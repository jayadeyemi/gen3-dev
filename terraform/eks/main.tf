

module "eks" {
  source                                    = "terraform-aws-modules/eks/aws"
  version                                   = "20.37.1"

  cluster_name                              = var.eks_cluster_name
  cluster_version                           = "1.33"
  
  cluster_endpoint_public_access            = true
  cluster_endpoint_public_access_cidrs      = var.cluster_user_ips
  cluster_endpoint_private_access           = true

  enable_cluster_creator_admin_permissions  = true
  
  cluster_compute_config = {
    enabled    = true
    node_pools = ["system", "general-purpose"]
  }
 
  vpc_id                                    = var.vpc_id
  subnet_ids                                = var.vpc_private_subnet_ids

  tags                                      = var.tags

}


