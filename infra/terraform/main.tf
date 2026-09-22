# A provider-neutral preflight contract. The owner must bind these interfaces to a
# selected cloud provider before provisioning; this module never claims to create
# production infrastructure or stores credentials in state.
resource "terraform_data" "deployment_contract" {
  input = {
    environment = var.environment
    network_id  = var.network.vpc_id
    cluster_id  = var.kubernetes.cluster_id
  }

  lifecycle {
    precondition {
      condition     = length(var.network.zones) >= 2 || var.environment == "local"
      error_message = "Staging and production require at least two availability zones."
    }
    precondition {
      condition = (
        var.connection_budget.api_max_pods * var.connection_budget.api_pool_per_pod +
        var.connection_budget.worker_max_pods * var.connection_budget.worker_pool_per_pod +
        var.connection_budget.reserved_connections
      ) <= var.connection_budget.database_max_connections
      error_message = "HPA maximum pods exceed the PostgreSQL backend connection budget."
    }
  }
}
