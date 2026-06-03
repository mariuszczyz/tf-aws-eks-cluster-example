# =============================================================================
# Module: vpc
# =============================================================================
# Builds the networking substrate for an EKS cluster:
#
#   - 1 VPC with DNS support/hostnames (required by EKS).
#   - Public + private /24 subnets in each AZ (3 of each by default).
#   - 1 Internet Gateway.
#   - NAT gateway(s): one per AZ for HA, or a single shared one to save cost.
#   - Public route table (0.0.0.0/0 → IGW), one or more private route tables
#     (0.0.0.0/0 → NAT).
#   - A worker-node security group with self-ingress; cluster→node rules are
#     added by the cluster module once the cluster SG exists.
#
# Subnets are tagged with `kubernetes.io/role/elb=1` (public) and
# `kubernetes.io/role/internal-elb=1` (private) so the AWS Load Balancer
# Controller can auto-discover where to place ALBs/NLBs.
#
# When `use_existing_vpc = true` everything in this file is skipped and the
# outputs pass through the caller-supplied IDs.
# =============================================================================

locals {
  name = var.name

  # Stamp every resource with a Module tag for traceability across submodules.
  tags = merge(var.tags, {
    Module = "vpc"
  })
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
# DNS support and DNS hostnames are mandatory for EKS — kubelet uses internal
# DNS to resolve the cluster API endpoint and addons rely on Pod DNS.
resource "aws_vpc" "main" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.name}-vpc"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway — public subnet egress + LB ingress.
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.tags, {
    Name = "${local.name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets — one per AZ. Hosts NAT gateways and public-facing LBs.
# -----------------------------------------------------------------------------
# `map_public_ip_on_launch = true` is required for NAT gateways and bastion-style
# workloads. The `kubernetes.io/role/elb` tag marks these subnets as valid
# placement targets for the AWS Load Balancer Controller's public LBs.
resource "aws_subnet" "public" {
  count = var.create && !var.use_existing_vpc ? length(var.azs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${local.name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = 1
  })
}

# -----------------------------------------------------------------------------
# Private Subnets — one per AZ. Hosts worker nodes and internal LBs.
# -----------------------------------------------------------------------------
# Tagged with `kubernetes.io/role/internal-elb` for internal LB auto-discovery.
resource "aws_subnet" "private" {
  count = var.create && !var.use_existing_vpc ? length(var.azs) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.tags, {
    Name                              = "${local.name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = 1
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs — one per NAT gateway. Allocated from the VPC pool.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.create && !var.use_existing_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name}-nat-eip-${count.index}"
  })
}

# -----------------------------------------------------------------------------
# NAT Gateway — egress for private subnets.
# -----------------------------------------------------------------------------
# Mode controlled by `single_nat_gateway`:
#   true  → one NAT (cheaper, no HA; if its AZ fails, all private egress dies).
#   false → one NAT per AZ (recommended for prod; each AZ stays independent).
#
# `depends_on` includes the public RT association so the public subnet is
# actually internet-connected by the time the NAT is created.
resource "aws_nat_gateway" "main" {
  count = var.create && !var.use_existing_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${local.name}-nat-${count.index}"
  })

  # NAT needs the public RT to actually reach the IGW.
  depends_on = [aws_internet_gateway.main, aws_route_table_association.public]
}

# -----------------------------------------------------------------------------
# Public Route Table — default route to the IGW.
# -----------------------------------------------------------------------------
# One RT is shared by all public subnets — public routing has no per-AZ state.
resource "aws_route_table" "public" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.tags, {
    Name = "${local.name}-public-rt"
  })
}

# -----------------------------------------------------------------------------
# Private Route Tables — default route to NAT.
# -----------------------------------------------------------------------------
# One RT per AZ when NAT-per-AZ (so each AZ uses its OWN NAT and a NAT failure
# only takes down one AZ). One shared RT when single_nat_gateway=true.
resource "aws_route_table" "private" {
  count = var.create && !var.use_existing_vpc ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  vpc_id = aws_vpc.main[0].id

  # Default route only emitted when NAT is enabled — private subnets without
  # NAT still need a route table, just no 0.0.0.0/0 route.
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name}-private-rt-${count.index}"
  })
}

# -----------------------------------------------------------------------------
# Node Security Group
# -----------------------------------------------------------------------------
# Self-ingress only — allows all node-to-node traffic (kubelet, kube-proxy,
# pod-to-pod, CNI overlays). The cluster→node rules required for kubelet
# (1025-65535 TCP) and webhooks (443) are added in the cluster module via
# `aws_vpc_security_group_ingress_rule` once the cluster's primary SG exists.
#
# Egress is wide-open — pods routinely fetch from arbitrary internet endpoints
# (container registries, package mirrors, APIs). Lock this down separately if
# your environment requires it.
resource "aws_security_group" "node" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  name        = "${local.name}-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main[0].id

  # Node-to-node (kubelet, kube-proxy, pod networking)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-node-sg"
  })
}

# -----------------------------------------------------------------------------
# Route Table Associations
# -----------------------------------------------------------------------------
# Public: every public subnet → the single public RT.
# Private: each private subnet → its AZ's RT (or the shared one in single-NAT mode).
resource "aws_route_table_association" "public" {
  count = var.create && !var.use_existing_vpc ? length(var.azs) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = var.create && !var.use_existing_vpc ? length(var.azs) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
