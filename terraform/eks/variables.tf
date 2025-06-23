variable "aws_profile" {
  description = "Username of the creator"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "gen3-vpc"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
  default     = ""
}

variable "vpc_private_subnet_ids" {
  description = "List of private subnet IDs in the VPC"
  type        = list(string)
  default     = []
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gen3-eks-cluster"
}

variable "eks_cluster_random_suffix" {
  description = "Random suffix to append to the cluster name"
  type        = string
  default     = ""
}

variable "cluster_user_ips" {
  description = "IP addresses of the users for external access to the cluster"
  type        = list(string)
  default     = []
}

variable "tags" {
  description   = "Tags to apply to all resources"
  type          = map(string)
  default       = {
    "CreatedBy" = "terraform"
  }
}