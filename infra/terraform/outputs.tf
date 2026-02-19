output "app_ec2_public_ip" {
  value = aws_instance.app.public_ip
}

output "app_ec2_private_ip" {
  value = aws_instance.app.private_ip
}

output "db_ec2_public_ip" {
  value = aws_instance.db.public_ip
}

output "db_ec2_private_ip" {
  value = aws_instance.db.private_ip
}
