locals {
  name = var.name

  tags = merge(var.tags, {
    Module = "vpc"
  })
}

# VPC
resource "aws_vpc" "main" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.create && !var.use_existing_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.tags, {
    Name = "${local.name}-igw"
  })
}

# Public Subnets
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

# Private Subnets
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

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.create && !var.use_existing_vpc && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name}-nat-eip-${count.index}"
  })
}

# NAT Gateway
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

# Public Route Table
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

# Private Route Tables — one per AZ when NAT-per-AZ, else a single shared one.
resource "aws_route_table" "private" {
  count = var.create && !var.use_existing_vpc ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  vpc_id = aws_vpc.main[0].id

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

# Node Security Group
# Cluster→node rules (1025-65535 + 443 from the cluster primary SG) are added in
# the cluster module once the cluster's auto-created SG exists.
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

# Route Table Associations
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
