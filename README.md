# ClickOps Terraform Project-2026

This is a 3-tier cloud-native web application showcasing a frontend interface, Python Flask backend, and MongoDB storage, integrated with AWS features like S3 and Secrets Manager.

## Project Architecture

```
clickops_project/
├── docker-compose.yml
├── README.md
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
└── frontend/
    ├── index.html
    ├── script.js
    └── style.css
```

## Setup & Deployment Commands

### 1. Build the Docker Image
To build the Dockerized backend and correctly tag it:
```bash
docker build -t clickops-dev-be:v1 ./backend
```

### 2. Run the Application locally
To spin up both MongoDB and the Backend, ensure you export your AWS credentials if testing locally so Flask can reach S3 & Secrets Manager.
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_REGION="us-east-1"

# Launch containers in detached mode
docker compose up -d
```
* **Backend GET Health Check:** open `http://localhost:3000/` in browser to see "Backend Running"
* **Frontend:** Open `frontend/index.html` locally in a browser. It is fully set up to make `POST` requests to `http://localhost:3000/upload`.

### 3. Push to AWS ECR
When ready to push the image to AWS ECR:

```bash
# 1. Log in to ECR (Replace with your region and account ID)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Create the ECR repository (You only have to do this once)
aws ecr create-repository --repository-name clickops-dev-be

# 3. Associate the newly built image to your remote ECR repo URL constraint
docker tag clickops-dev-be:v1 <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/clickops-dev-be:v1

# 4. Push the image
docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/clickops-dev-be:v1
```

## Features Complete:
- **HTML/CSS/JS** with validation, success/error styling, clean typography and responsive design.
- **RESTful Flask API** exposing `/` and `/upload` over exposed `3000` Docker port. Handles cross-origin setups with `flask-cors`.
- **S3 Boto3 Integration** uploading cleanly through `.upload_fileobj()`.
- **Secrets Manager dynamically called** avoiding hardcoded variables or configs. Falls back to unauthenticated mongo connection for pure debug flexibility.
- Single structured `docker compose` combining DB state management & network orchestration.
