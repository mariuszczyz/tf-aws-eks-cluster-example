locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "iam"
  })
}

# EKS Cluster IAM Role
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

resource "aws_iam_role_policy_attachment" "cluster" {
  count = var.create ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

# EKS Node IAM Role
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

resource "aws_iam_role_policy_attachment" "node" {
  for_each = var.create ? {
    kubelet = var.kubelet_iam_policy
    cni     = var.cni_iam_policy
    ec2     = var.ec2_iam_policy
  } : {}

  policy_arn = each.value
  role       = aws_iam_role.node[0].name
}

# OIDC Provider
data "tls_certificate" "eks" {
  count = var.create && var.oidc_provider_url != "" ? 1 : 0

  url = var.oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create && var.oidc_provider_arn == "" && var.oidc_provider_url != "" ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = try(data.tls_certificate.eks[0].certificates[*].sha1_fingerprint, [])
  url             = var.oidc_provider_url
}

# IRSA Roles
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

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = var.create && var.create_irsa_roles ? var.irsa_roles : {}

  policy_arn = coalesce(each.value.additional_policy, "") != "" ? each.value.additional_policy : aws_iam_policy.irsa[each.key].arn
  role       = aws_iam_role.irsa[each.key].name
}

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
