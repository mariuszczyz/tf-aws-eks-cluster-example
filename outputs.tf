# =============================================================================
# Root module outputs
# =============================================================================
# All outputs are wrapped in `try(..., "" / [])` so consumers can still plan
# against this module when child layers are disabled (e.g. create_cluster=false).
# Outputs pass through to the corresponding submodule output.
# =============================================================================

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = try(module.cluster.cluster_endpoint, "")
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = try(module.cluster.cluster_name, "")
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = try(module.cluster.cluster_arn, "")
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = try(module.cluster.cluster_version, "")
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = try(module.cluster.cluster_oidc_issuer_url, "")
}

output "cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = try(module.cluster.cluster_certificate_authority, "")
}

output "vpc_id" {
  description = "VPC ID"
  value       = try(module.vpc.vpc_id, "")
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = try(module.vpc.vpc_cidr, "")
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = try(module.vpc.public_subnet_ids, [])
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = try(module.vpc.private_subnet_ids, [])
}

output "node_group_arn" {
  description = "Node group ARN"
  value       = try(module.node_groups.node_group_arn, "")
}

output "node_group_name" {
  description = "Node group name"
  value       = try(module.node_groups.node_group_name, "")
}

output "addon_names" {
  description = "Addon names"
  value       = try(module.addons.addon_names, [])
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = try(module.iam.oidc_provider_url, "")
}
