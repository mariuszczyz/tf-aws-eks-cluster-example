locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "addons"
  })

  # Normalize all addon entries to the same shape so for_each access is safe.
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

  addons = { for k, v in local.all_addons : k => v if v.create }
}

# EKS Addons
# NOTE: aws-load-balancer-controller is NOT a managed EKS addon; install via Helm + IRSA.
resource "aws_eks_addon" "main" {
  for_each = var.create ? local.addons : {}

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = each.value.version != "" ? each.value.version : null
  resolve_conflicts_on_create = each.value.resolution

  configuration_values = each.value.configuration_values

  tags = local.tags
}
