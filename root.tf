# Modules
module "gen3-commons" {
  source                    = "./scripts/terraform"
  eks_cluster_name          = var.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  region                    = var.region
  ack_service_map           = var.ack_service_map
}
