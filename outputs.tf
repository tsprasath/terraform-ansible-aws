output "ami" {
  value = aws_instance.example.ami
}

output "instancetype" {
  value = aws_instance.example.instance_type
}

output "ip" {
  value = aws_eip.ip.public_ip
}