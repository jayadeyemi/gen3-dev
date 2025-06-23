resource "kubernetes_manifest" "ack_infra" {

  manifest = yamldecode(file("${path.root}/graphs/${var.resource_graph_definition}.yaml"))

}