# =============================================================================
# Module: node-groups
# =============================================================================
# Creates a single EKS-managed node group. AWS handles the underlying Auto
# Scaling Group, launch template, AMI patching, and cordon/drain on update.
#
# Why "managed" rather than self-managed nodes:
#   - AWS rolls AMI updates automatically (drain + replace, respecting PDBs).
#   - Tags, labels, and taints are first-class fields, not user_data hacks.
#   - Spot diversification, custom launch templates, and OS upgrades all flow
#     through one API.
#
# Caller MUST ensure (via depends_on) that the node IAM role's policies are
# attached BEFORE this resource is created. Otherwise kubelet fails to register
# and EKS returns NodeCreationFailure.
# =============================================================================

locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "node-groups"
  })
}

# -----------------------------------------------------------------------------
# EKS Managed Node Group
# -----------------------------------------------------------------------------
# - scaling_config: cluster-autoscaler / karpenter can change desired_size after
#   creation; the lifecycle block (not added here) `ignore_changes = [scaling_config[0].desired_size]`
#   is a common follow-up if you adopt an autoscaler.
# - update_config: AWS REJECTS the request if BOTH max_unavailable AND
#   max_unavailable_percentage are set. We emit at most one — prefer the
#   absolute count when the caller provides it, otherwise the percentage.
# - taints: dynamic block iterates the caller's list; effects must be one of
#   NO_SCHEDULE, NO_EXECUTE, PREFER_NO_SCHEDULE (EKS API form).
resource "aws_eks_node_group" "main" {
  count = var.create ? 1 : 0

  # Implicit dependency on node-role policy attachments — see iam_role_policies_ready
  # variable doc for rationale.
  lifecycle {
    precondition {
      condition     = length(var.iam_role_policies_ready) >= 0
      error_message = "iam_role_policies_ready must be a list."
    }
  }

  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_iam_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.instance_types
  ami_type        = var.ami_type
  # Null lets EKS pick the latest GA AMI for the cluster's k8s version.
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

  # Taints are emitted only when the caller provides them — an empty `var.taints`
  # produces zero `taint` blocks.
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
