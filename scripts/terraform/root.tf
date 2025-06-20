module "gen3-eks" {
  source                    = "./eks"
  eks_cluster_name          = var.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  region                    = var.region
  ack_service_map           = var.ack_service_map
}

# module "gen3-kube-config" {
#   source            = "./kube-config"
#   cluster_name      = module.gen3-eks.eks_cluster_name
#   context_name      = var.eks_cluster_name
#   cluster_user      = "aws"
#   endpoint          = module.gen3-eks.eks_cluster_endpoint
#   ca_data           = module.gen3-eks.eks_cluster_ca_data
#   client_cert_data  = module.gen3-eks.eks_cluster_client_cert_data
#   client_key_data   = module.gen3-eks.eks_cluster_client_key_data
  
# }

module "gen3-ack-controllers" {
  source            = "./ack-bootstrap"
  AWS_ACCOUNT_ID    = var.AWS_ACCOUNT_ID
  region            = var.region
  ack_service_map   = var.ack_service_map
  eks_cluster_name  = module.gen3-eks.eks_cluster_name
}