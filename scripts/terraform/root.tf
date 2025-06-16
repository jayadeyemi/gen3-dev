module "gen3-eks" {
  source          = "./eks"
  cluster_name    = var.cluster_name
  region          = var.region
  ack_service_map = var.ack_service_map
}

module "gen3-ack-controllers" {
  source            = "./ack-bootstrap"
  AWS_ACCOUNT_ID    = var.AWS_ACCOUNT_ID
  region            = var.region
  ack_service_map   = var.ack_service_map
  eks_cluster_name  = module.gen3-eks.eks_cluster_name
}