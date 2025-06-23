module "irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.58.0"

  create_role  = true
  role_name    = var.role_name
  provider_url = var.oidc_provider_url

  role_policy_arns = var.policy_arn

  oidc_fully_qualified_subjects = var.link_sa_to_namespace
}
