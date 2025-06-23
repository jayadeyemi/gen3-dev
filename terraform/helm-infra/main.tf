resource "helm_release" "ack_infra" {
  name             = "${var.service_name}-manifest"
  chart            = "${path.root}/charts/${var.service_name}-manifest"
  namespace        =  var.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = false
}