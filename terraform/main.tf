provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# 1. Random suffix for globally unique S3 bucket name
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "b" {
  bucket        = "clickops-s3-dev-${random_id.suffix.hex}"
  force_destroy = true
}

# 2. Secrets Manager Secret
resource "aws_secretsmanager_secret" "mongo_creds" {
  name                    = "clickops-sm-dev-${random_id.suffix.hex}"
  recovery_window_in_days = 0 # Force delete immediately for dev
}

resource "aws_secretsmanager_secret_version" "mongo_creds_val" {
  secret_id     = aws_secretsmanager_secret.mongo_creds.id
  secret_string = jsonencode({
    username = "admin"
    password = "supersecretpassword123"
  })
}

# 3. ECR Repository
resource "aws_ecr_repository" "be_repo" {
  name                 = "clickops-dev-be-${random_id.suffix.hex}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Push local Docker image to ECR automatically
resource "null_resource" "push_image" {
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
      docker tag clickops-dev-be:v2 ${aws_ecr_repository.be_repo.repository_url}:v2
      docker push ${aws_ecr_repository.be_repo.repository_url}:v2
    EOT
  }
  depends_on = [aws_ecr_repository.be_repo]
}

# 4. EC2 Infrastructure
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "web" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  name        = "clickops-web-sg-${random_id.suffix.hex}"
  description = "Allow inbound traffic on port 3000 and 80"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "clickops-ec2-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_inline" {
  name = "clickops-ec2-inline"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.b.arn,
          "${aws_s3_bucket.b.arn}/*"
        ]
      },
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect = "Allow"
        Resource = aws_secretsmanager_secret.mongo_creds.arn
      },
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "clickops-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id = aws_subnet.web.id
  depends_on = [null_resource.push_image]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose awscli
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              
              cat << 'DOCKERCOMPOSE' > /home/ubuntu/docker-compose.yml
              services:
                backend:
                  image: ${aws_ecr_repository.be_repo.repository_url}:v2
                  ports:
                    - "3000:3000"
                  environment:
                    - S3_BUCKET=${aws_s3_bucket.b.id}
                    - SECRET_NAME=${aws_secretsmanager_secret.mongo_creds.name}
                    - AWS_REGION=us-east-1
                    - MONGO_HOST=mongodb
                    - MONGO_PORT=27017
                  depends_on:
                    - mongodb
                  networks:
                    - app-network

                mongodb:
                  image: mongo:6.0
                  ports:
                    - "27017:27017"
                  environment:
                    - MONGO_INITDB_ROOT_USERNAME=admin
                    - MONGO_INITDB_ROOT_PASSWORD=supersecretpassword123
                  volumes:
                    - mongo-data:/data/db
                  networks:
                    - app-network

              networks:
                app-network:
                  driver: bridge
              volumes:
                mongo-data:
              DOCKERCOMPOSE
              
              chown ubuntu:ubuntu /home/ubuntu/docker-compose.yml
              
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
              
              cd /home/ubuntu
              docker-compose up -d
              EOF

  tags = {
    Name = "ClickOpsAppServer"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
output "endpoint" {
  value = "http://$${aws_instance.web.public_ip}:3000"
}
