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
