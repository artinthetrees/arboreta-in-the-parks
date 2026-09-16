#!/bin/bash
set -e
sudo yum install git -y
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker ec2-user
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose