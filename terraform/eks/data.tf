# obtain a cluster token for providers, tokens are short lived (15 minutes)
data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}

locals {

  eks_cluster_name = var.eks_cluster_random_suffix != "" ? "${var.eks_cluster_name}-${var.eks_cluster_random_suffix}" : "${var.eks_cluster_name}-${random_string.suffix.result}"
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    "Name"        = var.vpc_name
    "Environment" = "gen3"
    "CreatedBy"   = var.aws_profile != "" ? var.aws_profile : "terraform"
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

