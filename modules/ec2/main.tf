resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.main.public_key_openssh
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "main" {
  name        = "${var.project_name}-sg-${var.environment}"
  description = "Security group for clickops app"
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
    Name        = "${var.project_name}-sg-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_instance" "server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = var.iam_instance_profile
  key_name               = aws_key_pair.generated_key.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update and install Docker
              dnf update -y
              dnf install -y docker
              systemctl enable --now docker
              usermod -aG docker ec2-user

              # Install Docker Compose
              mkdir -p /usr/local/lib/docker/cli-plugins/
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
              
              # Create app directory
              mkdir -p /home/ec2-user/app
              cd /home/ec2-user/app
              
              # Create frontend directory and index.html
              mkdir -p frontend
              cat <<'HTML' > frontend/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>ClickOps App Dashboard</title>
                  <style>
                      * { box-sizing: border-box; }
                      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); color: #333; }
                      .card { background: rgba(255, 255, 255, 0.95); padding: 3rem; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); text-align: center; max-width: 500px; width: 90%; backdrop-filter: blur(10px); }
                      h1 { color: #1e3c72; margin-top: 0; font-size: 2.2rem; }
                      .status-box { margin-top: 2rem; padding: 1.5rem; border-radius: 8px; background: #f8f9fa; border-left: 4px solid #1e3c72; text-align: left; transition: transform 0.3s ease; }
                      .status-box:hover { transform: translateY(-5px); box-shadow: 0 6px 15px rgba(0,0,0,0.1); }
                      .indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }
                      .online { background-color: #28a745; box-shadow: 0 0 8px #28a745; }
                      .offline { background-color: #dc3545; box-shadow: 0 0 8px #dc3545; }
                      .loading { background-color: #ffc107; animation: pulse 1.5s infinite; }
                      @keyframes pulse { 0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; } }
                      p.label { margin: 0 0 5px 0; font-weight: bold; color: #555; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 1px; }
                      .value { margin: 0; font-size: 1.1rem; }
                      .row { margin-bottom: 15px; }
                      .row:last-child { margin-bottom: 0; }
                      button { margin-top: 20px; padding: 10px 20px; border: none; background: #1e3c72; color: white; border-radius: 5px; cursor: pointer; font-size: 1rem; transition: background 0.3s; }
                      button:hover { background: #2a5298; }
                  </style>
              </head>
              <body>
                  <div class="card">
                      <h1>ClickOps 3-Tier App</h1>
                      <p style="color: #666; margin-bottom: 2rem;">Infrastructure dynamically provisioned on AWS</p>
                      
                      <div class="status-box" id="status-container">
                          <div class="row">
                              <p class="label">Backend API</p>
                              <p class="value"><span id="api-indicator" class="indicator loading"></span><span id="api-status">Connecting...</span></p>
                          </div>
                          <div class="row">
                              <p class="label">MongoDB Database</p>
                              <p class="value"><span id="db-indicator" class="indicator offline"></span><span id="db-status">Unknown</span></p>
                          </div>
                          <div class="row">
                              <p class="label">Environment</p>
                              <p class="value" style="color: #1a73e8; font-weight: 600;" id="env-status">--</p>
                          </div>
                      </div>
                      
                      <button onclick="checkStatus()">Refresh Status</button>
                  </div>
                  <script>
                      function checkStatus() {
                          document.getElementById('api-indicator').className = 'indicator loading';
                          document.getElementById('api-status').innerText = 'Connecting...';
                          
                          fetch('http://' + window.location.hostname + ':3000/api/health')
                              .then(response => response.json())
                              .then(data => {
                                  document.getElementById('api-indicator').className = 'indicator online';
                                  document.getElementById('api-status').innerText = data.message || 'Online';
                                  
                                  const dbOnline = data.database === 'Connected';
                                  document.getElementById('db-indicator').className = dbOnline ? 'indicator online' : 'indicator offline';
                                  document.getElementById('db-status').innerText = data.database || 'Disconnected';
                                  
                                  document.getElementById('env-status').innerText = (data.environment || 'production').toUpperCase();
                              })
                              .catch(err => {
                                  document.getElementById('api-indicator').className = 'indicator offline';
                                  document.getElementById('api-status').innerText = 'Unreachable';
                                  document.getElementById('db-indicator').className = 'indicator offline';
                                  document.getElementById('db-status').innerText = 'Unreachable';
                                  console.error(err);
                              });
                      }
                      
                      // Run check immediately on load
                      checkStatus();
                  </script>
              </body>
              </html>
              HTML

              # Create docker-compose.yml
              cat <<EOT > docker-compose.yml
              version: '3.8'
              services:
                frontend:
                  image: nginx:alpine
                  ports:
                    - "80:80"
                  volumes:
                    - ./frontend:/usr/share/nginx/html
                  depends_on:
                    - backend

                backend:
                  image: ${var.ecr_repo_url}:v3
                  ports:
                    - "3000:3000"
                  environment:
                    - APP_ENV=${var.environment}
                    - MONGO_URL=mongodb://mongodb:27017
                    - S3_BUCKET=${var.s3_bucket}
                    - SECRET_NAME=${var.secret_name}
                    - AWS_REGION=${var.aws_region}
                  depends_on:
                    - mongodb

                mongodb:
                  image: mongo:latest
                  ports:
                    - "27017:27017"
                  environment:
                    - MONGO_INITDB_ROOT_USERNAME=admin
                    - MONGO_INITDB_ROOT_PASSWORD=password123
              EOT

              # Authenticate to ECR and run app
              ECR_REGISTRY="${split("/", var.ecr_repo_url)[0]}"
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
              docker compose up -d
              EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-server"
    Environment = var.environment
    Project     = var.project_name
  }
}
