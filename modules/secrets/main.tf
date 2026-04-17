resource "aws_secretsmanager_secret" "mongo_credentials" {
  name                    = "${var.project_name}-sm-${var.environment}-${var.secret_suffix}"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-sm-${var.environment}-${var.secret_suffix}"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "mongo_credentials_val" {
  secret_id     = aws_secretsmanager_secret.mongo_credentials.id
  secret_string = jsonencode({
    mongodb_username = "admin"
    mongodb_password = "password123" # In a real scenario, this would be passed as a sensitive variable or set manually
  })
}
