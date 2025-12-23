#########################################
# outputs.tf
#########################################

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "s3_bucket_name" {
  description = "Name of S3 bucket created"
  value       = aws_s3_bucket.project_bucket.bucket
}