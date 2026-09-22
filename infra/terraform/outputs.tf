output "node_pool_contract" {
  description = "Node pool labels and capacity settings for the selected provider's autoscaler."
  value       = var.kubernetes.node_pools
}

output "connection_budget_total" {
  description = "Worst case API plus worker pool connections, including reserve."
  value = (
    var.connection_budget.api_max_pods * var.connection_budget.api_pool_per_pod +
    var.connection_budget.worker_max_pods * var.connection_budget.worker_pool_per_pod +
    var.connection_budget.reserved_connections
  )
}

output "service_bindings" {
  description = "Service endpoints to bind to ExternalSecret and Kubernetes environment configuration."
  value       = var.services
  sensitive   = true
}
