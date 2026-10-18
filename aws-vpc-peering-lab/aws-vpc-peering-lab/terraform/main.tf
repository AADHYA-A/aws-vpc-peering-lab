############################
# Locals
############################
locals {
  vpc_a_cidr     = "10.10.0.0/16"
  public_a_cidr  = "10.10.1.0/24"
  private_a_cidr = "10.10.2.0/24"
  vpc_b_cidr     = "10.20.0.0/16"
  private_b_cidr = "10.20.1.0/24"

  bastion_ip = "10.10.1.10"
  app_a_ip   = "10.10.2.10"
  app_b_ip   = "10.20.1.10"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 (x86_64)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

############################
# VPC A
############################
resource "aws_vpc" "a" {
  cidr_block = local.vpc_a_cidr
  tags       = { Name = "ewb-vpc-a" }
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.public_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false # public IP is set per-instance on the bastion only
  tags                    = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = local.private_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-private" }
}

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-igw-a" }
}

resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-public" }
}

resource "aws_route" "a_public_internet" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-private" }
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

############################
# VPC B (no internet gateway)
############################
resource "aws_vpc" "b" {
  cidr_block = local.vpc_b_cidr
  tags       = { Name = "ewb-vpc-b" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = local.private_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-b-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id
  tags   = { Name = "ewb-rt-b-private" }
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

############################
# Peering (same account + Region)
############################
resource "aws_vpc_peering_connection" "a_b" {
  count = var.enable_peering ? 1 : 0

  vpc_id      = aws_vpc.a.id # requester
  peer_vpc_id = aws_vpc.b.id # accepter
  auto_accept = true         # same account/Region: accept automatically

  tags = { Name = "ewb-a-b-peer" }
}

# App-A -> VPC B
resource "aws_route" "a_private_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# Return path: VPC B -> VPC A
resource "aws_route" "b_private_to_a" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = local.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

# Bastion (public subnet) -> VPC B, needed for ProxyJump to App-B
resource "aws_route" "a_public_to_b" {
  count = var.enable_peering ? 1 : 0

  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = local.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b[0].id
}

############################
# Security groups
############################
resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "Bastion SSH from my IP only"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "App-A: SSH from bastion, ICMP from App-B"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "App-B: SSH from bastion, ICMP from App-A"
  vpc_id      = aws_vpc.b.id
  tags        = { Name = "ewb-sg-app-b" }
}

# Bastion: SSH from your /32
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from my public IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip_cidr
}

# App-A: SSH from bastion private IP
resource "aws_vpc_security_group_ingress_rule" "app_a_ssh" {
  security_group_id = aws_security_group.app_a.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

# App-A: ICMP echo request from App-B
resource "aws_vpc_security_group_ingress_rule" "app_a_icmp" {
  security_group_id = aws_security_group.app_a.id
  description       = "ICMP echo request from App-B"
  ip_protocol       = "icmp"
  from_port         = 8 # ICMP type
  to_port           = 0 # ICMP code
  cidr_ipv4         = "${local.app_b_ip}/32"
}

# App-B: SSH from bastion private IP (ProxyJump source)
resource "aws_vpc_security_group_ingress_rule" "app_b_ssh" {
  security_group_id = aws_security_group.app_b.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${local.bastion_ip}/32"
}

# App-B: ICMP echo request from App-A (toggle for controlled failure test)
resource "aws_vpc_security_group_ingress_rule" "app_b_icmp" {
  count = var.enable_app_b_icmp_rule ? 1 : 0

  security_group_id = aws_security_group.app_b.id
  description       = "ICMP echo request from App-A"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = "${local.app_a_ip}/32"
}

############################
# EC2 instances
############################
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = local.bastion_ip
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-bastion" }

  depends_on = [aws_route.a_public_internet]
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = local.app_a_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_a.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-a" }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = local.app_b_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_b.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-b" }
}
