locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "cluster"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  count = var.create ? 1 : 0

  name     = local.name
  version  = var.eks_version
  role_arn = var.cluster_iam_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
    # Intentionally do not pass node SG here — vpc_config.security_group_ids is for
    # ADDITIONAL cluster control-plane ENI SGs, not worker SGs. EKS auto-creates a
    # cluster SG and manages cluster↔node traffic via it.
  }

  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config != null ? [var.cluster_encryption_config] : []

    content {
      provider {
        key_arn = encryption_config.value.provider_arn
      }
      resources = encryption_config.value.resources
    }
  }

  tags = local.tags
}

# Addons are managed by the addons module to avoid duplicate aws_eks_addon resources.

# Cluster control-plane → node ingress (kubelet, API extension, exec/logs/port-forward).
resource "aws_vpc_security_group_ingress_rule" "cluster_to_node_kubelet" {
  count = var.create && var.node_security_group_id != "" ? 1 : 0

  security_group_id            = var.node_security_group_id
  referenced_security_group_id = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  description                  = "Cluster control plane to nodes (ephemeral)"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_to_node_https" {
  count = var.create && var.node_security_group_id != "" ? 1 : 0

  security_group_id            = var.node_security_group_id
  referenced_security_group_id = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Cluster control plane to nodes (HTTPS / webhook)"
}
