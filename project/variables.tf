variable "region" {
  description = "AWS region deployed into"
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "Target deployment environment"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance sizing"
  type        = string
  default     = "t2.micro"
}

variable "key_pair" {
  description = "SSH key pair name"
  type        = string
}
