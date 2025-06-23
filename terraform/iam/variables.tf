
variable "oidc_provider_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
  default     = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
}

variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
  default     = "ack-controller-role"
}

variable "policy_arn" {
  description = "ARN of the IAM policy to attach to the role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonEKSServicePolicy"]
}

variable "link_sa_to_namespace" {
  description = "Map of service account names to their respective namespaces"
  type        = list(string)
  default     = []
}