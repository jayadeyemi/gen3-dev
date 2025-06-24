data "aws_availability_zones" "zones" {
  state = "available"
}
locals {
    azs      = slice(data.aws_availability_zones.zones.names, 0, 3)

}

module "vpc" {
  source                = "terraform-aws-modules/vpc/aws"
  version               = "5.21.0"

  name = var.vpc_name
  cidr = var.vpc_cidr
  
  
  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  
  enable_nat_gateway    = true
  single_nat_gateway    = true
  
  private_subnet_names = [
    for i, az in local.azs : "${var.vpc_name}-private-${i + 1}"
  ]

  public_subnet_names = [
    for i, az in local.azs : "${var.vpc_name}-public-${i + 1}"
  ]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
