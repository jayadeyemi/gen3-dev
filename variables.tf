
# Variables
variable "region" {
    description = "AWS region"
    type        = string
    default     = "us-east-1"
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

variable "aws_profile" {
    description = "AWS profile to use for authentication"
    type        = string
    default     = "default"
}

variable "ack_service_map" {
    description = "Map of ACK service names to their versions"
    type        = map(string)
    default     = {
        # "Case sensitive service name" = "version"
        "S3"                            = "1.0.33"
        "DynamoDB"                      = "1.1.3"
    }
  
}

