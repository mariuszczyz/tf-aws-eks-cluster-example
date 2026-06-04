# EKS Cluster Terraform Modules

Reusable Terraform modules for deploying AWS EKS clusters, modeled after [AWS EKS Best Practices](https://github.com/aws/aws-eks-best-practices) and the patterns in [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks).

Composes five focused submodules into a working cluster while keeping each layer independently usable.

## Modules

| Module | Owns |
|--------|------|
| [vpc](modules/vpc/) | VPC, multi-AZ public + private subnets, IGW, NAT gateway(s), route tables, worker-node security group |
| [iam](modules/iam/) | EKS cluster service role, EKS node role (kubelet/CNI/ECR policies), OIDC provider, IRSA roles |
| [cluster](modules/cluster/) | EKS control plane + cluster→node SG ingress rules (1025-65535 / 443) |
| [node-groups](modules/node-groups/) | EKS-managed node group with scaling, labels, taints, update controls |
| [addons](modules/addons/) | EKS-managed addons: VPC CNI, CoreDNS, kube-proxy, Pod Identity Agent, EBS/EFS CSI drivers |

The **cluster** module does NOT create addons — that is intentionally the sole responsibility of the **addons** module so you never get a duplicate `aws_eks_addon` conflict.

## Architecture

```
VPC (10.0.0.0/16 by default)
├── Public Subnets  (one per AZ, tagged kubernetes.io/role/elb=1)
│   └── Internet Gateway
│       └── NAT Gateway(s)        ← one per AZ for HA, or one shared (cheaper)
└── Private Subnets (one per AZ, tagged kubernetes.io/role/internal-elb=1)
    └── Private Route Table(s)    ← per-AZ when NAT-per-AZ, else shared
        └── Worker Nodes (managed node group)

EKS Cluster
├── Control Plane                 ← AWS-managed, multi-AZ ENIs
├── Cluster SG ──(443 + 1025-65535 tcp)──▶ Node SG
└── Managed Addons (vpc-cni, coredns, kube-proxy, pod-identity, csi drivers)

IAM
├── Cluster service role (AmazonEKSClusterPolicy)
├── Node instance role  (Worker + CNI + ECR-ReadOnly)
└── OIDC provider → optional per-workload IRSA roles
```

### Ordering

The classic EKS races are avoided by passing **synthetic "ready" lists** from the `iam` module into `cluster` and `node-groups`:

- `module.cluster` consumes `module.iam.cluster_role_policies_ready` so the EKS create call only fires once the cluster role's policy is attached.
- `module.node_groups` consumes `module.iam.node_role_policies_ready` so kubelet on new nodes can authenticate immediately.

This is wired automatically by the root module — you only need it if you compose the submodules yourself.

## Usage

### One-shot via the root module

```hcl
module "eks" {
  source = "github.com/your-org/eks-cluster-tf-modules"

  aws_region   = "us-east-1"
  cluster_name = "my-eks-cluster"
  vpc_cidr     = "10.0.0.0/16"
  eks_version  = "1.30"

  instance_types = ["t3.medium"]
  min_size       = 1
  max_size       = 10
  desired_size   = 2

  use_private_subnets   = true
  enable_ebs_csi_driver = true

  tags = {
    Environment = "production"
  }
}
```

A bare apply with only `cluster_name` set produces a working cluster — every other variable has a safe default.

### Submodules standalone

Each module can be used on its own. When composing manually, wire the ordering inputs yourself:

```hcl
module "vpc" {
  source = "./modules/vpc"
  name   = "my-cluster"
  cidr   = "10.0.0.0/16"
}

module "iam" {
  source            = "./modules/iam"
  name              = "my-cluster"
  cluster_name      = "my-cluster"
  region            = "us-east-1"
  oidc_provider_url = try(module.cluster.cluster_oidc_issuer_url, "")
}

module "cluster" {
  source                  = "./modules/cluster"
  name                    = "my-cluster"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  cluster_iam_role_arn    = module.iam.cluster_iam_role_arn
  node_security_group_id  = module.vpc.node_security_group_id
  iam_role_policies_ready = module.iam.cluster_role_policies_ready
}

module "node_groups" {
  source                  = "./modules/node-groups"
  name                    = "my-cluster"
  cluster_name            = module.cluster.cluster_name
  node_iam_role_arn       = module.iam.node_iam_role_arn
  subnet_ids              = module.vpc.private_subnet_ids
  iam_role_policies_ready = module.iam.node_role_policies_ready
}

module "addons" {
  source             = "./modules/addons"
  cluster_name       = module.cluster.cluster_name
  enable_vpc_cni     = true
  enable_core_dns    = true
  enable_kube_proxy  = true
}
```

### Reusing an existing VPC

Set `create_vpc = false` (or call the `vpc` submodule with `use_existing_vpc = true`) and supply the existing subnet IDs:

```hcl
module "vpc" {
  source                      = "./modules/vpc"
  use_existing_vpc            = true
  existing_vpc_id             = "vpc-0123abcd"
  existing_vpc_cidr           = "10.20.0.0/16"
  existing_public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
  existing_private_subnet_ids = ["subnet-ccc", "subnet-ddd"]
}
```

Outputs (`vpc_id`, `public_subnet_ids`, `private_subnet_ids`) pass through transparently.

### Examples

- [examples/basic](examples/basic/) — minimal cluster, default VPC, single node group
- [examples/production](examples/production/) — KMS-encrypted secrets, multiple node groups, full addon suite
- [examples/production-existing-vpc](examples/production-existing-vpc/) — production cluster deployed into a pre-existing VPC (subnets discovered by tag)
- [examples/multi-cluster](examples/multi-cluster/) — multiple clusters in different regions

## Inputs (root)

The root module exposes the most common knobs. The submodules expose more (consult each `variables.tf` for the full list).

| Bucket | Variables |
|--------|-----------|
| Identity / region | `aws_region`, `name`, `cluster_name` |
| Kubernetes | `eks_version` (default `1.30`) |
| Networking | `vpc_cidr`, `azs`, `use_private_subnets`, `create_vpc` |
| Compute | `instance_types`, `min_size`, `max_size`, `desired_size`, `labels`, `taints` |
| Layer toggles | `create_iam`, `create_cluster`, `create_node_groups`, `create_addons` |
| Addon toggles | `enable_vpc_cni`, `enable_core_dns`, `enable_kube_proxy`, `enable_pod_identity`, `enable_ebs_csi_driver`, `enable_efs_csi_driver`, `enable_load_balancer_controller` |
| Tagging | `tags` |

> **Note:** `enable_load_balancer_controller` exists for API symmetry but is currently a **no-op** — the AWS Load Balancer Controller is not a managed EKS addon. Install it via Helm + IRSA after the cluster comes up.

## Outputs (root)

All wrapped in `try(...)` so consumers can plan against the module when individual layers are disabled.

| Output | Source |
|--------|--------|
| `cluster_endpoint`, `cluster_name`, `cluster_arn`, `cluster_version` | EKS cluster |
| `cluster_oidc_issuer_url`, `cluster_certificate_authority` | EKS cluster |
| `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids` | VPC module |
| `node_group_arn`, `node_group_name` | Node groups |
| `addon_names` | Addons |
| `oidc_provider_url` | IAM |

## Key features

- **Modular** — each layer is independently usable; cross-module ordering is explicit, not magic.
- **Safe defaults** — `terraform apply` with no overrides produces a working cluster.
- **Multi-AZ ready** — subnets, NAT, and route tables fan out across `azs`; HA-per-AZ NAT available with `single_nat_gateway = false`.
- **IRSA + Pod Identity** — both supported; OIDC provider is auto-registered from the cluster's issuer URL.
- **KMS envelope encryption** — pass `cluster_encryption_config` to encrypt Kubernetes Secrets at rest.
- **`create=false` everywhere** — every module can be turned off cleanly without dangling `[0]` index errors in outputs.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| hashicorp/aws | ~> 6.0 |
| hashicorp/tls | ~> 4.0 (used by the iam module for the OIDC issuer thumbprint) |

## Validating locally

```sh
terraform init -backend=false
terraform validate

cd examples/basic
terraform init -backend=false
terraform validate
```

Both root and `examples/basic` pass `terraform validate` cleanly.
