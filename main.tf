terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region ="us-west-2"
}

variable "cluster_name" {
  default = "gr5-capstone2-eks-cluster"
}

variable "cluster_version" {
  default = "1.28"
}

resource "aws_vpc" "gr5_capstone2_vpc_stack" {
  cidr_block = "192.168.0.0/16"


  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "gr5-capstone2-vpc-stack"
  }
}

resource "aws_internet_gateway" "gr5_capstone2_igw" {
  vpc_id = aws_vpc.gr5_capstone2_vpc_stack.id

  tags = {
    Name = "gr5-capstone2-igw"
  }
}

resource "aws_subnet" "gr5_capstone2_private_us_west_2a" {
  vpc_id            = aws_vpc.gr5_capstone2_vpc_stack.id
  cidr_block        = "192.168.128.0/18"
  availability_zone = "us-west-2a"

  tags = {
    "Name"                                      = "gr5-capstone2-private-us-west-2a"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "gr5_capstone2_private_us_west_2b" {
  vpc_id            = aws_vpc.gr5_capstone2_vpc_stack.id
  cidr_block        = "192.168.192.0/18"
  availability_zone = "us-west-2b"

  tags = {
    "Name"                                      = "gr5-capstone2-private-us-west-2b"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "gr5_capstone2_public_us_west_2a" {
  vpc_id            = aws_vpc.gr5_capstone2_vpc_stack.id
  cidr_block        = "192.168.0.0/18"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "gr5-capstone2-private-us-west-2a"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "gr5_capstone2_public_us_west_2b" {
  vpc_id            = aws_vpc.gr5_capstone2_vpc_stack.id
  cidr_block        = "192.168.64.0/18"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "gr5-capstone2-private-us-west-2b"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_eip" "gr5_capstone2_nat" {
  vpc = true

  tags = {
    Name = "gr5-capstone2-nat"
  }
}

resource "aws_nat_gateway" "gr5_capstone2_nat" {
  allocation_id = aws_eip.gr5_capstone2_nat.id
  subnet_id     = aws_subnet.gr5_capstone2_public_us_west_2a.id

  tags = {
    Name = "gr5-capstone2-nat"
  }

  depends_on = [aws_internet_gateway.gr5_capstone2_igw]
}

resource "aws_route_table" "gr5_capstone2_private" {
  vpc_id = aws_vpc.gr5_capstone2_vpc_stack.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gr5_capstone2_nat.id
  }

  tags = {
    Name = "gr5-capstone2-private"
  }
}

resource "aws_route_table" "gr5_capstone2_public" {
  vpc_id = aws_vpc.gr5_capstone2_vpc_stack.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gr5_capstone2_igw.id
  }

  tags = {
    Name = "gr5-capstone2-public"
  }
}

resource "aws_route_table_association" "gr5_capstone2_private_us_west_2a" {
  subnet_id      = aws_subnet.gr5_capstone2_private_us_west_2a.id
  route_table_id = aws_route_table.gr5_capstone2_private.id
}

resource "aws_route_table_association" "gr5_capstone2_private-us-west-2b" {
  subnet_id      = aws_subnet.gr5_capstone2_private_us_west_2b.id
  route_table_id = aws_route_table.gr5_capstone2_private.id
}

resource "aws_route_table_association" "gr5_capstone2_public-us-west-2a" {
  subnet_id      = aws_subnet.gr5_capstone2_public_us_west_2a.id
  route_table_id = aws_route_table.gr5_capstone2_public.id
}

resource "aws_route_table_association" "gr5_capstone2_public-us-west-2b" {
  subnet_id      = aws_subnet.gr5_capstone2_public_us_west_2b.id
  route_table_id = aws_route_table.gr5_capstone2_public.id
}

resource "aws_iam_role" "gr5_capstone2_eks_cluster_role" {
  name = "gr5-capstone2-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.gr5_assume_role.json
}

data "aws_iam_policy_document" "gr5_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role_policy_attachment" "gr5_capstone2_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.gr5_capstone2_eks_cluster_role.name}"
}

resource "aws_eks_cluster" "gr5_capstone2_eks_cluster" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.gr5_capstone2_eks_cluster_role.arn

  vpc_config {

    endpoint_private_access = false
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]

    subnet_ids = [
      aws_subnet.gr5_capstone2_private_us_west_2a.id,
      aws_subnet.gr5_capstone2_private_us_west_2b.id,
      aws_subnet.gr5_capstone2_public_us_west_2a.id,
      aws_subnet.gr5_capstone2_public_us_west_2b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.gr5_capstone2_cluster_policy]

}

resource "aws_eks_addon" "gr5_capstone2_vpc_cni" {
  cluster_name = var.cluster_name
  addon_name = "vpc-cni"
  depends_on = [aws_eks_cluster.gr5_capstone2_eks_cluster]
}

resource "aws_eks_addon" "gr5_capstone2_kube_proxy" {
  cluster_name = var.cluster_name
  addon_name = "kube-proxy"
  depends_on = [aws_eks_cluster.gr5_capstone2_eks_cluster]
}


resource "aws_iam_role" "gr5_capstone2_eks_fargate_profile" {
  name = "gr5-capstone2-eks-fargate-profile"
  assume_role_policy = data.aws_iam_policy_document.gr5_assume_role_fargate.json
}

data "aws_iam_policy_document" "gr5_assume_role_fargate" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "gr5_capstone2_eks-fargate-profile_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = "${aws_iam_role.gr5_capstone2_eks_fargate_profile.name}"
}

resource "aws_eks_fargate_profile" "gr5_capstone2_kube_system" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "gr5-capstone2-kube-system"
  pod_execution_role_arn = aws_iam_role.gr5_capstone2_eks_fargate_profile.arn

  # These subnets must have the following resource tag: 
  # kubernetes.io/cluster/<CLUSTER_NAME>.
  subnet_ids = [
    aws_subnet.gr5_capstone2_private_us_west_2a.id,
    aws_subnet.gr5_capstone2_private_us_west_2b.id
  ]

  selector {
    namespace = "kube-system"
  }
  depends_on = [aws_eks_cluster.gr5_capstone2_eks_cluster]
}

resource "aws_eks_addon" "gr5_capstone2_coredns" {
  cluster_name = var.cluster_name
  addon_name = "coredns"
  addon_version = "v1.10.1-eksbuild.7"
  resolve_conflicts = "OVERWRITE"
  depends_on = [aws_eks_cluster.gr5_capstone2_eks_cluster,aws_eks_fargate_profile.gr5_capstone2_kube_system]
}
