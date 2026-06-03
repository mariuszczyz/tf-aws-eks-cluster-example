# =============================================================================
# Root module — eks-cluster
# =============================================================================
# Composes the five building-block submodules into a complete EKS cluster:
#
#   vpc          → networking (VPC, subnets, NAT, route tables, node SG)
#   iam          → cluster + node IAM roles, OIDC provider, IRSA roles
#   cluster      → the EKS control plane and cluster→node SG rules
#   node_groups  → an EKS-managed worker node group
#   addons       → EKS-managed addons (CNI, CoreDNS, kube-proxy, etc.)
#
# Each submodule honors a `create` flag so the caller can disable individual
# layers (e.g. reuse an existing VPC, manage IAM outside this module).
#
# Resource ordering is enforced with explicit `depends_on` on the cluster and
# node_groups modules to avoid two classic EKS races:
#   1. EKS cluster creation before its IAM role policy is attached.
#   2. Node group launch before the node role's policies are attached.
# =============================================================================

locals {
  # Single name source used across child modules so resource names stay consistent.
  name = var.name

  # All resources get the user-supplied tags PLUS a Module tag for traceability.
  tags = merge(var.tags, {
    Module = "eks-cluster"
  })

  # EKS cluster needs subnets in multiple AZs. Give it both public + private when
  # available so the control plane can attach LBs in either tier; nodes still
  # land in private when `use_private_subnets` is true (the default).
  cluster_subnet_ids = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids    = var.use_private_subnets ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
}

# -----------------------------------------------------------------------------
# VPC — network foundation
# -----------------------------------------------------------------------------
# Creates the VPC, public/private subnets per AZ, IGW, NAT gateway(s), route
# tables, and the worker-node security group. Can be skipped (`create_vpc=false`)
# when reusing an existing VPC.
module "vpc" {
  source = "./modules/vpc"

  create = var.create_vpc
  name   = local.name
  cidr   = var.vpc_cidr
  azs    = var.azs
  tags   = local.tags
}

# -----------------------------------------------------------------------------
# IAM — roles and OIDC provider
# -----------------------------------------------------------------------------
# Creates:
#   - EKS cluster service role (trusted by eks.amazonaws.com).
#   - EKS node instance role (trusted by ec2.amazonaws.com) with the three
#     AWS-managed policies every worker needs.
#   - OIDC provider tied to the cluster's issuer URL (enables IRSA — IAM
#     Roles for Service Accounts).
#   - Optional IRSA roles for in-cluster workloads.
#
# `oidc_provider_url` is sourced from the cluster output; the OIDC provider
# resource is gated on that URL being non-empty so a plan with `create_cluster=false`
# still works.
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

# -----------------------------------------------------------------------------
# Cluster — EKS control plane
# -----------------------------------------------------------------------------
# Creates the EKS cluster itself plus the two cluster→node security-group
# ingress rules that EKS expects (1025-65535 TCP for kubelet/exec, 443 for
# webhooks). Addons are NOT created here — that's the addons module's job —
# to avoid duplicate `aws_eks_addon` resources.
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

  # Narrow ordering dep: wait for the cluster role's policy attachments without
  # depending on the entire iam module (which would cycle via oidc_provider_url).
  iam_role_policies_ready = module.iam.cluster_role_policies_ready
}

# -----------------------------------------------------------------------------
# Node groups — managed worker nodes
# -----------------------------------------------------------------------------
# Creates an EKS-managed node group. AWS handles the underlying Auto Scaling
# Group, EC2 launch template, and lifecycle. The cluster must exist and the
# node role's policies must be attached BEFORE node creation, otherwise EKS
# returns NodeCreationFailure when kubelet can't authenticate.
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

  # Wait for node-role policy attachments to exist before launching nodes.
  # cluster_name input already creates the implicit dep on the cluster.
  iam_role_policies_ready = module.iam.node_role_policies_ready
}

# -----------------------------------------------------------------------------
# Addons — EKS-managed addons
# -----------------------------------------------------------------------------
# Single owner for the `aws_eks_addon` resources. Each `enable_*` flag toggles
# one addon. Versions default to "" → EKS picks the version compatible with the
# cluster's k8s version.
#
# NOTE: `aws-load-balancer-controller` is NOT a managed EKS addon — it must be
# installed via Helm + IRSA. The flag exists for API symmetry but is currently
# a no-op inside the module.
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
