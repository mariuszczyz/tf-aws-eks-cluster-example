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

# -----------------------------------------------------------------------------
# Discover the existing VPC and its subnets
# -----------------------------------------------------------------------------
# This example reuses networking that already exists (created by another team,
# stack, or account-level baseline) instead of provisioning a new VPC. We look
# the VPC up by ID and discover the subnets by tag so the example keeps working
# even if subnet IDs change.
data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = var.private_subnet_tags
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = var.public_subnet_tags
}

# -----------------------------------------------------------------------------
# Node security group
# -----------------------------------------------------------------------------
# In `use_existing_vpc` mode the vpc module does NOT create a node security
# group (it only manages resources it owns), so we create one here. The cluster
# module adds the control-plane → node ingress rules to this SG.
resource "aws_security_group" "node" {
  name        = "${local.name}-node-sg"
  description = "Security group for EKS nodes (existing-VPC example)"
  vpc_id      = data.aws_vpc.existing.id

  # Node-to-node (kubelet, kube-proxy, pod networking)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-node-sg"
  })
}

# -----------------------------------------------------------------------------
# VPC module in pass-through (existing) mode
# -----------------------------------------------------------------------------
# No aws_vpc / aws_subnet / aws_nat_* resources are created. The module just
# echoes the caller-supplied IDs back through its outputs so the rest of the
# stack can consume them exactly as it would for a managed VPC.
module "vpc" {
  source = "../../modules/vpc"

  name = local.name

  use_existing_vpc            = true
  existing_vpc_id             = data.aws_vpc.existing.id
  existing_vpc_cidr           = data.aws_vpc.existing.cidr_block
  existing_private_subnet_ids = data.aws_subnets.private.ids
  existing_public_subnet_ids  = data.aws_subnets.public.ids

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

# Cluster with encryption, deployed into the existing private subnets
module "cluster" {
  source = "../../modules/cluster"

  name                   = local.name
  eks_version            = var.eks_version
  vpc_id                 = module.vpc.vpc_id
  cluster_iam_role_arn   = module.iam.cluster_iam_role_arn
  subnet_ids             = module.vpc.private_subnet_ids
  node_security_group_id = aws_security_group.node.id

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

variable "existing_vpc_id" {
  description = "ID of the existing VPC to deploy the cluster into"
  type        = string
}

variable "private_subnet_tags" {
  description = "Tags used to discover the existing PRIVATE subnets (cluster + node groups land here)"
  type        = map(string)
  default = {
    Tier = "private"
  }
}

variable "public_subnet_tags" {
  description = "Tags used to discover the existing PUBLIC subnets (e.g. for public load balancers)"
  type        = map(string)
  default = {
    Tier = "public"
  }
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

output "vpc_id" {
  description = "ID of the existing VPC the cluster was deployed into"
  value       = data.aws_vpc.existing.id
}

output "private_subnet_ids" {
  description = "Existing private subnet IDs the cluster uses"
  value       = data.aws_subnets.private.ids
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}
