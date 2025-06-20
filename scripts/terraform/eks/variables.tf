# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gen3-eks-cluster"
}

variable "ack_service_map" {
  description = "Map of ACK service names to their versions"
  type        = map(string)
  default     = {
    # "service_name" = "version"
    "s3" = "1.1.3"
  }
}

variable "eks_cluster_random_suffix" {
  description = "Random suffix to append to the cluster name"
  type        = string
  default     = ""
}
