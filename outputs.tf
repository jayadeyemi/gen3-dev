# Outputs
output "eks_cluster_endpoint" {
    description = "Endpoint for EKS control plane"
    value       = module.gen3-commons.eks_cluster_endpoint
}

output "eks_cluster_security_group_id" {
    description = "Security group ids attached to the cluster control plane"
    value       = module.gen3-commons.eks_cluster_security_group_id
}

output "region" {
    description = "AWS region"
    value       = var.region
}

output "eks_cluster_name" {
    description = "Kubernetes Cluster Name"
    value       = module.gen3-commons.eks_cluster_name
}

output "ack_controller_role_arns" {
  description = "IAM role ARNs for each ACK controller, keyed by service"
  value = module.gen3-commons.ack_controller_role_arns
}

# output "ack_chart_statuses" {
#   description = "Helm release status for each ACK controller"
#   value = module.gen3-commons.ack_chart_statuses
# }
