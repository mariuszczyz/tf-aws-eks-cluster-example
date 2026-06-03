# =============================================================================
# Module: vpc — inputs
# =============================================================================
# - `create`            kill switch for the whole module.
# - `use_existing_vpc`  pass-through mode: reuse caller-supplied VPC/subnets
#                       and skip all aws_vpc / aws_subnet / aws_nat_* resources.
# - NAT controls        enable_nat_gateway + single_nat_gateway. Default is
#                       single shared NAT (cheaper) — flip to false for prod HA.
# =============================================================================

variable "create" {
  description = "Controls if VPC resources should be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the VPC"
  type        = string
  default     = "eks-cluster"
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 support"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "use_existing_vpc" {
  description = "Use an existing VPC instead of creating one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of the existing VPC to use (only used when use_existing_vpc is true)"
  type        = string
  default     = ""
}

variable "existing_vpc_cidr" {
  description = "CIDR of the existing VPC (required when use_existing_vpc is true)"
  type        = string
  default     = ""
}

variable "existing_subnet_ids" {
  description = "DEPRECATED — use existing_public_subnet_ids / existing_private_subnet_ids. Fallback list of subnet IDs used for both public and private outputs when the split lists are empty."
  type        = list(string)
  default     = []
}

variable "existing_public_subnet_ids" {
  description = "List of existing PUBLIC subnet IDs (used when use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "List of existing PRIVATE subnet IDs (used when use_existing_vpc is true)"
  type        = list(string)
  default     = []
}
