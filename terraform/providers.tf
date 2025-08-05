provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

terraform {

  required_providers {
    random     = { source = "hashicorp/random"    , version = "~> 3.6.1" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.37.1" }
    helm       = { source = "hashicorp/helm"      , version = "~> 3.0.1" }
    tls        = { source = "hashicorp/tls"       , version = "~> 4.0.5" }
    cloudinit  = { source = "hashicorp/cloudinit" , version = "~> 2.3.4" }
    kubectl    = { source = "alekc/kubectl" , version = "~> 2.1.3" }
    }
  required_version = "~> 1.3"
}


provider "kubernetes" {
  host                   = module.gen3-eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.gen3-eks.eks_cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.gen3-eks.eks_cluster_name]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.gen3-eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.gen3-eks.eks_cluster_ca_certificate)

    exec     = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.gen3-eks.eks_cluster_name]
    }
  }
  
  registries = [
    {
      url      = "oci://public.ecr.aws/aws-controllers-k8s"
      username = "AWS"
      password = data.aws_ecrpublic_authorization_token.token.password
    }
  ]
}

provider "kubectl" {
  host                   = module.gen3-eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.gen3-eks.eks_cluster_ca_certificate)
  token                  = module.gen3-eks.eks_cluster_token
  load_config_file       = false
}