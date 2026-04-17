output "public_ip" {
  value = aws_instance.server.public_ip
}

output "instance_id" {
  value = aws_instance.server.id
}

output "private_key" {
  value     = tls_private_key.main.private_key_pem
  sensitive = true
}
