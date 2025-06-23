data aws_ecrpublic_authorization_token "token" {
}



data aws_availability_zones "available" {
  state = "available"
}

locals {
  eks_cluster_name = var.eks_cluster_random_suffix != "" ? "${var.eks_cluster_name}-${var.eks_cluster_random_suffix}" : "${var.eks_cluster_name}-${random_string.suffix.result}"
  
  ack_services = {
    for item in var.helm_services :
    lower(item.name) => {
      policy_arn           = item.policy_arn
      version              = item.version
      namespace            = "ack-system"
      service_account_name = "helm-${lower(item.name)}-controller"
    }
  }

  kro_link_sa_to_namespace =  [ for item in var.kro_service_list : "system:serviceaccount:${var.kro_namespace}:helm-${lower(item)}-controller" ]

  tags = {
    "Environment" = "gen3"
    "CreatedBy"   = var.aws_profile != "" ? "${var.aws_profile}-terraform" : "terraform"
  }

}

resource "random_string" "suffix" {
  length  = 4
  special = false
  lifecycle {
    prevent_destroy = true
    }
}

module "gen3-vpc" {
  source                    = "./vpc"
  aws_profile               = var.aws_profile
  region                    = var.region
  azs                       = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_name                  = var.vpc_name
  vpc_cidr                  = var.vpc_cidr
  vpc_private_subnets       = var.vpc_private_subnets
  vpc_public_subnets        = var.vpc_public_subnets
  tags                      = local.tags
}

module "gen3-eks" {
  source                    = "./eks"
  aws_profile               = var.aws_profile
  region                    = var.region
  vpc_name                  = var.vpc_name
  vpc_id                    = module.gen3-vpc.vpc_id
  vpc_private_subnet_ids       = module.gen3-vpc.vpc_private_subnet_ids
  eks_cluster_name          = local.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  cluster_user_ips          = var.cluster_user_ips
  tags                      = local.tags
}


module "gen3-ack-helm-iam" {

  for_each = local.ack_services
  source   = "./iam"

  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-helm-controller-${local.eks_cluster_name}-${each.key}"
  link_sa_to_namespace = [ "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}" ] 
  policy_arn           = [ each.value.policy_arn ]
}

module "gen3-ack-kro-iam" {
  source               = "./iam"
  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-controller-${local.eks_cluster_name}-kro"
  link_sa_to_namespace = local.kro_link_sa_to_namespace

  policy_arn           = var.kro_policy_arns
} 

module "gen3-ack-helm-controllers" {
  for_each      = local.ack_services
  source        = "./helm-controller"
  # Per-service inputs
  service_name  = each.key
  chart_version = each.value.version
  namespace     = each.value.namespace

  # Shared / derived inputs
  region        = var.region
  irsa_role_arn = module.gen3-ack-helm-iam[each.key].iam_role_arn
  depends_on    = [ module.gen3-eks, module.gen3-ack-helm-iam ]
}

module "gen3-ack-helm-infra" {
  for_each     = local.ack_services
  source       = "./helm-infra"
  # Per-service inputs
  service_name = each.key
  namespace    = each.value.namespace
  depends_on   = [ module.gen3-ack-helm-controllers ]
}

module "gen3-ack-kro-controllers" {
  source        = "./kro-controller"
  region        = var.region
  chart_version = var.kro_chart_version
  namespace     = var.kro_namespace
  irsa_role_arn = module.gen3-ack-kro-iam.iam_role_arn
  depends_on    = [ module.gen3-eks, module.gen3-ack-kro-iam ]
}

# module "gen3-ack-kro-graph" {
#   source                    = "./kro-infra"
#   resource_graph_definition = var.kro_manifest
#   depends_on                = [ module.gen3-ack-kro-controllers ]
# }
