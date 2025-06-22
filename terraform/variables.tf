# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "aws_profile" {
  description = "Username of the creator"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "gen3-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = ""
}

variable "vpc_private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "vpc_public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "cluster_user_ips" {
  description = "IP addresses of the users for external access to the cluster"
  type        = list(string)
  default     = []
}

variable "eks_cluster_name" {
  description = "unique name of the EKS cluster"
  type        = string
  default     = "gen3-eks-cluster"
}

variable "eks_cluster_random_suffix" {
  description = "Random suffix to append to the cluster name"
  type        = string
  default     = ""
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