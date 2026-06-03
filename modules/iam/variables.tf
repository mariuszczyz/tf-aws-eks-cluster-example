# =============================================================================
# Module: iam — inputs
# =============================================================================
# Three categories:
#   - Identity:   name, cluster_name, region.
#   - Policies:   kubelet_/cni_/ec2_iam_policy — the three node attachments.
#                 Defaults are the AWS-managed policies EKS expects.
#   - OIDC/IRSA:  oidc_provider_url (from cluster), oidc_provider_arn (if a
#                 provider already exists outside this module),
#                 create_irsa_roles + irsa_roles for per-workload roles.
# =============================================================================

variable "create" {
  description = "Controls if IAM resources should be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "oidc_provider_arn" {
  description = "ARN of the OpenID Connect provider"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the OpenID Connect provider"
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Whether to fetch the cluster OIDC TLS cert and register an IAM OIDC provider. Must be known at plan time (cannot depend on apply-time values like the cluster's issuer URL)."
  type        = bool
  default     = true
}

variable "kubelet_iam_policy" {
  description = "IAM policy ARN for kubelet"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

variable "cni_iam_policy" {
  description = "IAM policy ARN for VPC CNI"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

variable "ec2_iam_policy" {
  description = "IAM policy ARN for EC2"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

variable "create_irsa_roles" {
  description = "Create IRSA roles"
  type        = bool
  default     = false
}

variable "irsa_roles" {
  description = "Map of IRSA roles to create"
  type = map(object({
    service_account   = string
    namespace         = string
    policies          = list(string)
    additional_policy = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
