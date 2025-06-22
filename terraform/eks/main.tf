resource "random_string" "suffix" {
  length  = 4
  special = false
  lifecycle {
    prevent_destroy = true
    }
}

module "vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  version               = "5.21.0"

  name = var.vpc_name
  cidr = var.vpc_cidr
  
  azs                   = local.azs
  private_subnets       = var.vpc_private_subnets
  public_subnets        = var.vpc_public_subnets
  enable_nat_gateway    = true
  single_nat_gateway    = true
  # enable_dns_hostnames  = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

module "eks" {
  source                                    = "terraform-aws-modules/eks/aws"
  version                                   = "20.37.0"

  cluster_name                              = local.eks_cluster_name
  cluster_version                           = "1.33"
  
  cluster_endpoint_public_access            = true
  cluster_endpoint_public_access_cidrs      = var.cluster_user_ips
  cluster_endpoint_private_access           = true

  enable_cluster_creator_admin_permissions  = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["system", "general-purpose"]
  }

  vpc_id                                    = module.vpc.vpc_id
  subnet_ids                                = module.vpc.private_subnets

}


