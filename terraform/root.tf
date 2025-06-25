data aws_ecrpublic_authorization_token "token" {
}



data aws_availability_zones "available" {
  state = "available"
}

locals {
  eks_cluster_name = var.eks_cluster_random_suffix != "" ? "${var.eks_cluster_name}-${var.eks_cluster_random_suffix}" : "${var.eks_cluster_name}-${random_string.suffix.result}"
  
  ack_services = {
    for item in var.ack_services :
    lower(item.name) => {
      version              = item.version
      namespace            = "ack-system"
      service_account_name = "ack-${lower(item.name)}-controller"
      policy_arn           = item.policy_arn
    }
  }

  kro_services = {
    version              = var.kro_chart_version
    namespace            = var.kro_namespace
    service_account_name = "ack-iam-controller-sa"
    policy_arns           = [
      "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
      ]

  }

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
  tags                      = local.tags
}

module "gen3-eks" {
  source                    = "./eks"
  aws_profile               = var.aws_profile
  region                    = var.region
  vpc_name                  = var.vpc_name
  vpc_id                    = module.gen3-vpc.vpc_id
  vpc_private_subnet_ids    = module.gen3-vpc.private_subnet_ids
  eks_cluster_name          = local.eks_cluster_name
  eks_cluster_random_suffix = var.eks_cluster_random_suffix
  cluster_user_ips          = var.cluster_user_ips
  tags                      = local.tags
}


module "gen3-ack-iam" {

  for_each = local.ack_services
  source   = "./iam"

  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-${each.key}-controller-${local.eks_cluster_name}"
  link_sa_to_namespace = [ "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}" ] 
  policy_arn           = [ each.value.policy_arn ]
}

 

module "gen3-ack-helm-controllers" {
  for_each      = local.ack_services
  source        = "./helm-controller"
  chart_name    = "ack-${each.key}-controller"
  chart         = "${each.key}-chart"
  repository    = "oci://public.ecr.aws/aws-controllers-k8s"
  chart_version = each.value.version
  namespace     = each.value.namespace
  set_values = [ 
    {    
      name  = "aws.region"
      value = var.region
    },
    {
      name  = "serviceAccount.name"
      value = "ack-${each.key}-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.gen3-ack-iam[each.key].iam_role_arn
    }
  ]
  depends_on    = [ module.gen3-eks, module.gen3-ack-iam ]
}

module "gen3-ack-kro-iam" {

  source   = "./iam"

  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-kro-controller-${local.eks_cluster_name}"
  link_sa_to_namespace = [ "system:serviceaccount:${local.kro_services.namespace}:${local.kro_services.service_account_name}" ]
  policy_arn           = local.kro_services.policy_arns
}

module "gen3-ack-kro-controller" {
 source        = "./helm-controller"
  chart_name    = "kro-controller"
  chart         = "kro"
  repository    = "oci://ghcr.io/kro-run/kro"
  chart_version = local.kro_services.version
  namespace     = local.kro_services.namespace
  set_values = [ 
    {
      name = "aws.region"
      value = var.region
    }, 
    {
      name  = "serviceAccount.name"
      value = local.kro_services.service_account_name
    }, 
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.gen3-ack-kro-iam.iam_role_arn
    } 
]
  depends_on    = [ module.gen3-eks ]
}

module "gen3-ack-helm-infra" {
  for_each     = local.ack_services
  source       = "./helm-infra"
  # Per-service inputs
  service_name = each.key
  namespace    = each.value.namespace
  depends_on   = [ module.gen3-ack-helm-controllers ]
}
