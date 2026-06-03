provider "aws" {
  region = var.aws_region
}

locals {
  name = var.cluster_name
  env  = var.environment

  common_tags = merge(var.tags, {
    Environment = local.env
    ManagedBy   = "terraform"
  })
}

# VPC with multi-AZ
module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cidr                 = var.vpc_cidr
  azs                  = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  tags = local.common_tags
}

# IAM with OIDC provider
module "iam" {
  source = "../../modules/iam"

  name           = local.name
  cluster_name   = local.name
  region         = var.aws_region
  cni_iam_policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  create_irsa_roles = true
  irsa_roles        = var.irsa_roles

  tags = local.common_tags
}

# Cluster with encryption
module "cluster" {
  source = "../../modules/cluster"

  name                   = local.name
  eks_version            = var.eks_version
  vpc_id                 = module.vpc.vpc_id
  cluster_iam_role_arn   = module.iam.cluster_iam_role_arn
  subnet_ids             = module.vpc.private_subnet_ids
  node_security_group_id = module.vpc.node_security_group_id

  cluster_encryption_config = {
    provider_arn = var.kms_key_arn
    resources    = ["secrets"]
  }

  enable_vpc_cni      = true
  enable_core_dns     = true
  enable_kube_proxy   = true
  enable_pod_identity = true

  tags = local.common_tags
}

# System node group
module "system_node_group" {
  source = "../../modules/node-groups"

  name              = "${local.name}-system"
  node_group_name   = "${local.name}-system-ng"
  cluster_name      = module.cluster.cluster_name
  node_iam_role_arn = module.iam.node_iam_role_arn
  subnet_ids        = module.vpc.private_subnet_ids

  instance_types = var.system_instance_types
  min_size       = var.system_min_size
  max_size       = var.system_max_size
  desired_size   = var.system_desired_size

  labels = {
    "role" = "system"
  }

  taints = [
    {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    },
  ]

  tags = local.common_tags
}

# Workload node group
module "workload_node_group" {
  source = "../../modules/node-groups"

  name              = "${local.name}-workload"
  node_group_name   = "${local.name}-workload-ng"
  cluster_name      = module.cluster.cluster_name
  node_iam_role_arn = module.iam.node_iam_role_arn
  subnet_ids        = module.vpc.private_subnet_ids

  instance_types = var.workload_instance_types
  min_size       = var.workload_min_size
  max_size       = var.workload_max_size
  desired_size   = var.workload_desired_size

  labels = {
    "role" = "workload"
  }

  tags = local.common_tags
}

# Addons
module "addons" {
  source = "../../modules/addons"

  cluster_name = module.cluster.cluster_name

  enable_vpc_cni        = true
  enable_core_dns       = true
  enable_kube_proxy     = true
  enable_pod_identity   = true
  enable_ebs_csi_driver = true

  tags = local.common_tags
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "eks_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway"
  type        = bool
  default     = false
}

variable "system_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_min_size" {
  description = "Minimum size for system node group"
  type        = number
  default     = 2
}

variable "system_max_size" {
  description = "Maximum size for system node group"
  type        = number
  default     = 5
}

variable "system_desired_size" {
  description = "Desired size for system node group"
  type        = number
  default     = 3
}

variable "workload_instance_types" {
  description = "Instance types for workload node group"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "workload_min_size" {
  description = "Minimum size for workload node group"
  type        = number
  default     = 2
}

variable "workload_max_size" {
  description = "Maximum size for workload node group"
  type        = number
  default     = 20
}

variable "workload_desired_size" {
  description = "Desired size for workload node group"
  type        = number
  default     = 5
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for cluster encryption"
  type        = string
  default     = ""
}

variable "irsa_roles" {
  description = "IRSA roles"
  type = map(object({
    service_account   = string
    namespace         = string
    policies          = list(string)
    additional_policy = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.cluster.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.cluster.cluster_name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.cluster.cluster_oidc_issuer_url
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}
