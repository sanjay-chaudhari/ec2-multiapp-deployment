# Infrastructure

Terraform scripts to provision all AWS resources. Run once per environment.

```
terraform/
├── main.tf          # VPC, subnet, IGW, route table
├── security.tf      # App + DB security groups
├── ec2.tf           # App + DB EC2 instances
├── variables.tf     # Input variables
├── outputs.tf       # Prints IPs after apply
├── terraform.tfvars.example
└── .gitignore
```

## Usage

```bash
cd infra/terraform

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values

terraform init
terraform apply    # provision everything
terraform destroy  # tear down everything
```

## Prerequisites

- Terraform installed (`brew install hashicorp/tap/terraform`)
- AWS CLI configured (`aws configure`)
- EC2 Key Pair created — see main README Prerequisites section
- Your public IP: `curl ifconfig.me`
