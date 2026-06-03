variable "create" {
  description = "Controls if node group resources should be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name prefix for node groups"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_iam_role_arn" {
  description = "ARN of the EKS node IAM role"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for node groups"
  type        = list(string)
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

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
  default     = "eks-node-group"
}

variable "ami_type" {
  description = "AMI type for node group"
  type        = string
  default     = "AL2_x86_64"
}

variable "release_version" {
  description = "AMI version"
  type        = string
  default     = ""
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
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

variable "update_config" {
  description = "Update configuration for node group"
  type = object({
    max_unavailable_percentage = optional(number, 33)
    max_unavailable            = optional(number, null)
  })
  default = {}
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
