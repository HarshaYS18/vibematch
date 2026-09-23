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
        var.connection_budget.inbox_max_pods * var.connection_budget.inbox_pool_per_pod +
        var.connection_budget.worker_max_pods * var.connection_budget.worker_pool_per_pod +
        var.connection_budget.reserved_connections
      ) <= var.connection_budget.database_max_connections
      error_message = "HPA maximum pods exceed the PostgreSQL backend connection budget."
    }
    precondition {
      condition = var.environment != "production" || alltrue([
        for value in [
          var.kubernetes.cluster_id,
          var.services.postgres_endpoint,
          var.services.redis_primary_endpoint,
          var.services.nats_endpoint,
          var.services.object_bucket,
          var.services.api_dns,
          var.services.websocket_dns,
          var.services.certificate_ref,
          var.services.secret_manager_ref,
          var.services.workload_identity_ref,
          var.services.observability_endpoint,
        ] : !strcontains(lower(value), "replace-with") && !strcontains(lower(value), ".invalid")
      ])
      error_message = "Production infrastructure bindings must be real provider values, not placeholders."
    }
    precondition {
      condition = var.environment != "production" || alltrue([
        var.kubernetes.node_pools["system"].min_nodes >= 2,
        var.kubernetes.node_pools["application"].min_nodes >= 3,
        var.kubernetes.node_pools["realtime"].min_nodes >= 3,
        var.kubernetes.node_pools["media"].min_nodes >= 3,
      ])
      error_message = "Production node pools do not meet the minimum high-availability floor."
    }
  }
}
