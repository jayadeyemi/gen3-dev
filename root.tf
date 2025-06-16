# Modules
module "gen3-commons" {
    source          = "./scripts/terraform"
    cluster_name    = var.cluster_name
    region          = var.region
    ack_service_map = var.ack_service_map
}
