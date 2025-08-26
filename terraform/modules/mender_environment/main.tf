resource "aws_instance" "mender" {
  ami           = var.ami
  instance_type = var.instance_type

  user_data = <<EOF
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose-plugin

git clone -b v4.0.0 https://github.com/mendersoftware/mender-server.git mender-server
cd mender-server
export MENDER_IMAGE_TAG=v4.0.0
docker compose up -d
MENDER_USERNAME=admin@docker.mender.io
MENDER_PASSWORD=PleaseReplaceWithASecurePassword
docker compose run --name create-user useradm create-user --username "$MENDER_USERNAME" --password "$MENDER_PASSWORD"
EOF

  tags = {
    Name = "mender-environment-${random_id.id.hex}"
  }
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_security_group" "mender" {
  name        = "mender-environment-${random_id.id.hex}"
  description = "Allow HTTP/HTTPS traffic to Mender environment"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
