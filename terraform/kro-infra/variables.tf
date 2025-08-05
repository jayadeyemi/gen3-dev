variable "chart_name" {
  description = "The name of the chart to deploy"
  type        = string
  default     = "kro-instance-manifest"
}

variable "chart_path" {
  description = "The path to the chart to deploy"
  type        = string
  default     = "kro-manifests"
}

variable "namespace" {
  description = "The Kubernetes namespace to deploy the chart into"
  type        = string
  default     = "ack-system"
}