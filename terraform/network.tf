# network.tf - the private network (VPC) our app runs inside.
#
# Layout (across 2 Availability Zones for redundancy):
#   - Public subnets:  hold the load balancer + NAT gateway.
#   - Private subnets: hold the ECS tasks (not directly reachable).
#
# Traffic in:  Internet -> IGW -> ALB (public) -> tasks (private)
# Traffic out: tasks (private) -> NAT (public) -> IGW -> Internet
#              (so tasks can pull images / reach AWS APIs, but nobody
#               on the internet can open a connection to them)

# Look up which AZs are available in the chosen region.
data "aws_availability_zones" "available" {
  state = "available"
}

# The VPC: our isolated slice of the AWS network.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.app_name}-vpc" }
}

# Internet Gateway: the VPC's door to the public internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.app_name}-igw" }
}

# Two public subnets, one per AZ. /24 each, carved from the VPC CIDR.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.app_name}-public-${count.index}" }
}

# Two private subnets, one per AZ. Offset by 10 to avoid overlap.
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${var.app_name}-private-${count.index}" }
}

# An Elastic IP for the NAT gateway (NAT needs a fixed public IP).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.app_name}-nat-eip" }
}

# NAT Gateway: lets private tasks make OUTBOUND internet calls
# (e.g. to pull the image) without being reachable from outside.
# Placed in the first public subnet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.app_name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# Public route table: send internet-bound traffic to the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.app_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: send internet-bound traffic to the NAT gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.app_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
