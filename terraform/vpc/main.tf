

module "vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  version               = "5.21.0"

  name = var.vpc_name
  cidr = var.vpc_cidr
  
  azs                   = var.azs
  private_subnets       = var.vpc_private_subnets
  public_subnets        = var.vpc_public_subnets
  
  enable_nat_gateway    = true
  single_nat_gateway    = true
  
  private_subnet_names = [
    for i, az in var.azs : "${var.vpc_name}-private-${i + 1}"
  ]

  public_subnet_names = [
    for i, az in var.azs : "${var.vpc_name}-public-${i + 1}"
  ]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
