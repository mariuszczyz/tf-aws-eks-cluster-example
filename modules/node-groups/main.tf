locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "node-groups"
  })
}

# EKS Managed Node Group
resource "aws_eks_node_group" "main" {
  count = var.create ? 1 : 0

  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_iam_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  ami_type        = var.ami_type
  release_version = var.release_version != "" ? var.release_version : null
  disk_size       = var.disk_size

  scaling_config {
    min_size     = var.min_size
    max_size     = var.max_size
    desired_size = var.desired_size
  }

  # AWS rejects update_config when both fields are set; emit only the one provided.
  update_config {
    max_unavailable            = var.update_config.max_unavailable
    max_unavailable_percentage = var.update_config.max_unavailable == null ? var.update_config.max_unavailable_percentage : null
  }

  labels = var.labels
  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = local.tags
}
