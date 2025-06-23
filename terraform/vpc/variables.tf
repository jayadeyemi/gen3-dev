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

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    "CreatedBy"   = "terraform"
  }
}