resource "helm_release" "ack_controller" {
  name             = var.chart_name
  chart            = var.chart
  repository       = var.repository
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  wait             = false
 
  set = var.set_values

}