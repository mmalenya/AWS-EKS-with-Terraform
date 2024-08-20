data "aws_availability_zones" "available" {}


### VPC 

resource "aws_vpc" "main" {

  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    var.default_tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id
}


# ####custom security groups########################

# resource "aws_security_group" "eks_cluster_sg" {
#   name        = "${var.cluster_name}-eks-cluster-sg"
#   description = "Security group for EKS cluster control plane communication with worker nodes"
#   vpc_id      = module.vpc.vpc_id
#   tags = {
#     Name = "${var.cluster_name}-eks-cluster-sg"
#   }
# }

# resource "aws_security_group_rule" "eks_cluster_ingress_nodes" {
#   type                     = "ingress"
#   from_port                = 443
#   to_port                  = 443
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_cluster_sg.id
#   source_security_group_id = aws_security_group.eks_nodes_sg.id
#   description              = "Allow inbound traffic from the worker nodes on the Kubernetes API endpoint port"
# }

# resource "aws_security_group_rule" "eks_cluster_egress_kublet" {
#   type                     = "egress"
#   from_port                = 10250
#   to_port                  = 10250
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_cluster_sg.id
#   source_security_group_id = aws_security_group.eks_nodes_sg.id
#   description              = "Allow control plane to node egress for kubelet"
# }

# resource "aws_security_group" "eks_nodes_sg" {
#   name        = "${var.cluster_name}-eks-nodes-sg"
#   description = "Security group for all nodes in the cluster"
#   vpc_id      = module.vpc.vpc_id
#   tags = {
#     Name                                        = "${var.cluster_name}-eks-nodes-sg"
#     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#   }
# }

# resource "aws_security_group_rule" "worker_node_ingress_kublet" {
#   type                     = "ingress"
#   from_port                = 10250
#   to_port                  = 10250
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_nodes_sg.id
#   source_security_group_id = aws_security_group.eks_cluster_sg.id
#   description              = "Allow control plane to node ingress for kubelet"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_ephemeral" {
#   type              = "ingress"
#   from_port         = 1025
#   to_port           = 65535
#   protocol          = "tcp"
#   self              = true
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   description       = "Allow workers nodes to communicate with each other on ephemeral ports"
# }
# resource "aws_security_group_rule" "worker_node_egress_internet" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   description       = "Allow outbound internet access"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_coredns_tcp" {
#   type              = "ingress"
#   from_port         = 53
#   to_port           = 53
#   protocol          = "tcp"
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   self              = true
#   description       = "Allow workers nodes to communicate with each other for coredns TCP"
# }

# resource "aws_security_group_rule" "worker_node_to_worker_node_ingress_coredns_udp" {
#   type              = "ingress"
#   from_port         = 53
#   to_port           = 53
#   protocol          = "udp"
#   security_group_id = aws_security_group.eks_nodes_sg.id
#   self              = true
#   description       = "Allow workers nodes to communicate with each other for coredns UDP"
# }

############################################################################################################
### SUBNETS 
############################################################################################################
## Public subnets
resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, var.public_subnet_additional_bits, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.default_tags, var.public_subnet_tags, {
      Name = "${var.vpc_name}-public-subnet-${count.index + 1}"
  })
}

## Private Subnets
resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, var.private_subnet_additional_bits, count.index + var.public_subnet_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.default_tags, var.private_subnet_tags, {
      Name = "${var.vpc_name}-private-subnet-${count.index + 1}"
  })
}



### INTERNET GATEWAY

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.default_tags, {
      Name = "${var.vpc_name}-internetgateway"
  })
}


############################################################################################################
### NAT GATEWAY 
############################################################################################################
resource "aws_eip" "nat_gateway" {
  count = var.nat_gateway ? 1 : 0

  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count = var.nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_gateway[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.default_tags, {
      Name = "${var.vpc_name}-natgateway-default"
  })

  depends_on = [
    aws_internet_gateway.main
  ]
}


############################################################################################################
### ROUTE TABLES 
############################################################################################################
# Public Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.default_tags, {
      Name = "${var.vpc_name}-routetable-public"
  })
}

## Public Route Table rules
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
  destination_cidr_block = "0.0.0.0/0"
}

## Public Route table associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.default_tags, {
      Name = "${var.vpc_name}-routetable-private"
  })
}

## Private Route Table rules
resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = var.nat_gateway ? aws_nat_gateway.main[0].id : null
  destination_cidr_block = "0.0.0.0/0"
}

## Private Route table associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}