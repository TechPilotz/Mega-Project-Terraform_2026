output "cluster_id" {
  description = "The ID of the Techpilotz EKS Cluster"
  value       = aws_eks_cluster.techpilotz.id
}

output "node_group_id" {
  description = "The ID of the Techpilotz EKS Node Group"
  value       = aws_eks_node_group.techpilotz.id
}

output "vpc_id" {
  description = "The ID of the Techpilotz VPC"
  value       = aws_vpc.techpilotz_vpc.id
}

output "subnet_ids" {
  description = "The IDs of the Techpilotz subnets"
  value       = aws_subnet.techpilotz_subnet[*].id
}

output "cluster_endpoint" {
  description = "The endpoint for your Techpilotz EKS Kubernetes API"
  value       = aws_eks_cluster.techpilotz.endpoint
}
