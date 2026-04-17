variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "ecr_repo_url" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "secret_name" {
  type = string
}

variable "aws_region" {
  type = string
}
