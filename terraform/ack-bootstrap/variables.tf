# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "unique name of the EKS cluster"
  type        = string
  default     = "gen3-eks-cluster"
}

variable "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
  default     = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
}

variable "helm_services" {
  type = list(object({
    name       = string
    policy_arn = string
    version    = string
  }))

  default     = [{
    name = "s3"
    version = "1.0.33"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  }]
}
