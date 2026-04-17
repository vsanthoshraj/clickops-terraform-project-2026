output "ec2_public_ip" {
  description = "Access URL IP Endpoint"
  value       = module.ec2.public_ip
}

output "s3_bucket_name" {
  description = "Assets storage bucket"
  value       = module.s3.bucket_name
}

output "ecr_repo_url" {
  description = "Container registry coordinates"
  value       = module.ecr.repository_url
}
