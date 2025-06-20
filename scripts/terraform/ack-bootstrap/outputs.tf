# -----------------------------------------------------------------------------
# Map of IAM role ARNs, keyed by service (e.g. "s3" → "arn:…")
# -----------------------------------------------------------------------------
output "ack_controller_role_arns" {
  description = "IAM role ARNs for each ACK controller, keyed by service"
  value = {
    for svc, mod in module.irsa_ack_service :
    svc => mod.iam_role_arn
  }
}

# # -----------------------------------------------------------------------------
# # Map of Helm release statuses, keyed by service (e.g. "s3" → "deployed")
# # -----------------------------------------------------------------------------
# output "ack_controller_statuses" {
#   description = "Helm release status for each ACK controller, keyed by service"
#   value = {
#     for svc, rel in helm_release.ack_service_controller :
#     svc => rel.status
#   }
# }
