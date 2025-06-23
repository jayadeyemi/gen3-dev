# Modules
module "gen3-commons" {
  source                    = "./terraform"
  aws_profile               = var.aws_profile
  region                    = var.region
  vpc_name                  = var.vpc_name
  vpc_cidr                  = var.vpc_cidr
  vpc_private_subnets       = var.vpc_private_subnets
  vpc_public_subnets        = var.vpc_public_subnets
  eks_cluster_name          = var.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  cluster_user_ips          = var.cluster_user_ips
  helm_services             = var.helm_services
  kro_chart_version         = var.kro_chart_version
  kro_namespace             = var.kro_namespace
  kro_service_list          = var.kro_service_list
  kro_manifest              = var.kro_manifest
}