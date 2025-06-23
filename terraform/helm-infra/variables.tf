variable "service_name" {
  description = "Name of the service for which ACK controller is being installed"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the ACK controller will be deployed"
  type        = string
  default     = "ack-system"  # Default namespace for ACK controllers
}