# Outputs file
output "ssh" {
  value = "http://${aws_eip.andrius.public_dns}"
}

output "app_url" {
  value = "http://${aws_eip.andrius.public_ip}"
}
