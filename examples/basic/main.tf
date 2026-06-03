provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  name = var.cluster_name
  cidr = var.vpc_cidr

  tags = var.tags
}

# IAM
module "iam" {
  source = "../../modules/iam"

  name         = var.cluster_name
  cluster_name = var.cluster_name
  region       = var.aws_region

  tags = var.tags
}

# Cluster
module "cluster" {
  source = "../../modules/cluster"

  name                   = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  cluster_iam_role_arn   = module.iam.cluster_iam_role_arn
  subnet_ids             = module.vpc.private_subnet_ids
  node_security_group_id = module.vpc.node_security_group_id

  enable_vpc_cni      = true
  enable_core_dns     = true
  enable_kube_proxy   = true
  enable_pod_identity = true

  tags = var.tags
}

# Node Groups
module "node_groups" {
  source = "../../modules/node-groups"

  name              = var.cluster_name
  cluster_name      = module.cluster.cluster_name
  node_iam_role_arn = module.iam.node_iam_role_arn
  subnet_ids        = module.vpc.private_subnet_ids

  instance_types = var.instance_types
  min_size       = var.min_size
  max_size       = var.max_size
  desired_size   = var.desired_size

  tags = var.tags
}

# Addons
module "addons" {
  source = "../../modules/addons"

  cluster_name = module.cluster.cluster_name

  enable_vpc_cni      = true
  enable_core_dns     = true
  enable_kube_proxy   = true
  enable_pod_identity = true

  tags = var.tags
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_types" {
  description = "List of instance types for node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
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

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.cluster.cluster_name} --region ${var.aws_region}"
}
