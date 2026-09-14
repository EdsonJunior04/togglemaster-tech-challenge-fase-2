# --- Resolução da role a ser usada -----------------------------------------
# AWS Academy: NÃO é permitido `aws_iam_role`/`aws_iam_policy` no Terraform.
# Em vez disso, importamos a LabRole existente via data source e associamos
# ela tanto ao control plane do EKS quanto ao Node Group.
# Conta pessoal: se use_academy_lab_role = false, criamos as roles normalmente.

data "aws_iam_role" "lab_role" {
  count = var.use_academy_lab_role ? 1 : 0
  name  = var.lab_role_name
}

# ---- Roles próprias (somente conta pessoal, use_academy_lab_role = false) --
resource "aws_iam_role" "cluster" {
  count = var.use_academy_lab_role ? 0 : 1
  name  = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  count      = var.use_academy_lab_role ? 0 : 1
  role       = aws_iam_role.cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  count = var.use_academy_lab_role ? 0 : 1
  name  = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  count      = var.use_academy_lab_role ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  count      = var.use_academy_lab_role ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  count      = var.use_academy_lab_role ? 0 : 1
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

locals {
  cluster_role_arn = var.use_academy_lab_role ? data.aws_iam_role.lab_role[0].arn : aws_iam_role.cluster[0].arn
  node_role_arn    = var.use_academy_lab_role ? data.aws_iam_role.lab_role[0].arn : aws_iam_role.node[0].arn
}

# --- EKS Cluster -------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "SG do control plane EKS"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-sg" }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = local.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access   = true
    endpoint_private_access  = true
  }

  tags = { Name = var.cluster_name }
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-default"
  node_role_arn   = local.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # Quando usa LabRole no Academy, NÃO criamos policy attachments (a role já
  # tem permissões amplas o suficiente por padrão do curso).
  depends_on = [aws_eks_cluster.this]
}
