# Provider constraints for the iam module:
#   - aws: IAM roles, policies, OIDC provider.
#   - tls: needed by the `tls_certificate` data source that fetches the OIDC
#          issuer's TLS thumbprint for the OIDC provider registration.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
