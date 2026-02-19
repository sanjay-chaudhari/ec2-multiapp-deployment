variable "region" {
  default = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for your region"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name"
}

variable "your_ip" {
  description = "Your public IP in CIDR format e.g. 203.0.113.10/32"
}
