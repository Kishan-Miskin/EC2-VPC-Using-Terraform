variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_subnet_cidr" {
  type = string
}

variable "az_public" {
  type = string
}

variable "az_private" {
  type = string
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}