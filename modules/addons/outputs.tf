# =============================================================================
# Module: addons — outputs
# =============================================================================
# Three views of the created addons:
#   addons       — full resource map (for advanced consumers).
#   addon_names  — list of created addon names (handy for asserts / dashboards).
#   addon_arns   — name → ARN map (for IAM resource conditions, etc).
# =============================================================================

output "addons" {
  description = "Map of created addon resources"
  value       = aws_eks_addon.main
}

output "addon_names" {
  description = "List of addon names"
  value       = [for name, addon in aws_eks_addon.main : name]
}

output "addon_arns" {
  description = "Map of addon ARNs"
  value       = { for name, addon in aws_eks_addon.main : name => addon.arn }
}
