resource "helm_release" "kro_chart" {
  name             = "kro-controller"
  chart            = "kro"
  repository       = "oci://ghcr.io/kro-run/kro"
  version          = var.chart_version 
  namespace        = var.namespace
  create_namespace = true
  wait             = false 

  values = [
    templatefile("${path.root}/charts/kro-controller/values.yaml.tpl", {
      region = var.region
    })
  ]
}
