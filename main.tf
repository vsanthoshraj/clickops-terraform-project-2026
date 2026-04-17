terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source       = "./modules/vpc"
  environment  = var.environment
  project_name = var.project_name
}

module "iam" {
  source       = "./modules/iam"
  environment  = var.environment
  project_name = var.project_name
}

resource "random_id" "suffix" {
  byte_length = 4
}

module "s3" {
  source        = "./modules/s3"
  environment   = var.environment
  project_name  = var.project_name
  bucket_suffix = random_id.suffix.hex
}

module "secrets" {
  source        = "./modules/secrets"
  environment   = var.environment
  project_name  = var.project_name
  secret_suffix = random_id.suffix.hex
}

module "ecr" {
  source       = "./modules/ecr"
  environment  = var.environment
  project_name = var.project_name
}

module "ec2" {
  source               = "./modules/ec2"
  environment          = var.environment
  project_name         = var.project_name
  instance_type        = var.instance_type
  key_name             = var.key_name
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_id
  iam_instance_profile = module.iam.instance_profile_name
  ecr_repo_url         = module.ecr.repository_url
  s3_bucket            = module.s3.bucket_name
  secret_name          = "${var.project_name}-sm-${var.environment}-${random_id.suffix.hex}"
  aws_region           = var.aws_region
}

