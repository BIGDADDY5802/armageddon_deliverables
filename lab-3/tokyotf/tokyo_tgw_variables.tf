# # Add these variables to your existing Tokyo variables.tf

# variable "saopaulo_tgw_id" {
#   description = "São Paulo TGW ID (liberdade_tgw01). Get from São Paulo outputs after first apply."
#   type        = string
#   # No default — must be supplied after São Paulo TGW is created
# }

# variable "saopaulo_vpc_cidr" {
#   description = "São Paulo VPC CIDR. Used for Tokyo return routes and RDS SG rules."
#   type        = string
#   default     = "10.190.0.0/16" # Must match São Paulo var.vpc_cidr
# }
