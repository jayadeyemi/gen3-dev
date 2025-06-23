resource "helm_release" "kro_chart" {
  name             = "kro-controller"
  chart            = "kro"
  repository       = "oci://ghcr.io/kro-run/kro"
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
      value = "kro-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.irsa_role_arn
    }
  ]
}
