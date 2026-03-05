variable "project_name" {
  description = "Prefix for naming. Tokyo uses shinjuku-* convention."
  type        = string
  default     = "shinjuku"
}

variable "vpc_cidr" {
  description = "Tokyo VPC CIDR. Must not overlap with São Paulo (10.190.0.0/16)."
  type        = string
  default     = "10.52.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for Tokyo."
  type        = list(string)
  default     = ["10.52.1.0/24", "10.52.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for Tokyo. RDS and TGW attachment live here."
  type        = list(string)
  default     = ["10.52.101.0/24", "10.52.102.0/24"]
}

variable "azs" {
  description = "Availability zones in ap-northeast-1."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "ec2_ami_id" {
  description = "AMI ID for ap-northeast-1. Must be valid in Tokyo region."
  type        = string
  default     = "ami-0d52744d6551d851e" # Amazon Linux 2 ap-northeast-1 — verify current
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_engine" {
  type    = string
  default = "mysql"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "labdb"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "ShinjukuRDSPass123" # TODO: student supplies
}

variable "sns_email_endpoint" {
  type    = string
  default = "firstofmyname5802@outlook.com"
}

variable "my_ip" {
  description = "Your public IP for SSH access."
  type        = string
  default     = "35.135.236.158/32"
}

# ── Cross-region TGW inputs ───────────────────────────────────────────────

variable "saopaulo_tgw_id" {
  description = "São Paulo TGW ID (liberdade_tgw01). Supplied after São Paulo first apply."
  type        = string
  default = "tgw-0b1e0186e6739b3ad"
}

variable "saopaulo_vpc_cidr" {
  description = "São Paulo VPC CIDR. Used for RDS SG rules and TGW return routes."
  type        = string
  default     = "10.190.0.0/16"
}
