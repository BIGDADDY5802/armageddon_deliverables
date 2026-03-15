variable "aws_region" {
  description = "AWS Region for the DAWG fleet to patrol."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for naming. Students should change from 'chewbacca' to their own."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR (use 10.180.0.0/16 as instructed)."
  type        = string
  default     = "10.180.0.0/16" # TODO: student supplies
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (use 10.180.0.0/24)."
  type        = list(string)
  default     = ["10.180.1.0/24", "10.180.2.0/24"] # TODO: student supplies
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (use 10.180.0.0/24)."
  type        = list(string)
  default     = ["10.180.101.0/24", "10.180.102.0/24"] # TODO: student supplies
}

variable "azs" {
  description = "Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] # TODO: student supplies
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-068c0051b15cdb816" # TODO
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "labmysql" # Students can change
}

variable "db_username" {
  description = "DB master username (students should use Secrets Manager in 1B/1C)."
  type        = string
  default     = "admin" # TODO: student supplies
}

variable "db_password" {
  description = "DB master password (DO NOT hardcode in real life; for lab only)."
  type        = string
  sensitive   = true
  default     = "DawgsRDSPass123" # TODO: student supplies
}

variable "sns_email_endpoint" {
  description = "Email for SNS subscription (PagerDuty simulation)."
  type        = string
  default     = "firstofmyname5802@outlook.com" # TODO: student supplies
}

variable "domain_name" {
  description = "Base domain students registered (e.g., thedawgs2025.click)."
  type        = string
  default     = "thedawgs2025.click"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.thedawgs2025.click)."
  type        = string
  default     = "app"
}

variable "certificate_validation_method" {
  description = "ACM validation method. Students can do DNS (Route53) or EMAIL."
  type        = string
  default     = "DNS"
}

# variable "enable_waf" {
#   description = "Toggle WAF creation."
#   type        = bool
#   default     = true
# }

# variable "alb_5xx_threshold" {
#   description = "Alarm threshold for ALB 5xx count."
#   type        = number
#   default     = 10
# }

# variable "alb_5xx_period_seconds" {
#   description = "CloudWatch alarm period."
#   type        = number
#   default     = 300
# }

# variable "alb_5xx_evaluation_periods" {
#   description = "Evaluation periods for alarm."
#   type        = number
#   default     = 1
# }