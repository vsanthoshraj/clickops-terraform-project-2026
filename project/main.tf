provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./modules/vpc"
  env    = var.env
}

module "s3" {
  source = "./modules/s3"
  env    = var.env
}

module "secrets" {
  source = "./modules/secrets"
  env    = var.env
}

module "ecr" {
  source = "./modules/ecr"
  env    = var.env
}

module "iam" {
  source     = "./modules/iam"
  env        = var.env
  s3_arn     = module.s3.bucket_arn
  secret_arn = module.secrets.secret_arn
}

module "ec2" {
  source               = "./modules/ec2"
  env                  = var.env
  instance_type        = var.instance_type
  key_pair             = var.key_pair
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_id
  iam_instance_profile = module.iam.instance_profile_name
  s3_bucket_name       = module.s3.bucket_name
  secret_name          = module.secrets.secret_name
  ecr_repo_url         = module.ecr.repository_url
}
