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
