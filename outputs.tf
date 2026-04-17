output "ec2_public_ip" {
  value       = module.ec2.public_ip
  description = "Public IP of the EC2 instance"
}

output "s3_bucket_name" {
  value       = module.s3.bucket_name
  description = "Name of the S3 bucket"
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "URL of the ECR repository"
}

output "private_key" {
  value     = module.ec2.private_key
  sensitive = true
}
