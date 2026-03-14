terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  az_public           = var.az_public
  az_private          = var.az_private
  enable_nat_gateway  = var.enable_nat_gateway
  allowed_ssh_cidr    = var.allowed_ssh_cidr
}

module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.ec2_security_group_id
  key_name          = var.key_name
}