# =============================================================================
# Module: addons
# =============================================================================
# Sole owner of the `aws_eks_addon` resources for the cluster.
#
# Each supported addon has an entry in `local.all_addons` with a uniform shape
# (`create`, `version`, `resolution`, `configuration_values`). Uniformity matters
# because Terraform refuses to merge maps of differently-shaped objects, and the
# for_each below reads `each.value.version` / `each.value.configuration_values`
# unconditionally.
#
# Supported (AWS-managed) addons:
#   vpc-cni                — Amazon VPC CNI (pod networking via ENIs).
#   coredns                — cluster DNS.
#   kube-proxy             — Kubernetes proxy (iptables/ipvs).
#   eks-pod-identity-agent — newer alternative to IRSA, simpler trust model.
#   aws-ebs-csi-driver     — dynamic EBS PV provisioning.
#   aws-efs-csi-driver     — dynamic EFS PV provisioning.
#
# NOTE: `aws-load-balancer-controller` is NOT a managed EKS addon — it must be
# installed via Helm + IRSA. The `enable_load_balancer_controller` flag exists
# for API symmetry but is currently a no-op here.
# =============================================================================

locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "addons"
  })

  # Normalize all addon entries to the same shape so for_each access is safe
  # regardless of which addons the caller enabled.
  #   - `version = null` lets EKS choose the version compatible with the
  #     cluster's k8s version (the recommended default).
  #   - `resolution = "OVERWRITE"` tells EKS to win against any conflicting
  #     manual edits on the in-cluster resources.
  #   - `configuration_values` is JSON-encoded; null means "don't send a config".
  all_addons = {
    "vpc-cni" = {
      create               = var.enable_vpc_cni
      version              = var.vpc_cni_version
      resolution           = "OVERWRITE"
      configuration_values = length(var.vpc_cni_configuration) > 0 ? jsonencode(var.vpc_cni_configuration) : null
    }
    "coredns" = {
      create               = var.enable_core_dns
      version              = var.coredns_version
      resolution           = "OVERWRITE"
      configuration_values = length(var.coredns_configuration) > 0 ? jsonencode(var.coredns_configuration) : null
    }
    "kube-proxy" = {
      create               = var.enable_kube_proxy
      version              = var.kube_proxy_version
      resolution           = "OVERWRITE"
      configuration_values = null
    }
    "eks-pod-identity-agent" = {
      create               = var.enable_pod_identity
      version              = null
      resolution           = "OVERWRITE"
      configuration_values = null
    }
    "aws-ebs-csi-driver" = {
      create               = var.enable_ebs_csi_driver
      version              = null
      resolution           = "OVERWRITE"
      configuration_values = null
    }
    "aws-efs-csi-driver" = {
      create               = var.enable_efs_csi_driver
      version              = null
      resolution           = "OVERWRITE"
      configuration_values = null
    }
  }

  # Final set of addons to create — entries whose create=true.
  addons = { for k, v in local.all_addons : k => v if v.create }
}

# -----------------------------------------------------------------------------
# EKS Managed Addons
# -----------------------------------------------------------------------------
# One aws_eks_addon per enabled entry. `addon_version` falls back to null (latest
# compatible) when the caller left the variable at the default empty string.
resource "aws_eks_addon" "main" {
  for_each = var.create ? local.addons : {}

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = each.value.version != "" ? each.value.version : null
  resolve_conflicts_on_create = each.value.resolution

  configuration_values = each.value.configuration_values

  tags = local.tags
}
