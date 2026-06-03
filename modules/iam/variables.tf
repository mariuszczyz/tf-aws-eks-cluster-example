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
