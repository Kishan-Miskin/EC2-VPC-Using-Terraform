# 🖥️ EC2 System Monitor

> Terraform-provisioned EC2 with a live system dashboard — no agents, no extra tools.

---

## 🧱 How It Works

```
Browser :80  →  Apache  →  /metrics proxy  →  Python :8080  →  /proc/*
```

The `user_data` script does everything on first boot:
1. Installs Apache + Python 3
2. Writes the dashboard HTML via Python (avoids heredoc conflicts)
3. Starts a lightweight metrics API on `:8080`
4. Proxies `/metrics` through Apache on `:80`
5. Registers the metrics server as a systemd service

---

## ⚡ Deploy

```bash
terraform init
terraform apply
```

Open `http://<ec2-public-ip>` — dashboard is live.

---

## 📐 Variables

| Name | Description | Default |
|---|---|---|
| `project_name` | Page title & resource tag | required |
| `instance_type` | EC2 instance type | required |
| `subnet_id` | Subnet to launch into | required |
| `security_group_id` | SG with port 80 open | required |
| `key_name` | EC2 key pair name | required |
| `ami_id` | Custom AMI override | `ami-0b6c6ebed2801a5cb` |

---

## 📊 Dashboard

Polls `/metrics` every **5 seconds** and displays:

`Status` · `Hostname` · `CPU %` · `Memory %` · `Disk %` · `Uptime`

---

## 🔒 Security

- **IMDSv2 enforced** — `http_tokens = required`
- **Root EBS encrypted** — gp3, 20 GB, deleted on termination
- **Restrict port `80`** to trusted IPs — the dashboard exposes live system internals

---

## 📁 Structure

```
.
├── main.tf           # EC2 resource + full user_data bootstrap
├── variables.tf      # Input variable declarations
├── outputs.tf        # Public IP / DNS outputs
└── terraform.tfvars  # Your values (gitignored)
```

---

<sub>Terraform · Apache HTTPD · Python 3 stdlib · Amazon Linux 2</sub>
