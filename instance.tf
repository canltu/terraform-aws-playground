provider "aws" {
  version = "~> 3.0"
  region  = var.region
}

resource "aws_vpc" "andrius" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = "Production"
  }
}

resource "aws_subnet" "andrius" {
  vpc_id     = aws_vpc.andrius.id
  cidr_block = var.subnet_prefix

  tags = {
    name = "${var.prefix}-subnet"
  }
}

resource "aws_security_group" "andrius" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.andrius.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "random_id" "app-server-id" {
  prefix      = "${var.prefix}-andrius-"
  byte_length = 8
}

resource "aws_internet_gateway" "andrius" {
  vpc_id = aws_vpc.andrius.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "andrius" {
  vpc_id = aws_vpc.andrius.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.andrius.id
  }
}

resource "aws_route_table_association" "andrius" {
  subnet_id      = aws_subnet.andrius.id
  route_table_id = aws_route_table.andrius.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_eip" "andrius" {
  instance = aws_instance.andrius.id
  vpc      = true
}

resource "aws_eip_association" "andrius" {
  instance_id   = aws_instance.andrius.id
  allocation_id = aws_eip.andrius.id
}

resource "aws_instance" "andrius" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.andrius.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.andrius.id
  vpc_security_group_ids      = [aws_security_group.andrius.id]

  tags = {
    Name = "${var.prefix}-andrius-instance"
  }
}

# We're using a little trick here so we can run the provisioner without
# destroying the VM. Do not do this in production.

# If you need ongoing management (Day N) of your virtual machines a tool such
# as Chef or Puppet is a better choice. These tools track the state of
# individual files and can keep them in the correct configuration.

# Here we do the following steps:
# Sync everything in files/ to the remote VM.
# Set up some environment variables for our script.
# Add execute permissions to our scripts.
# Run the deploy_app.sh script.
resource "null_resource" "configure-cat-app" {
  depends_on = [aws_eip_association.andrius]

  triggers = {
    build_number = timestamp()
  }

  provisioner "file" {
    source      = "files/"
    destination = "/home/ubuntu/"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.andrius.private_key_pem
      host        = aws_eip.andrius.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo add-apt-repository universe",
      "sudo apt -y update",
      "sudo apt -y instal pip3",
      "sudo pip3 install botocore rsa requests, parse, flask, flask_cors",
      "sudo chmod +x *.sh",
      "sudo chmod +x *.py",
      "sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "echo ${SIGNING_KEY} > signing_private_key.pem",
      "nohup ./s.py&"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.andrius.private_key_pem
      host        = aws_eip.andrius.public_ip
    }
  }
}

resource "tls_private_key" "andrius" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  private_key_filename = "${random_id.app-server-id.dec}-ssh-key.pem"
}

resource "aws_key_pair" "andrius" {
  key_name   = local.private_key_filename
  public_key = tls_private_key.andrius.public_key_openssh
}

resource "null_resource" "get_keys" {
  provisioner "local-exec" {
    command     = "echo '${tls_private_key.andrius.public_key_openssh}' > ~/.ssh/aws.rsa.pub"
  }
  provisioner "local-exec" {
    command     = "echo '${tls_private_key.andrius.private_key_pem}' > ~/.ssh/aws_key.pem"
  }
  provisioner "local-exec" {
    command     = "chmod 0600 ~/.ssh/aws_key.pem"
  }
}
