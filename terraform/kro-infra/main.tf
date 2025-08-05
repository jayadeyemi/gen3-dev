resource "helm_release" "kro_infra" {
  name             = var.chart_name
  chart            = var.chart_path
  namespace        =  var.namespace
  create_namespace = false
  wait             = true
}