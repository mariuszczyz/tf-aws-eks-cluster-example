# EKS Cluster Terraform Modules

Reusable Terraform modules for deploying AWS EKS clusters following [AWS EKS Best Practices](https://github.com/aws/aws-eks-best-practices) and the [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) module patterns.

## Modules

| Module | Description |
|--------|-------------|
| [vpc](modules/vpc/) | VPC with public/private subnets, NAT Gateway, and routing |
| [iam](modules/iam/) | IAM roles for EKS cluster, nodes, OIDC provider, and IRSA |
| [cluster](modules/cluster/) | EKS cluster with addons (VPC CNI, CoreDNS, kube-proxy, pod identity) |
| [node-groups](modules/node-groups/) | EKS managed node groups with scaling and taints |
| [addons](modules/addons/) | EKS addons with configurable enable/disable |

## Architecture

```
VPC
├── Public Subnets (multi-AZ)
│   └── Internet Gateway
└── Private Subnets (multi-AZ)
    └── NAT Gateway

EKS Cluster
├── Control Plane
├── Addons (VPC CNI, CoreDNS, kube-proxy, pod identity)
└── Node Groups
    ├── System nodes (CriticalAddonsOnly taint)
    └── Workload nodes
```

## Usage

### Basic

Deploy a complete EKS cluster using the root module:

```hcl
module "eks" {
  source = "."

  aws_region       = "us-east-1"
  cluster_name     = "my-eks-cluster"
  vpc_cidr         = "10.0.0.0/16"
  eks_version      = "1.29"
  instance_types   = ["t3.medium"]
  min_size         = 1
  max_size         = 10
  desired_size     = 2
  enable_ebs_csi_driver = true
}
```

### Root Module

The root module composes all sub-modules into a single deployable unit:

```hcl
module "eks" {
  source = "."

  name                  = "my-eks-cluster"
  aws_region            = "us-east-1"
  vpc_cidr              = "10.0.0.0/16"
  eks_version           = "1.29"
  instance_types        = ["t3.medium"]
  min_size              = 1
  max_size              = 10
  desired_size          = 2
  use_private_subnets   = true

  enable_vpc_cni        = true
  enable_core_dns       = true
  enable_kube_proxy     = true
  enable_pod_identity   = true
  enable_ebs_csi_driver = true

  taints = [
    {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  ]

  tags = {
    Environment = "production"
  }
}
```

### Standalone Modules

Each module can be used independently:

```hcl
# VPC only
module "vpc" {
  source = "./modules/vpc"
  name   = "my-vpc"
  cidr   = "10.0.0.0/16"
}

# Cluster with existing VPC
module "cluster" {
  source = "./modules/cluster"
  name                 = "my-cluster"
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  cluster_iam_role_arn = module.iam.cluster_iam_role_arn
}
```

### Examples

- [basic](examples/basic/) — Minimal EKS cluster deployment
- [production](examples/production/) — Production-ready with encryption, multiple node groups, and full addon suite
- [multi-cluster](examples/multi-cluster/) — Multiple clusters across regions

## Key Features

- **DRY**: Locals and maps reduce repetition
- **Modular**: Independent modules with clean interfaces
- **Multi-AZ**: Automatic multi-AZ subnet distribution
- **Encryption**: KMS encryption for cluster secrets
- **IRSA**: IAM Roles for Service Accounts support
- **Pod Identity**: EKS Pod Identity Agent integration
- **Extensible**: Easy to add new addons and node groups

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 6.0 |
| tls | ~> 4.0 |
