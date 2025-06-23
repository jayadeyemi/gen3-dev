resource "helm_release" "ack_controller" {
  name             = "ack-${var.service_name}-controller"
  chart            = "${var.service_name}-chart"
  repository       = "oci://public.ecr.aws/aws-controllers-k8s"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = false

  set = [
    {    
      name  = "aws.region"
      value = var.region
    },
    {
      name  = "serviceAccount.name"
      value = "ack-${var.service_name}-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.irsa_role_arn
    }
  ]
}