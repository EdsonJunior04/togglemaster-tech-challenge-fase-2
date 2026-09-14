resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-db-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite acesso ao RDS apenas a partir do cluster EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres a partir dos nodes do EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# Uma instância RDS PostgreSQL por serviço (auth, flag, targeting -> 3 instâncias)
resource "aws_db_instance" "this" {
  for_each = toset(var.services_with_own_db)

  identifier     = "${var.project_name}-${each.key}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version

  instance_class        = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = replace("${each.key}_db", "-", "_")
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  tags = {
    Name    = "${var.project_name}-${each.key}-db"
    Service = each.key
  }
}
