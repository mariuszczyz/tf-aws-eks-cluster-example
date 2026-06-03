output "node_group_arn" {
  description = "ARN of the node group"
  value       = try(aws_eks_node_group.main[0].arn, "")
}

output "node_group_name" {
  description = "Name of the node group"
  value       = try(aws_eks_node_group.main[0].node_group_name, "")
}

output "node_group_status" {
  description = "Status of the node group"
  value       = try(aws_eks_node_group.main[0].status, "")
}

output "node_group_id" {
  description = "ID of the node group"
  value       = try(aws_eks_node_group.main[0].id, "")
}
