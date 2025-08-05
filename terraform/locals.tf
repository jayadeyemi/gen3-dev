locals {
  eks_cluster_name = var.eks_cluster_random_suffix != "" ? "${var.eks_cluster_name}-${var.eks_cluster_random_suffix}" : "${var.eks_cluster_name}-${random_string.suffix.result}"
  
  ack_services = {
    for item in var.ack_services :
    lower(item.name) => {
      version              = item.version
      namespace            = "ack-system"
      service_account_name = "ack-${lower(item.name)}-controller"
      policy_arn           = item.policy_arn
    }
  }

  kro_services = {
    version              = var.kro_chart_version
    namespace            = var.kro_namespace
    service_account_name = "ack-iam-controller-sa"
    policy_arns           = [
      "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
      ]

  }

  tags = {
    "Environment" = "gen3"
    "CreatedBy"   = var.aws_profile != "" ? "${var.aws_profile}-terraform" : "terraform"
  }


}
