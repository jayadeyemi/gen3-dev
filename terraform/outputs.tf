output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.gen3-eks.eks_cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.gen3-eks.eks_cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "eks_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.gen3-eks.eks_cluster_name
}
output "ack_role_arns" {
  description = "IAM role ARNs for each ACK controller, keyed by service"
  value       = {
    for service, role in module.gen3-ack-iam:
    service => role.iam_role_arn
  }
}

output "ack_kro_controller_role_arn" {
  description = "IAM role ARN for the ACK KRO controller"
  value       = module.gen3-ack-kro-iam.iam_role_arn
 
} 