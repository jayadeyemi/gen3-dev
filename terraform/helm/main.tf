resource "helm_release" "ack_controller" {
  name             = try(var.chart_name, null)
  chart            = try(var.chart, null)
  version          = try(var.chart_version, null)
  namespace        = try(var.namespace, null)
  create_namespace = try(var.create_namespace, false)
  wait             = true
  repository       = try(var.repository, null)
  values = try(var.values, [])
}