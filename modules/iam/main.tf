# =============================================================================
# Module: iam
# =============================================================================
# IAM scaffolding for EKS. Three groups of resources:
#
#   1. Cluster service role    — trusted by eks.amazonaws.com; lets EKS manage
#                                ENIs, LBs, log groups, etc.
#                                Single attached policy: AmazonEKSClusterPolicy.
#
#   2. Node instance role      — trusted by ec2.amazonaws.com; assumed by
#                                worker EC2 instances. Three policies:
#                                  - AmazonEKSWorkerNodePolicy  (kubelet auth)
#                                  - AmazonEKS_CNI_Policy       (VPC CNI ENI mgmt)
#                                  - AmazonEC2ContainerRegistryReadOnly (image pulls)
#
#   3. OIDC + IRSA             — registers the cluster's OIDC issuer as an IAM
#                                identity provider so in-cluster ServiceAccounts
#                                can assume IAM roles (IRSA). Optional per-workload
#                                roles are created from var.irsa_roles.
#
# OIDC provider creation is conditional on `oidc_provider_url` being non-empty
# (i.e. the cluster exists). This avoids a chicken-and-egg failure when the
# cluster hasn't been created yet.
# =============================================================================

locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "iam"
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------
# Used by the EKS control plane itself to call AWS APIs on the user's behalf
# (managing ENIs, route table tweaks, LB hooks, CloudWatch log groups, etc).
resource "aws_iam_role" "cluster" {
  count = var.create ? 1 : 0

  name = "${local.name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Attaches the single AWS-managed policy EKS requires on its service role.
resource "aws_iam_role_policy_attachment" "cluster" {
  count = var.create ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

# -----------------------------------------------------------------------------
# EKS Node IAM Role
# -----------------------------------------------------------------------------
# Assumed by every worker EC2 instance. Used by kubelet to register with the
# cluster, by the VPC CNI to attach ENIs/secondary IPs, and by containerd to
# pull from ECR.
resource "aws_iam_role" "node" {
  count = var.create ? 1 : 0

  name = "${local.name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# Three policy attachments, keyed by purpose (not by ARN) so a user override
# can replace any one of them without colliding in for_each.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = var.create ? {
    kubelet = var.kubelet_iam_policy
    cni     = var.cni_iam_policy
    ec2     = var.ec2_iam_policy
  } : {}

  policy_arn = each.value
  role       = aws_iam_role.node[0].name
}

# -----------------------------------------------------------------------------
# OIDC Provider — enables IRSA
# -----------------------------------------------------------------------------
# Fetches the cluster's OIDC issuer TLS cert to compute the SHA-1 thumbprint
# AWS requires when registering the OIDC provider. Only runs when an OIDC
# issuer URL is known (i.e. the cluster has been created).
data "tls_certificate" "eks" {
  count = var.create && var.create_oidc_provider ? 1 : 0

  url = var.oidc_provider_url
}

# Registers the cluster's OIDC issuer with IAM. Skipped when the caller passes
# a pre-existing `oidc_provider_arn` (e.g. another module already created one)
# or when no URL is available yet.
resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create && var.create_oidc_provider && var.oidc_provider_arn == "" ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = try(data.tls_certificate.eks[0].certificates[*].sha1_fingerprint, [])
  url             = var.oidc_provider_url
}

# -----------------------------------------------------------------------------
# IRSA Roles — per-workload IAM roles assumable by Kubernetes ServiceAccounts
# -----------------------------------------------------------------------------
# For each entry in `var.irsa_roles`, creates:
#   - an aws_iam_role whose trust policy ties it to a specific
#     `system:serviceaccount:<namespace>:<service_account>` subject claim,
#   - either an inline custom aws_iam_policy (from the `policies` list) or an
#     attachment of an externally-managed `additional_policy` ARN.
# Disabled by default — set `create_irsa_roles = true` to enable.
resource "aws_iam_role" "irsa" {
  for_each = var.create && var.create_irsa_roles ? var.irsa_roles : {}

  name = "${local.name}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn != "" ? var.oidc_provider_arn : try(aws_iam_openid_connect_provider.eks[0].arn, "")
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# Attach EITHER the caller-supplied `additional_policy` ARN OR the inline policy
# generated below — never both. Inline wins only when additional_policy is empty/null.
resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = var.create && var.create_irsa_roles ? var.irsa_roles : {}

  policy_arn = coalesce(each.value.additional_policy, "") != "" ? each.value.additional_policy : aws_iam_policy.irsa[each.key].arn
  role       = aws_iam_role.irsa[each.key].name
}

# Inline policy generated from each IRSA role's `policies` list (Action[]).
# Resource is "*" — narrow this via `additional_policy` if least-privilege matters.
resource "aws_iam_policy" "irsa" {
  for_each = var.create && var.create_irsa_roles ? var.irsa_roles : {}

  name        = "${local.name}-${each.key}"
  description = "IRSA policy for ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = each.value.policies
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}
