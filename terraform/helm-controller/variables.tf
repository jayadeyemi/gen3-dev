variable "name" {
  description = "Name of the user creating the resources"
  type        = string
  default     = ""
}

variable "chart_name" {
  description = "Name of the ACK controller Helm chart to install"
  type        = string
  default     = "ack-controller"  # Adjust as needed
}

variable "chart" {
  description = "Path to the ACK controller Helm chart"
  type        = string
  default     = "eks-chart"  # Default Helm repository path for ACK controllers
}

variable "repository" {
  description = "Helm repository URL for the ACK controller chart"
  type        = string
  default     = "https://aws.github.io/eks-charts"  # Default Helm repository for ACK controllers
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

variable "set_values" {
  description = "List of values to set in the Helm chart"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "aws.region"
      value = "us-west-2"  # Adjust as needed
    },
    {
      name  = "serviceAccount.name"
      value = "ack-controller-service-account"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = ""  # Specify the IAM role ARN for IRSA if needed
    }
  ]
}