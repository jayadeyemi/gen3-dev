locals {
  # 1. Build a policy map directly from your ack_service_map
  policy_map = {
    for svc, ver in var.ack_service_map :
    svc => "arn:aws:iam::aws:policy/Amazon${svc}FullAccess"
  }

  # 2. Compose your single source‐of‐truth service_config
  service_config = {
    for svc, ver in var.ack_service_map :
    lower(svc) => {
      version              = ver
      namespace            = "ack-${lower(svc)}-controller"
      service_account_name = "${lower(svc)}-controller"
      policy_arn           = lookup(
                              local.policy_map,
                              svc,
                              "arn:aws:iam::aws:policy/AdministratorAccess"  # fallback
                            )
    }
  }
}
