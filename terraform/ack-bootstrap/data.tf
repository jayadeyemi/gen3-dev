locals {
  # 3. Build a map of helm services
  helm_services = {
    for item in var.helm_services :
    lower(item.name) => {
      policy_arn           = item.policy_arn
      version              = item.version
      namespace            = "ack-system"
      service_account_name = "ack-${lower(item.name)}-controller"
    }
  }
}