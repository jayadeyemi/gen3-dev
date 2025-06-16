# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
variable "AWS_ACCOUNT_ID" {
  description = "AWS account ID"
  type        = string
  default     = "123456789012"
}
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ack_service_map" {
  description = "Map of ACK service names to their versions"
  type        = map(string)
  default     = {
    # "service_name" = "version"
    "s3" = "1.1.3"
  }
}

variable "ack_namespace" {
  description = "Namespace for ACK services"
  type        = string
  default     = "ack-system"
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