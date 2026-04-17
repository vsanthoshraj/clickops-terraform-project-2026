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
  owners = ["099720109477"]
}

resource "aws_security_group" "web" {
  name        = "clickops-sg-${var.env}"
  description = "Security rules for web access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

  tags = {
    Name        = "clickops-sg-${var.env}"
    Environment = var.env
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name        = "clickops-${var.env}-server"
    Environment = var.env
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose awscli git
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              
              cat << 'DOCKERCOMPOSE' > /home/ubuntu/docker-compose.yml
              services:
                backend:
                  image: clickops-${var.env}-be:v1
                  ports:
                    - "3000:3000"
                  environment:
                    - S3_BUCKET=${var.s3_bucket_name}
                    - SECRET_NAME=${var.secret_name}
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
              
              # Auto-pulls the pre-built application image from ECR natively 
              cat << 'SCRIPT' > /home/ubuntu/start.sh
              #!/bin/bash
              REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
              MAC=\$(curl -s http://169.254.169.254/latest/meta-data/mac)
              ACCOUNT_ID=\$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/\$MAC/owner-id)
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin \$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
              
              docker pull ${var.ecr_repo_url}:v1
              docker tag ${var.ecr_repo_url}:v1 clickops-${var.env}-be:v1
              docker-compose up -d
              SCRIPT
              
              chmod +x /home/ubuntu/start.sh
              /home/ubuntu/start.sh &
              EOF
}
