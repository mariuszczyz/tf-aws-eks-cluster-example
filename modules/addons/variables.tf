variable "create" {
  description = "Controls if addon resources should be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name prefix for addons"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "enable_vpc_cni" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "vpc_cni_version" {
  description = "Version of VPC CNI addon"
  type        = string
  default     = ""
}

variable "vpc_cni_configuration" {
  description = "VPC CNI addon configuration"
  type        = map(string)
  default     = {}
}

variable "enable_core_dns" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "coredns_version" {
  description = "Version of CoreDNS addon"
  type        = string
  default     = ""
}

variable "coredns_configuration" {
  description = "CoreDNS addon configuration"
  type        = map(string)
  default     = {}
}

variable "enable_kube_proxy" {
  description = "Enable kube-proxy addon"
  type        = bool
  default     = true
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy addon"
  type        = string
  default     = ""
}

variable "enable_pod_identity" {
  description = "Enable EKS Pod Identity Agent addon"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Enable AWS EBS CSI Driver addon"
  type        = bool
  default     = false
}

variable "enable_efs_csi_driver" {
  description = "Enable AWS EFS CSI Driver addon"
  type        = bool
  default     = false
}

variable "enable_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller addon"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
