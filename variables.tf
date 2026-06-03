# =============================================================================
# Root module variables
# =============================================================================
# Variables are grouped into four buckets:
#
#   1. Identity / region        — name, aws_region, cluster_name
#   2. Networking               — vpc_cidr, azs, use_private_subnets
#   3. Compute                  — instance_types, min/max/desired_size, labels, taints
#   4. Feature toggles          — create_* (per-layer kill switches) and enable_*
#                                 (per-addon switches)
#
# Every `create_*` and `enable_*` boolean has a safe default so a bare
# `terraform apply` produces a working cluster.
# =============================================================================

variable "create" {
  description = "Master kill switch. Currently informational — child modules are toggled with create_vpc / create_iam / create_cluster / create_node_groups / create_addons."
  type        = bool
  default     = true
}

variable "name" {
  description = "Name prefix for resources"
  type        = string
  default     = "eks-cluster"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "eks_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "instance_types" {
  description = "List of instance types for node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "use_private_subnets" {
  description = "Use private subnets for nodes"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Kubernetes labels for node group"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints for node group"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "create_vpc" {
  description = "Create VPC"
  type        = bool
  default     = true
}

variable "create_iam" {
  description = "Create IAM resources"
  type        = bool
  default     = true
}

variable "create_cluster" {
  description = "Create cluster"
  type        = bool
  default     = true
}

variable "create_node_groups" {
  description = "Create node groups"
  type        = bool
  default     = true
}

variable "create_addons" {
  description = "Create addons"
  type        = bool
  default     = true
}

variable "enable_vpc_cni" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "enable_core_dns" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "enable_kube_proxy" {
  description = "Enable kube-proxy addon"
  type        = bool
  default     = true
}

variable "enable_pod_identity" {
  description = "Enable EKS Pod Identity Agent addon"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver addon"
  type        = bool
  default     = false
}

variable "enable_efs_csi_driver" {
  description = "Enable EFS CSI driver addon"
  type        = bool
  default     = false
}

variable "enable_load_balancer_controller" {
  description = "Enable Load Balancer Controller addon"
  type        = bool
  default     = false
}
