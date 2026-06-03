output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = try(aws_eks_cluster.main[0].endpoint, "")
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = try(aws_eks_cluster.main[0].name, "")
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = try(aws_eks_cluster.main[0].arn, "")
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = try(aws_eks_cluster.main[0].version, "")
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = try(aws_eks_cluster.main[0].identity[0].oidc[0].issuer, "")
}

output "cluster_certificate_authority" {
  description = "EKS cluster certificate authority"
  value       = try(aws_eks_cluster.main[0].certificate_authority[0].data, "")
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = try(aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id, "")
}
