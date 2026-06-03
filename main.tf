locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "eks-cluster"
  })

  # EKS cluster needs subnets in multiple AZs. Give it both public + private when available
  # so the control plane can attach LBs in either tier; nodes still land in private when requested.
  cluster_subnet_ids = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids    = var.use_private_subnets ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
}

# VPC
module "vpc" {
  source = "./modules/vpc"

  create = var.create_vpc
  name   = local.name
  cidr   = var.vpc_cidr
  azs    = var.azs
  tags   = local.tags
}

# IAM
module "iam" {
  source = "./modules/iam"

  create             = var.create_iam
  name               = local.name
  cluster_name       = var.cluster_name
  region             = var.aws_region
  kubelet_iam_policy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  cni_iam_policy     = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ec2_iam_policy     = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  oidc_provider_url  = try(module.cluster.cluster_oidc_issuer_url, "")
  tags               = local.tags
}

# Cluster
module "cluster" {
  source = "./modules/cluster"

  create                 = var.create_cluster
  name                   = local.name
  vpc_id                 = module.vpc.vpc_id
  eks_version            = var.eks_version
  cluster_iam_role_arn   = module.iam.cluster_iam_role_arn
  subnet_ids             = local.cluster_subnet_ids
  node_security_group_id = module.vpc.node_security_group_id

  enable_vpc_cni      = var.enable_vpc_cni
  enable_core_dns     = var.enable_core_dns
  enable_kube_proxy   = var.enable_kube_proxy
  enable_pod_identity = var.enable_pod_identity

  tags = local.tags

  # Ensure cluster role policy attachments exist before cluster creation.
  depends_on = [module.iam]
}

# Node Groups
module "node_groups" {
  source = "./modules/node-groups"

  create            = var.create_node_groups
  name              = local.name
  cluster_name      = module.cluster.cluster_name
  node_iam_role_arn = module.iam.node_iam_role_arn
  subnet_ids        = local.node_subnet_ids

  instance_types = var.instance_types
  min_size       = var.min_size
  max_size       = var.max_size
  desired_size   = var.desired_size

  labels = var.labels
  taints = var.taints

  tags = local.tags

  # Avoid the classic EKS NodeCreationFailure: node role policies must be attached
  # before the node group launches instances.
  depends_on = [module.iam, module.cluster]
}

# Addons
module "addons" {
  source = "./modules/addons"

  create = var.create_addons
  name   = local.name

  cluster_name = module.cluster.cluster_name

  enable_vpc_cni                  = var.enable_vpc_cni
  enable_core_dns                 = var.enable_core_dns
  enable_kube_proxy               = var.enable_kube_proxy
  enable_pod_identity             = var.enable_pod_identity
  enable_ebs_csi_driver           = var.enable_ebs_csi_driver
  enable_efs_csi_driver           = var.enable_efs_csi_driver
  enable_load_balancer_controller = var.enable_load_balancer_controller

  tags = local.tags
}
