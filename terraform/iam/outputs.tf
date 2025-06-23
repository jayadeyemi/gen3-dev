output "iam_role_arn" {
  description = "ARN of the IRSA role for this ACK controller"
  value       = module.irsa_role.iam_role_arn
}