# ClickOps 3-Tier Web Application - Comprehensive Documentation

Welcome to the comprehensive guide for the **ClickOps Terraform Project-2026**. This document outlines the entire architecture, the technologies used, precisely how the environment functions, and a step-by-step procedure to deploy the application completely from scratch.

---

## 1. Technologies and Tech Stack

We utilize a robust and modern set of frameworks to build this cloud-native application. Here is what we use and exactly why we chose them:

### Application Stack
* **Frontend (Vanilla HTML/CSS/JS):** Chosen for lightweight execution, simplicity, and blazing fast browser rendering without heavy node-module or React dependencies. Perfectly decoupled and directly served by the backend API.
* **Backend API (Python / Flask):** Flask is a micro-framework that is immensely simple yet scalable. We chose it because it natively integrates with **Boto3** (The AWS Python SDK) perfectly, making our S3 and Secrets Manager interactions seamless.
* **Database (MongoDB):** A NoSQL Document DB. Chosen because our user submissions (Name, Age, Image Metadata) are essentially unstructured JSON documents. It allows extremely fast and schema-less data ingestion scaling natively without strict relational SQL migrations.
* **Containerization (Docker & Docker Compose):** Normalizes the application environment. By packaging the python app and database daemon into strict containers, we guarantee that the codebase runs exactly the identical way locally on a developer's machine as it does on a dynamic AWS EC2 instance.

### Cloud Stack (AWS Resources)
Every single AWS cloud component was strategically chosen to fulfill a specific infrastructure need securely:
* **Amazon EC2 (Elastic Compute Cloud):** Provides the raw Virtual Machine and CPU horsepower required to physically spin up your Docker daemons and serve traffic over the web. 
* **Amazon ECR (Elastic Container Registry):** Chosen as a secure, private AWS vault to securely stash our built Docker images exactly where EC2 can fetch them instantly without using public DockerHub rates.
* **Amazon S3 (Simple Storage Service):** Our limitless blob-storage. We chose this over storing images locally on the EC2 hard drive because S3 acts as a CDN—it securely serves massive image files via public object URLs seamlessly without ever maxing out our EC2 bandwidth.
* **AWS Secrets Manager:** Selected to decouple our database credentials from source code explicitly. It dynamically retrieves credentials across the network on runtime ensuring zero security leaks.
* **AWS IAM (Identity & Access Management):** Handles server-to-server assumed authentication. It provides our EC2 instance permission to talk to S3 and Secrets Manager implicitly through "Instance profiles" instead of insecurely saving `.csv` keys.
* **AWS VPC (Virtual Private Cloud):** Delivers the structured network isolation guaranteeing rogue IP addresses can't easily exploit the database routing internally.

---

## 2. How the Application Actually Works

The moment a user visits your IP `http://<SERVER_IP>:3000` to submit a form, the following precise sequential actions orchestrate the transaction:

### A. The End-to-End Orchestration Flow
1. **Frontend Submit:** The browser constructs a `multipart/form-data` package containing the text data (Name, Age) and binary data (The Image). It sends an HTTP POST request to `/upload`.
2. **Backend Interception & S3:** The Flask API catches the request. Since IAM Instance Profiles securely map AWS credentials to our code inherently, the backend pushes the image directly into our AWS S3 bucket.
3. **Database Authentication:** The Backend then uses the `boto3` SDK to query **AWS Secrets Manager**, retrieving a JSON file containing identical username and passwords allocated internally.
4. **MongoDB Storage:** Utilizing those secure credentials, the backend authenticates its active connection string to the MongoDB daemon and records a final entry noting the Username, Age, and exactly which filename it uploaded to S3.
5. **Nginx Dashboard:** In parallel, an auto-generated HTML dashboard runs on Port 80, polling the backend's `/api/health` endpoint periodically checking the pulse of both API and Database functionalities.

### B. How Docker Compose Operates Internally
Within this architecture, `docker-compose.yml` plays a phenomenal localized role running on the Amazon EC2 server:

* When the EC2 instance physically boots up, our custom `user_data` script triggers dynamically. 
* This bash script dynamically extracts your active Terraform variables (like the generated S3 Bucket Name `clickops-s3-dev-...`, and dynamic IAM AWS region `us-east-1`).
* It mathematically **writes and injects** these exact variables as environment arguments (`- S3_BUCKET=${var.s3_bucket}`) directly into a physical `/home/ec2-user/app/docker-compose.yml` file!
* It structures two local services bound tightly logically: `backend` (Your Flask code fetched from ECR) and `mongodb` (Your document database daemon).
* Finally, it executes `docker compose up -d` pulling both containers up safely.
* Because they use the Compose Network (`mongodb://mongodb:27017`), your backend communicates effortlessly with the database via purely localized internal DNS routing.

---

## 3. Deployment Playbook (How to Run)

The codebase relies strictly on Infrastructure as Code utilizing **HashiCorp Terraform**. Thus, rolling out the application is performed programmatically via terminal commands.

### Prerequisite Checklist
- Terraform `v1.x` and `docker` installed locally.
- A valid AWS Account with programmatic access enabled.

### Step 1: Export AWS Credentials & Initialize
Before executing any remote AWS CLI commands or Terraform deployments, you must explicitly export your AWS credentials into your active terminal session:
```bash
export AWS_ACCESS_KEY_ID="your_access_key_here"
export AWS_SECRET_ACCESS_KEY="your_secret_key_here"
export AWS_REGION="us-east-1"
```
Once securely bonded to your environment, initialize the Terraform working directory:
```bash
terraform init
```

### Step 2: Provision ECR Remote Repository Specifically First 
Because your application needs an EC2 server that can successfully pull your backend container layer down exactly upon its first startup procedure, you must independently spin up the remote **container registry (ECR)** first.
```bash
terraform apply -target=module.ecr -var-file=dev.tfvars -auto-approve
```

### Step 3: Package, Build, and Transport Software Architecture (Docker)
Authenticate Docker safely via AWS CLI mechanisms, manually construct the Python application layout locally, and immediately push the finished artifact bundle exactly to your newly allocated AWS ECR container repository.

```bash
# 1. Provide secure ECR credentials to Docker locally
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Build Backend Dockerfile
docker build -t clickops-be:v1 -f backend/Dockerfile .

# 3. Synchronize tags and deploy standard payload identically to your ECR URL
docker tag clickops-be:v1 <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/clickops-ecr-dev:v1

# 4. Push final software architecture
docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/clickops-ecr-dev:v1
```

### Step 4: Scale the AWS Cloud Infrastructure Architecture Dynamically
Instruct Terraform computationally to apply all remaining infrastructure dependencies (VPCs, Network Gateways, MongoDB Password Generetions, IAM Role Structuring, S3 Image Buckets, and eventually spin up the EC2 Linux Computing Machine globally).

```bash
terraform apply -var-file=dev.tfvars -auto-approve
```

**Success Validation:**
As soon as Terraform reports `Apply Complete`, it will automatically echo out your live instance `ec2_public_ip` interface.
- Navigate efficiently to `http://<EC2_PUBLIC_IP>:3000` to interact deeply executing web requests.
- Navigate to `http://<EC2_PUBLIC_IP>` purely to strictly visualize internal application health statuses dynamically.
