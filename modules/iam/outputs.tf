# =============================================================================
# Module: iam — outputs
# =============================================================================
# Role ARNs are wrapped in try() so they're safe to reference when create=false.
# `cluster_role_policies_ready` / `node_role_policies_ready` are *ordering*
# outputs — depend on these (not the role ARN) to guarantee that the policy
# attachments exist before downstream resources are created.
# =============================================================================

output "cluster_iam_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = try(aws_iam_role.cluster[0].arn, "")
}

output "cluster_iam_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = try(aws_iam_role.cluster[0].name, "")
}

output "node_iam_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = try(aws_iam_role.node[0].arn, "")
}

output "node_iam_role_name" {
  description = "Name of the EKS node IAM role"
  value       = try(aws_iam_role.node[0].name, "")
}

output "node_security_group_id" {
  description = "ID of the node security group (empty if not created)"
  value       = ""
}

output "node_security_group_arn" {
  description = "ARN of the node security group (empty if not created)"
  value       = ""
}

output "oidc_provider_arn" {
  description = "ARN of the OpenID Connect provider"
  value       = var.oidc_provider_arn != "" ? var.oidc_provider_arn : try(aws_iam_openid_connect_provider.eks[0].arn, "")
}

output "oidc_provider_url" {
  description = "URL of the OpenID Connect provider"
  value       = try(aws_iam_openid_connect_provider.eks[0].url, var.oidc_provider_url)
}

output "irsa_role_arns" {
  description = "ARNs of the IRSA roles"
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}

# Synthetic outputs that resolve only after policy attachments are created.
# Downstream modules consume these to guarantee ordering (avoids the classic
# EKS NodeCreationFailure race).
output "cluster_role_policies_ready" {
  description = "Resolves after cluster IAM role policy attachments are in place"
  value       = [for a in aws_iam_role_policy_attachment.cluster : a.id]
}

output "node_role_policies_ready" {
  description = "Resolves after node IAM role policy attachments are in place"
  value       = [for k, a in aws_iam_role_policy_attachment.node : a.id]
}
