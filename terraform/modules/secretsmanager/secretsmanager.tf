resource "aws_secretsmanager_secret" "secret_metadata" {
  name = "${var.secret_name}"
}

resource "aws_secretsmanager_secret_version" "secret_value" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = jsonencode(var.secret_map)
}