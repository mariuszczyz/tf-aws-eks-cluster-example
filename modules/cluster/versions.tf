# Provider constraints for the cluster module — only needs the AWS provider
# (aws_eks_cluster + aws_vpc_security_group_ingress_rule).
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
