# =============================================================================
# Module: cluster — inputs
# =============================================================================
# Required: vpc_id, subnet_ids, cluster_iam_role_arn (from iam module).
# Optional: node_security_group_id (enables cluster→node SG rules), eks_version,
# cluster_encryption_config (KMS envelope encryption for k8s Secrets).
#
# The enable_* / *_version variables and vpc_cni_/kubelet_/ec2_iam_policy
# variables are legacy passthroughs from when this module also created addons
# and IAM. They are unused in current code but kept for API stability — remove
# in a future major version.
# =============================================================================

variable "create" {
  description = "Controls if EKS cluster resources should be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "eks_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "cluster_iam_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  type        = string
}

variable "node_security_group_id" {
  description = "ID of the node security group"
  type        = string
  default     = ""
}

variable "create_node_security_group_rules" {
  description = "Whether to create the cluster→node SG ingress rules. Must be known at plan time (cannot depend on unknown values like SG IDs computed during apply)."
  type        = bool
  default     = true
}

variable "vpc_cni_iam_policy" {
  description = "IAM policy ARN for VPC CNI"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

variable "kubelet_iam_policy" {
  description = "IAM policy ARN for kubelet"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

variable "ec2_iam_policy" {
  description = "IAM policy ARN for EC2"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

variable "enable_pod_identity" {
  description = "Enable EKS pod identity"
  type        = bool
  default     = true
}

variable "enable_core_dns" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "enable_vpc_cni" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "enable_kube_proxy" {
  description = "Enable Kube Proxy addon"
  type        = bool
  default     = true
}

variable "coredns_version" {
  description = "Version of CoreDNS addon"
  type        = string
  default     = ""
}

variable "vpc_cni_version" {
  description = "Version of VPC CNI addon"
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of Kube Proxy addon"
  type        = string
  default     = ""
}

variable "cluster_encryption_config" {
  description = "Encryption configuration for the cluster"
  type = object({
    provider_arn = string
    resources    = list(string)
  })
  default = null
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Synthetic ordering input. Pass module.iam.cluster_role_policies_ready here so
# Terraform creates the IAM policy attachments BEFORE the cluster — avoids the
# "role not authorized" race without taking a wide module-level depends_on
# (which would form a cycle with the OIDC URL flowing back into iam).
variable "iam_role_policies_ready" {
  description = "List of IAM policy attachment IDs the cluster should wait on (use module.iam.cluster_role_policies_ready)"
  type        = list(string)
  default     = []
}
