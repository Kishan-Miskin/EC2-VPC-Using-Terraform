<div align="center">

<h1 style="color:#7c3aed">EC2 & VPC Using Terraform Hands-On</h1>

**Provision a production-ready EC2 instance inside a custom VPC — fully automated with Terraform.**
Live system dashboard served at boot. No agents. No manual steps.

---

[![Terraform](https://img.shields.io/badge/Terraform-1.x-7c3aed?style=flat-square&logo=terraform&logoColor=white)](https://terraform.io)
[![AWS EC2](https://img.shields.io/badge/AWS-EC2-232f3e?style=flat-square&logo=amazonaws&logoColor=white)](https://aws.amazon.com/ec2)
[![Apache](https://img.shields.io/badge/Server-Apache-d22128?style=flat-square&logo=apache&logoColor=white)](https://httpd.apache.org)
[![Amazon Linux](https://img.shields.io/badge/OS-Amazon%20Linux%202-ff9900?style=flat-square&logo=amazon&logoColor=white)](https://aws.amazon.com/amazon-linux-2)

</div>

---

## Overview

This project provisions an AWS EC2 instance inside a VPC using Terraform and automatically deploys a live system monitoring dashboard on first boot. The dashboard displays real-time server metrics — CPU, memory, disk, network, and uptime — refreshed every 5 seconds via a lightweight Python API.

The entire bootstrap (web server, metrics API, systemd service, Apache proxy) is handled through `user_data`. Zero manual SSH required.

---

## Architecture

```
Browser
   |
   |  :80
   v
Apache HTTPD
   |            \
   |  /          \  /metrics proxy
   v              v
index.html     Python API :8080
                   |
                   v
              /proc/* (CPU, MEM, NET, DISK)
```

---

## What Gets Deployed

| Component | Details |
|---|---|
| EC2 Instance | Custom type, subnet, key pair |
| VPC / Subnet | User-defined via variables |
| Web Server | Apache HTTPD on port 80 |
| Dashboard | Glassmorphism UI, auto-refreshes every 5s |
| Metrics API | Python 3 stdlib server on port 8080 |
| Systemd Service | Metrics API persists across reboots |
| Storage | 20 GB gp3 EBS, encrypted at rest |
| IMDSv2 | Enforced — `http_tokens = required` |

---

## Dashboard

The landing page at `http://<public-ip>` shows a live card with:

```
Status    Hostname    CPU Usage
Memory    Disk Usage  Uptime
```

Footer reads: `Created By Kishan Miskin ; EC2 & VPC Using Terraform`

---

## Quick Start

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd <project-folder>

# 2. Fill in your values
cp terraform.tfvars.example terraform.tfvars

# 3. Deploy
terraform init
terraform plan
terraform apply
```

Navigate to the EC2 public IP in your browser. The dashboard is live.

---

## Variables

| Variable | Description | Required |
|---|---|:---:|
| `project_name` | Shown as page title, footer, and resource tags | yes |
| `instance_type` | EC2 instance type e.g. `t3.micro` | yes |
| `subnet_id` | Subnet ID to launch the instance into | yes |
| `security_group_id` | Security group with port 80 inbound open | yes |
| `key_name` | EC2 key pair name for SSH access | yes |
| `ami_id` | Custom AMI ID — defaults to Amazon Linux 2 | no |

---

## File Structure

```
.
├── main.tf              # EC2 resource, user_data bootstrap
├── variables.tf         # All input variable declarations
├── outputs.tf           # Public IP and public DNS
├── terraform.tfvars     # Your values (never commit this)
└── README.md
```

---

## Security Notes

- IMDSv2 enforced on the instance metadata service
- Root EBS volume is AES-256 encrypted
- Volume is deleted automatically on instance termination
- Restrict port `80` in your security group to known IP ranges — the dashboard exposes live system internals

---

## Teardown

```bash
terraform destroy
```

All resources are removed cleanly. No orphaned volumes or dangling ENIs.

---

<div align="center">

Created by **Kishan Miskin** — EC2 & VPC Using Terraform Hands-On

</div>
