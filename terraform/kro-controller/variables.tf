variable "region" {
  description = "AWS region where the ACK controller will be deployed"
  type        = string
}

variable "chart_version" {
  description = "Version of the ACK controller Helm chart to install"
  type        = string
  default     = "1.0.0"  # Adjust as needed
}

variable "namespace" {
  description = "Kubernetes namespace where the ACK controller will be deployed"
  type        = string
  default     = "ack-system"  # Default namespace for ACK controllers
}

variable "irsa_role_arn" {
  description = "ARN of the IAM role for the ACK service account"
  type        = string
  default     = "arn:aws:iam::123456789012:role/ack-service-role"  # Replace with actual ARN
}