# =============================================================================
# Module: cluster
# =============================================================================
# Creates the EKS control plane plus the two SG rules required for the cluster
# to talk to its worker nodes.
#
#   aws_eks_cluster.main           - the control plane.
#   aws_vpc_security_group_ingress_rule.cluster_to_node_kubelet  - 1025-65535/tcp
#   aws_vpc_security_group_ingress_rule.cluster_to_node_https    - 443/tcp
#
# Notably this module DOES NOT create any aws_eks_addon resources — the addons
# module owns those. Splitting ownership avoids a duplicate-resource conflict
# (EKS rejects creating the same addon twice).
#
# Optional envelope encryption of cluster secrets is supported via
# `cluster_encryption_config` (KMS-backed).
# =============================================================================

locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "cluster"
  })
}

# -----------------------------------------------------------------------------
# EKS Cluster (control plane)
# -----------------------------------------------------------------------------
# AWS provisions the actual API server, etcd, scheduler, controller-manager.
# We supply: name, k8s version, the service role, and the subnets in which
# EKS attaches its cross-AZ ENIs.
resource "aws_eks_cluster" "main" {
  count = var.create ? 1 : 0

  name     = local.name
  version  = var.eks_version
  role_arn = var.cluster_iam_role_arn

  # Implicit dependency on the IAM policy attachments via a synthetic input —
  # forces ordering without a wide module-level depends_on (which would cycle
  # via the OIDC URL feeding back into iam).
  lifecycle {
    precondition {
      condition     = length(var.iam_role_policies_ready) >= 0
      error_message = "iam_role_policies_ready must be a list."
    }
  }

  vpc_config {
    subnet_ids = var.subnet_ids
    # Intentionally do not pass node SG here — vpc_config.security_group_ids is for
    # ADDITIONAL cluster control-plane ENI SGs, not worker SGs. EKS auto-creates a
    # cluster SG (exposed as `cluster_security_group_id`) and manages cluster↔node
    # traffic via it.
  }

  # Optional KMS envelope encryption of Kubernetes Secrets at rest.
  # Provide a KMS key ARN + resources=["secrets"] to enable.
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

# -----------------------------------------------------------------------------
# Cluster → Node Security Group rules
# -----------------------------------------------------------------------------
# The node SG (from the vpc module) starts with only self-ingress. EKS needs
# two paths from the control-plane SG into the node SG:
#
#   1025-65535/tcp - kubelet API, exec, port-forward, log streaming.
#                    Without this, `kubectl exec` and `kubectl logs` time out.
#   443/tcp        - aggregated API server requests + webhook callbacks
#                    (mutating/validating admission webhooks, metrics-server, etc.).
#
# We can only emit these rules AFTER the cluster exists, since the source SG
# is the EKS-managed `cluster_security_group_id`.
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
