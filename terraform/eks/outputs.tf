output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = module.eks.oidc_provider
}

output "eks_cluster_name" {
  description = "Unique name of the EKS cluster"
  value       = var.eks_cluster_name
}

output "eks_cluster_id" {
  description = "The ID of the EKS cluster. Note: currently a value is returned only for local EKS clusters created on Outposts"
  value       = module.eks.cluster_id
}

output "eks_oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "eks_cluster_ca_certificate" {
  description = "The base64-encoded certificate data required to communicate with the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_token" {
  description = "The token used to authenticate with the EKS cluster"
  value       = data.aws_eks_cluster_auth.cluster_auth.token
}