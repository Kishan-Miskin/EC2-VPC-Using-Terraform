<div align="center">

# EC2 & VPC Using Terraform — Hands-On

**End-to-end infrastructure automation using Terraform modules on AWS.**
Provisions a custom VPC and a production-ready EC2 instance with Apache HTTPD —
fully automated from `terraform apply` to a live web server. No manual steps. No SSH.

<br>

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7c3aed?style=for-the-badge&logo=terraform&logoColor=white)](https://terraform.io)
[![AWS EC2](https://img.shields.io/badge/Cloud-AWS%20EC2-232f3e?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/ec2)
[![Apache](https://img.shields.io/badge/Server-Apache%20HTTPD-d22128?style=for-the-badge&logo=apache&logoColor=white)](https://httpd.apache.org)
[![Amazon Linux](https://img.shields.io/badge/OS-Amazon%20Linux%202-ff9900?style=for-the-badge&logo=amazon&logoColor=white)](https://aws.amazon.com/amazon-linux-2)

</div>

---

## What This Project Demonstrates

A hands-on cloud engineering project showcasing real-world Infrastructure as Code (IaC) skills.

- Modular Terraform project structure — separate `vpc` and `ec2` modules
- Full VPC provisioning: subnets, security groups, routing — defined in code
- EC2 bootstrap automation via `user_data` — Apache live on first boot
- IMDSv2 enforcement, EBS encryption, and least-privilege security groups
- Clean variable passing between root module and child modules
- Outputs surfaced at root level for easy access to public IP and DNS

---

## Infrastructure Overview

```
terraform apply
      |
      v
  Root Module (main.tf)
      |
      +── module "vpc"
      |       |
      |       +── VPC
      |       +── Subnet
      |       +── Internet Gateway
      |       +── Route Table
      |       +── Security Group (port 80)
      |       |
      |       outputs: vpc_id, subnet_id, security_group_id
      |
      +── module "ec2"
              |
              inputs: subnet_id, security_group_id (from vpc module)
              |
              +── EC2 Instance
              |       |
              |       +── user_data bootstrap
              |               |
              |               +── yum install httpd python3
              |               +── systemctl enable httpd
              |               +── Deploy web application
              |               +── Register systemd service
              |
              +── EBS gp3 20 GB (encrypted)
              +── IMDSv2 enforced
              |
              outputs: public_ip, public_dns
```

---

## Modular Project Structure

```
EC2-VPC-US.../
│
├── modules/
│   ├── ec2/
│   │   ├── main.tf          # aws_instance resource, user_data, EBS, metadata
│   │   ├── variables.tf     # ami_id, instance_type, subnet_id, sg_id, key_name
│   │   └── outputs.tf       # public_ip, public_dns, instance_id
│   │
│   └── vpc/
│       ├── main.tf          # VPC, subnet, IGW, route table, security group
│       ├── variables.tf     # cidr_block, project_name, region
│       └── outputs.tf       # vpc_id, subnet_id, security_group_id
│
├── main.tf                  # Root module — calls vpc + ec2 modules
├── variables.tf             # Root-level input variables
├── outputs.tf               # Surfaces ec2 module outputs to the user
└── terraform.tfvars         # Actual values (gitignored)
```

---

## Module Responsibilities

### `modules/vpc`

Provisions the full network layer entirely in code.

| Resource | Details |
|---|---|
| `aws_vpc` | Custom CIDR block, DNS enabled |
| `aws_subnet` | Public subnet in specified AZ |
| `aws_internet_gateway` | Attached to VPC for outbound access |
| `aws_route_table` | Routes `0.0.0.0/0` through the IGW |
| `aws_security_group` | Inbound port 80, outbound all |

### `modules/ec2`

Provisions the compute layer, consuming VPC module outputs.

| Resource | Details |
|---|---|
| `aws_instance` | Amazon Linux 2, configurable type |
| `root_block_device` | 20 GB gp3, AES-256 encrypted |
| `metadata_options` | IMDSv2 enforced — `http_tokens = required` |
| `user_data` | Full server bootstrap — Apache + web app automated |

---

## Automation with user_data

The entire server configuration runs automatically on first boot — driven by Terraform's `user_data`. No manual SSH, no Ansible, no configuration management tools needed.

```bash
# Executed once at EC2 launch via Terraform user_data

yum update -y
yum install -y httpd python3

systemctl start httpd
systemctl enable httpd       # Persists across reboots

# Apache serves the landing page immediately
# Systemd service registered and started
# Everything wired up — zero manual steps
```

---

## Quick Start

```bash
# 1. Clone
git clone <your-repo-url>
cd EC2-VPC-US...

# 2. Set your values
cp terraform.tfvars.example terraform.tfvars

# 3. Deploy
terraform init
terraform plan
terraform apply
```

The public IP is printed as an output. Open it in a browser — Apache is already serving.

---

## Input Variables

| Variable | Description | Required |
|---|---|:---:|
| `project_name` | Name prefix applied to all resources and tags | yes |
| `instance_type` | EC2 instance type — e.g. `t3.micro`, `t2.micro` | yes |
| `key_name` | EC2 key pair name for SSH access | yes |
| `ami_id` | AMI override — defaults to Amazon Linux 2 | no |

> Subnet, VPC, and Security Group are created by the `vpc` module — no pre-existing infra needed.

---

## Security Hardening

| Control | Implementation |
|---|---|
| IMDSv2 | `http_tokens = required` — blocks credential theft via SSRF |
| EBS Encryption | AES-256 encryption at rest on root volume |
| Volume Lifecycle | `delete_on_termination = true` — no orphaned storage |
| Security Group | Least privilege — port 80 inbound only, all outbound |

---

## Teardown

```bash
terraform destroy
```

Tears down every resource in reverse dependency order — EC2, EBS, SG, subnet, IGW, VPC. Nothing left behind.

---

<div align="center">

Created by **Kishan Miskin** — EC2 & VPC Using Terraform Hands-On

</div>
