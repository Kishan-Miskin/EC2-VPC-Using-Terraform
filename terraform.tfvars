# terraform.tfvars
project_name       = "myapp"
aws_region         = "us-east-1"
az_public          = "us-east-1a"
az_private         = "us-east-1b"
ami_id             = "ami-0c02fb55956c7d316"   # ← us-east-1 Amazon Linux 2
key_name           = "Docker"
allowed_ssh_cidr   = "0.0.0.0/0"
enable_nat_gateway = false