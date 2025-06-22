module "irsa_ack_service" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.58.0"

  for_each = local.helm_services

  create_role  = true
  role_name    = "ACK-controller-${var.eks_cluster_name}-${each.key}"
  provider_url = var.eks_oidc_issuer_url

  role_policy_arns = [ each.value.policy_arn ]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"
  ]
}

############################x
# 3. Helm registry login
############################
# Helm itself must be authorised once per machine so it can pull
# oci://public.ecr.aws/… charts.  A simple local-exec does the trick.
resource "null_resource" "helm_registry_login" {
  provisioner "local-exec" {
    command = <<EOF
aws ecr-public get-login-password --region us-east-1 | \
  helm registry login --username AWS --password-stdin public.ecr.aws
EOF
  }
}

resource "helm_release" "ack_chart" {
  for_each = local.helm_services
  name             = "ack-${each.key}-controller"
  chart            = "${each.key}-chart"
  repository       = "oci://public.ecr.aws/aws-controllers-k8s"
  version          = each.value.version 
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false 

  set = [
    {
      name  = "aws.region"
      value = var.region
    },
    {
      name  = "serviceAccount.name"
      value = "ack-${each.key}-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.irsa_ack_service[each.key].iam_role_arn
    }
  ]
}

resource "helm_release" "ack_infra" {
  for_each         = local.helm_services
  name             = "${each.key}-manifest"
  chart            = "${path.root}/charts/${each.key}-manifest"
  namespace        = each.value.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = false

  depends_on = [
    helm_release.ack_chart
  ]

}