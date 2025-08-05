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
  depends_on = [ module.gen3-vpc ]
}

###################################################################################################################
# IAM Role Provisioning
module "gen3-ack-iam" {

  for_each = local.ack_services
  source   = "./iam"

  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-${each.key}-controller-${local.eks_cluster_name}"
  link_sa_to_namespace = [ "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}" ] 
  policy_arn           = [ each.value.policy_arn ]
  depends_on = [ module.gen3-eks  ]
  }

module "gen3-ack-kro-iam" {

  source   = "./iam"

  oidc_provider_url    = module.gen3-eks.eks_oidc_issuer_url
  role_name            = "ack-kro-controller-${local.eks_cluster_name}"
  link_sa_to_namespace = [ "system:serviceaccount:${local.kro_services.namespace}:${local.kro_services.service_account_name}" ]
  policy_arn           = local.kro_services.policy_arns
  depends_on = [ module.gen3-eks  ]
}
###################################################################################################################
# Namespace Provisioning
resource "kubernetes_namespace" "ack" {
  depends_on = [
    module.gen3-eks,
    module.gen3-ack-iam
  ]

  metadata {
    name = "ack-system"
  }
}

resource "kubernetes_namespace" "kro" {
  depends_on = [
    module.gen3-eks,
  ]

  metadata {
    name = local.kro_services.namespace
  }
}
###################################################################################################################
# ACK Controller Provisioning (Required for both ACK and KRO deployment)
###################################################################################################################
module "gen3-ack-helm-controllers" {
  for_each             = local.ack_services
  source               = "./helm"
  chart_name           = "ack-${each.key}-controller"
  chart                = "${each.key}-chart"
  repository           = "oci://public.ecr.aws/aws-controllers-k8s"
  chart_version        = each.value.version
  namespace            = each.value.namespace
  create_namespace     = false
  values = [
    templatefile("${path.root}/charts/ctrl-templates/ack.yaml.tpl", {
      region               = var.region
      service_account_name = each.value.service_account_name
      role_arn             = module.gen3-ack-iam[each.key].iam_role_arn
    })
  ]
  depends_on           = [ 
    module.gen3-eks, 
    module.gen3-ack-iam,
    kubernetes_namespace.ack
    ]
}
# ##################################################################################################################
# ACK CRs
# ##################################################################################################################
module "gen3-ack-helm-infra" {
  for_each     = local.ack_services
  source       = "./helm"
  chart_name   = "${each.key}-manifest"
  chart        = "${path.root}/charts/${each.key}-manifest"
  namespace    =  each.value.namespace
  repository   = null
  create_namespace = false
  chart_version = null
  values = null


  depends_on   = [module.gen3-ack-helm-controllers] 
}
###################################################################################################################
# KRO Controller, RG, and Instance Provisioning
###################################################################################################################
module "gen3-ack-kro-controller" {
 source        = "./helm"
  chart_name    = "kro-controller"
  chart         = "kro"
  repository    = "oci://ghcr.io/kro-run/kro"
  chart_version = local.kro_services.version
  namespace     = local.kro_services.namespace
  create_namespace = false
 
  values = [
    templatefile("${path.root}/charts/ctrl-templates/kro.yaml.tpl", {
      region               = var.region
    })
  ]

  depends_on    = [
    module.gen3-eks,
    module.gen3-ack-helm-controllers,
    kubernetes_namespace.kro
    ]
}
# Resource Graphs for KRO
module "gen3-ack-kro-rg1-infra" {
  source = "./helm"
  chart_name = "kro-rg1"
  chart      = "${path.root}/charts/kro-rg1-manifest"
  namespace  = local.kro_services.namespace
  repository = null
  create_namespace = false
  chart_version = null
  values = null

  depends_on = [module.gen3-ack-kro-controller]
}

module "gen3-ack-kro-rg2-infra" {
  source = "./helm"
  chart_name = "kro-rg2"
  chart      = "${path.root}/charts/kro-rg2-manifest"
  namespace  = local.kro_services.namespace
  repository = null
  create_namespace = false
  chart_version = null
  values = null
  depends_on = [module.gen3-ack-kro-rg1-infra]
}
# KRO Instance
module "gen3-ack-kro-instance-infra" {
  source = "./helm"
  chart_name = "kro-instance"
  chart      = "${path.root}/charts/kro-instance-manifest"
  namespace  = local.kro_services.namespace
  repository = null
  create_namespace = false
  chart_version = null
  values = null

  depends_on = [module.gen3-ack-kro-rg2-infra]
}