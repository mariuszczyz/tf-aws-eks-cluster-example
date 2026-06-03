provider "aws" {
  region = var.aws_region
  alias  = "primary"
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary"
}

locals {
  clusters = {
    primary = {
      name     = var.primary_cluster_name
      region   = var.aws_region
      vpc_cidr = var.primary_vpc_cidr
      provider = "aws.primary"
    }
    secondary = {
      name     = var.secondary_cluster_name
      region   = var.secondary_region
      vpc_cidr = var.secondary_vpc_cidr
      provider = "aws.secondary"
    }
  }
}

# Primary cluster
module "primary" {
  source = "../../modules/vpc"

  name = local.clusters.primary.name
  cidr = local.clusters.primary.vpc_cidr
  azs  = var.primary_availability_zones

  enable_nat_gateway = true

  providers = {
    aws = aws.primary
  }

  tags = var.tags
}

module "primary_iam" {
  source = "../../modules/iam"

  name         = local.clusters.primary.name
  cluster_name = local.clusters.primary.name
  region       = local.clusters.primary.region

  providers = {
    aws = aws.primary
  }

  tags = var.tags
}

module "primary_cluster" {
  source = "../../modules/cluster"

  name                 = local.clusters.primary.name
  vpc_id               = module.primary.vpc_id
  cluster_iam_role_arn = module.primary_iam.cluster_iam_role_arn
  subnet_ids           = module.primary.private_subnet_ids

  providers = {
    aws = aws.primary
  }

  tags = var.tags
}

module "primary_node_groups" {
  source = "../../modules/node-groups"

  name              = local.clusters.primary.name
  cluster_name      = module.primary_cluster.cluster_name
  node_iam_role_arn = module.primary_iam.node_iam_role_arn
  subnet_ids        = module.primary.private_subnet_ids

  providers = {
    aws = aws.primary
  }

  tags = var.tags
}

module "primary_addons" {
  source = "../../modules/addons"

  cluster_name = module.primary_cluster.cluster_name

  providers = {
    aws = aws.primary
  }

  tags = var.tags
}

# Secondary cluster
module "secondary" {
  source = "../../modules/vpc"

  name = local.clusters.secondary.name
  cidr = local.clusters.secondary.vpc_cidr
  azs  = var.secondary_availability_zones

  enable_nat_gateway = true

  providers = {
    aws = aws.secondary
  }

  tags = var.tags
}

module "secondary_iam" {
  source = "../../modules/iam"

  name         = local.clusters.secondary.name
  cluster_name = local.clusters.secondary.name
  region       = local.clusters.secondary.region

  providers = {
    aws = aws.secondary
  }

  tags = var.tags
}

module "secondary_cluster" {
  source = "../../modules/cluster"

  name                 = local.clusters.secondary.name
  vpc_id               = module.secondary.vpc_id
  cluster_iam_role_arn = module.secondary_iam.cluster_iam_role_arn
  subnet_ids           = module.secondary.private_subnet_ids

  providers = {
    aws = aws.secondary
  }

  tags = var.tags
}

module "secondary_node_groups" {
  source = "../../modules/node-groups"

  name              = local.clusters.secondary.name
  cluster_name      = module.secondary_cluster.cluster_name
  node_iam_role_arn = module.secondary_iam.node_iam_role_arn
  subnet_ids        = module.secondary.private_subnet_ids

  providers = {
    aws = aws.secondary
  }

  tags = var.tags
}

module "secondary_addons" {
  source = "../../modules/addons"

  cluster_name = module.secondary_cluster.cluster_name

  providers = {
    aws = aws.secondary
  }

  tags = var.tags
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "primary_cluster_name" {
  description = "Primary cluster name"
  type        = string
  default     = "primary-eks-cluster"
}

variable "secondary_cluster_name" {
  description = "Secondary cluster name"
  type        = string
  default     = "secondary-eks-cluster"
}

variable "primary_vpc_cidr" {
  description = "Primary VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  description = "Secondary VPC CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "primary_availability_zones" {
  description = "Primary availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "secondary_availability_zones" {
  description = "Secondary availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

output "primary_cluster_endpoint" {
  description = "Primary EKS cluster endpoint"
  value       = module.primary_cluster.cluster_endpoint
}

output "secondary_cluster_endpoint" {
  description = "Secondary EKS cluster endpoint"
  value       = module.secondary_cluster.cluster_endpoint
}

output "primary_cluster_name" {
  description = "Primary cluster name"
  value       = module.primary_cluster.cluster_name
}

output "secondary_cluster_name" {
  description = "Secondary cluster name"
  value       = module.secondary_cluster.cluster_name
}
