# Provider + Terraform version constraints for the root module.
#   - terraform >= 1.5.0: needed for `optional()` attributes on object types.
#   - hashicorp/aws ~> 6.0: pinned to a major to avoid breaking schema changes;
#     the EKS, IAM, VPC, and IRSA resources used here are stable in 6.x.
#   - hashicorp/tls ~> 4.0: needed by modules/iam for the `tls_certificate` data
#     source that fetches the OIDC issuer's thumbprint.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
