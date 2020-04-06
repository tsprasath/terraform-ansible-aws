provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_key_pair" "example" {
  key_name   = "examplekey"
  public_key = file("~/.ssh/prasath.pub")
}

resource "aws_s3_bucket" "example" {
  # NOTE: S3 bucket names must be unique across _all_ AWS accounts, so
  # this name must be changed before applying this example to avoid naming
  # conflicts.
  bucket = "terraform-state"
  acl    = "private"
}

resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16" # Defines overall VPC address space
  enable_dns_hostnames = true          # Enable DNS hostnames for this VPC
  enable_dns_support   = true          # Enable DNS resolving support for this VPC
  instance_tenancy     = "default"
  enable_classiclink   = "false"

  tags = {
    Name = "VPC-my-vpc" # Tag VPC with name
  }
}

resource "aws_instance" "example" {
  key_name                    = aws_key_pair.example.key_name
  ami                         = var.ami
  instance_type               = var.instance
  associate_public_ip_address = true
  # Tells Terraform that this EC2 instance must be created only after the
  # S3 bucket has been created.
  depends_on = [aws_s3_bucket.example]

  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.egress-tls.id}",
    "${aws_security_group.ping-ICMP.id}",
    "${aws_security_group.web_server.id}"
  ]

  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_size           = 500
    volume_type           = "io1"
    iops                  = 2000
    encrypted             = true
    delete_on_termination = true
  }

  provisioner "local-exec" {
    //command = "echo ${aws_instance.example.public_ip} > ip_address.txt"
    command = <<EOT
    sleep 120; 
    export ANSIBLE_HOST_KEY_CHECKING=False 
    ansible-playbook -u ubuntu --private-key '${aws_instance.example.key_name}' -i '${aws_instance.example.public_ip},' ../ansible/install_java.yaml"
  EOT
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = ["sudo apt-get -qq install python -y"]
  }
}

resource "aws_security_group" "web" {
  name        = "default-web-example"
  description = "Security group for web that allows web traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-example-default-vpc"
  }
}

resource "aws_security_group" "ssh" {
  name        = "default-ssh-example"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-example-default-vpc"
  }
}

resource "aws_security_group" "egress-tls" {
  name        = "default-egress-tls-example"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "egress-tls-example-default-vpc"
  }
}

resource "aws_security_group" "ping-ICMP" {
  name        = "default-ping-example"
  description = "Default security group that allows to ping the instance"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ping-ICMP-example-default-vpc"
  }
}

# Allow the web app to receive requests on port 8080
resource "aws_security_group" "web_server" {
  name        = "default-web_server-example"
  description = "Default security group that allows to use port 8080"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_server-example-default-vpc"
  }
}

resource "aws_eip" "ip" {
  vpc      = true
  instance = aws_instance.example.id
}
