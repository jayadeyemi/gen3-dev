
variable "chart_name" {
  description = "Name of the ACK controller Helm chart to install"
  type        = string
}

variable "chart" {
  description = "Path to the ACK controller Helm chart"
  type        = string
}

variable "repository" {
  description = "Helm repository URL for the ACK controller chart"
  type        = string
}

variable "create_namespace" {
  description = "Whether to create the namespace for the ACK controller"
  type        = bool
}

variable "chart_version" {
  description = "Version of the ACK controller Helm chart to install"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the ACK controller will be deployed"
  type        = string
}

variable "values" {
  description = "Values to pass to the Helm chart"
  type        = any
}

