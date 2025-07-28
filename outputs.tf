output "latest_ami_id" {
  description = "The ID of the latest Amazon Linux 2 AMI."
  value       = data.aws_ami.latest_amazon_linux.id
}
# outputs.tf (追記)

output "web_server_public_ip" {
  description = "The public IP address of our web server."
  value       = aws_instance.my_web_server.public_ip
}