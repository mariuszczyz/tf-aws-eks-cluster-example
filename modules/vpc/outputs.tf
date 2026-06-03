# =============================================================================
# Module: vpc — outputs
# =============================================================================
# Outputs are tolerant of `create=false` / `use_existing_vpc=true`:
#   - Scalar outputs fall back to "" via try() when the resource has count=0.
#   - List outputs return [] when no subnets / NAT gateways were created.
# Callers should treat empty values as "this layer was disabled".
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.use_existing_vpc ? var.existing_vpc_id : try(aws_vpc.main[0].id, "")
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = var.use_existing_vpc ? var.existing_vpc_cidr : try(aws_vpc.main[0].cidr_block, "")
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value = var.use_existing_vpc ? (
    length(var.existing_public_subnet_ids) > 0 ? var.existing_public_subnet_ids : var.existing_subnet_ids
  ) : aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value = var.use_existing_vpc ? (
    length(var.existing_private_subnet_ids) > 0 ? var.existing_private_subnet_ids : var.existing_subnet_ids
  ) : aws_subnet.private[*].id
}

output "azs" {
  description = "Availability zones"
  value       = var.azs
}

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = try(aws_security_group.node[0].id, "")
}

output "node_security_group_arn" {
  description = "ARN of the node security group"
  value       = try(aws_security_group.node[0].arn, "")
}
