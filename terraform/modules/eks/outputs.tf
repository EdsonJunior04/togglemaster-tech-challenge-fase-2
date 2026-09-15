output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  # O SG passado em vpc_config.security_group_ids so vale pro control plane.
  # Os worker nodes (e portanto os Pods) usam o SG "cluster_security_group"
  # que a propria AWS cria automaticamente - e esse que RDS/Redis precisam liberar.
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
