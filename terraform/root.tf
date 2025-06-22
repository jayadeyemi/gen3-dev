data aws_ecrpublic_authorization_token "token" {
}

module "gen3-eks" {
  source                    = "./eks"
  aws_profile               = var.aws_profile
  region                    = var.region
  vpc_name                  = var.vpc_name
  vpc_private_subnets       = var.vpc_private_subnets
  vpc_public_subnets        = var.vpc_public_subnets
  vpc_cidr                  = var.vpc_cidr
  eks_cluster_name          = var.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  cluster_user_ips          = var.cluster_user_ips
}

module "gen3-ack-controllers" {
  source              = "./ack-bootstrap"
  region              = var.region
  eks_cluster_name    = module.gen3-eks.eks_cluster_name
  eks_oidc_issuer_url = module.gen3-eks.eks_oidc_issuer_url
  helm_services       = var.helm_services
  depends_on          = [ module.gen3-eks ]
  }