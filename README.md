# ☁️ Cloud Engineer Coding Challenge 3  
### Infrastructure as Code (IaC) with Terraform and Ansible  

This README explains **how to provision and configure AWS infrastructure** using Terraform (for IaC) and Ansible (for configuration management).  
By completing these steps, you will have an *EC2 instance* running **Nginx** serving a simple **“Hello World!”** webpage hosted on AWS.

---

## Step 1 – Plan and Prepare AWS Architecture  
Understand what will be built and prepare the environment for automation.

### 🎯 Objective  
Design and prepare the environment Terraform and Ansible will use to provision and configure AWS.

---

### AWS Components Overview  

| AWS Service | Description | Role in Project |
|-------------|--------------|-----------------|
| **EC2** | Virtual machine | Hosts Nginx and serves “Hello, World!” |
| **S3** | Object storage | Optional storage for Terraform state or static assets |
| **IAM** | Permissions management | Grants EC2 permissions to access S3 |
| **Security Group** | Firewall rules | Allows SSH (22) and HTTP (80) traffic |

---

### Terraform and Ansible Interaction  

- **Terraform (IaC):** Automates creation of AWS resources.  
- **Ansible (CM):** Automates software installation and configuration.  

```
Terraform → Build AWS Resources (EC2, S3, IAM, Security Groups)
Ansible   → Configure EC2 (Install Web Server + Hello World)
User      → Visit EC2 Public IP → See “Hello World!”
```

---

### AWS Account and CLI Configuration  

1️⃣ Create an IAM User  
- Service: **IAM**  
- Name: `terraform-admin`  
- Enable: **Programmatic Access**  
- Policy: **AdministratorAccess**  

2️⃣ Install AWS CLI  
```bash
# macOS
brew install awscli
# Ubuntu/Debian
sudo apt install awscli -y
# Windows (PowerShell)
choco install awscli
```

3️⃣ Configure CLI Access  
```bash
aws configure
```
Input your Access and Secret Keys, region (`us-east-2`), and output format (`json`).  
Validate:
```bash
aws sts get-caller-identity
```

---

### Architecture Diagram (Textual View)  

```
Developer Workstation → Terraform + Ansible
          ↓
AWS Cloud (us-east-2)
  └── EC2 Instance (Nginx)
  └── IAM Role (S3 Access)
  └── Security Group (Ports 22 & 80)
          ↓
Browser → “Hello World!”
```

---

## Step 2 – Build and Deploy Infrastructure with Terraform  

### 🎯 Objective  
Use Terraform to automatically create an EC2 instance, IAM Role, S3 Bucket, and Security Group.

---

### Project Structure  

```bash
terraform/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

### main.tf  
Defines all AWS resources.  

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~>5.0" }
  }
}
provider "aws" { region = var.aws_region }

resource "aws_security_group" "web_sg" {
  name = "web-sg"
  ingress { from_port=22 to_port=22 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  ingress { from_port=80 to_port=80 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "random_id" "bucket_id" { byte_length = 3 }

resource "aws_s3_bucket" "project_bucket" {
  bucket = "tech-challenge3-${random_id.bucket_id.hex}"
  tags = { Name = "tech-challenge3-bucket" }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]
  filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] }
}

resource "aws_instance" "web_server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  key_name = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install nginx -y
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello, World!</h1>" > /var/www/html/index.html
  EOF

  tags = { Name = "Tech-Challenge3-WebServer" }
}
```

---

### variables.tf  
```hcl
variable "aws_region" {
  default = "us-east-2"
  description = "AWS region for deployment"
}
variable "key_name" {
  description = "Name of the SSH key pair"
}
```

### outputs.tf  
```hcl
output "instance_public_ip" {
  description = "Public IP of your EC2 instance"
  value = aws_instance.web_server.public_ip
}
output "s3_bucket_name" {
  description = "S3 bucket name"
  value = aws_s3_bucket.project_bucket.bucket
}
```

---

### Initialize and Apply Terraform  

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

✅ Terraform outputs the EC2 Public IP and S3 Bucket name.  
Use that Public IP for the next Ansible step.

---

### Verify on AWS  

| Service | Where to check | Expectation |
|---------|-----------------|-------------|
| EC2 | AWS Console → Instances | One instance running |
| S3 | AWS Console → Buckets | Bucket created |
| IAM | AWS Console → Roles | Role = ec2-s3-access-role |
| VPC | Security Groups → web-sg | Ports 22 and 80 open |

---

## Step 3 – Configure EC2 with Ansible  

### 🎯 Objective  
Install and configure the web server inside the provisioned EC2 instance.

---

### 1️⃣ Connect via SSH  
```bash
ssh -i /path/to/ ubuntu@<EC2_PUBLIC_IP>
```

---

### 2️⃣ Install Ansible  
```bash
sudo apt update -y
sudo apt install ansible -y
ansible --version
```

---

### 3️⃣ Create Inventory and Playbook  

```bash
mkdir ~/ansible && cd ~/ansible
echo "[local]
localhost ansible_connection=local" > inventory
nano playbook.yml
```

Paste:
```yaml
---
- name: Install Nginx and deploy Hello World page
  hosts: local
  become: true
  tasks:
    - apt: { update_cache: yes }
    - apt: { name: nginx, state: present }
    - copy:
        dest: /var/www/html/index.html
        content: "<h1>Hello, World!</h1>"
        owner: www-data
        group: www-data
        mode: '0644'
    - systemd: { name: nginx, state: started, enabled: true }
```

---

### 4️⃣ Run Playbook  
```bash
ansible-playbook -i inventory playbook.yml
```

Expected result:  
```
PLAY RECAP ******************************************************************
localhost : ok=4 changed=2 unreachable=0 failed=0
```

---

### 5️⃣ Validate the Web Server  

From inside EC2:  
```bash
curl http://localhost
```
Output: `<h1>Hello, World!</h1>`  

From your browser:   
Navigate to `http://<EC2_PUBLIC_IP>` — you should see **Hello World!**

---

## ✅ Final Checklist  

| Task | Status |
|------|---------|
| AWS CLI & Terraform configured | ☐ |
| Infrastructure deployed | ☐ |
| Ansible installed on EC2 | ☐ |
| Nginx running / HelloWorld page visible | ☐ |
| Code committed to GitHub with README | ☐ |

---

**Author:** Amos Music  
**Challenge:** Cloud Engineer Coding Challenge 3  
**Region:** us‑east‑2  
**Stack:** Terraform · Ansible · AWS · Ubuntu · Nginx  
