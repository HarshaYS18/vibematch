variable "environment" {
  description = "Deployment environment. Production requires real provider bindings before apply."
  type        = string
  validation {
    condition     = contains(["local", "staging", "production"], var.environment)
    error_message = "environment must be local, staging, or production."
  }
}

variable "network" {
  description = "Provider-supplied network and zone contract; no cloud network is created by this module."
  type = object({
    vpc_id          = string
    private_subnets = list(string)
    public_subnets  = list(string)
    zones           = list(string)
  })
}

variable "kubernetes" {
  description = "Provider-supplied cluster contract with separate pools for system, API/worker, realtime, media."
  type = object({
    cluster_id = string
    endpoint   = string
    node_pools = map(object({
      min_nodes = number
      max_nodes = number
      workload  = string
    }))
  })
  validation {
    condition = alltrue([
      for name in ["system", "application", "realtime", "media"] : contains(keys(var.kubernetes.node_pools), name)
    ])
    error_message = "system, application, realtime, and media node pools are required."
  }
  validation {
    condition = alltrue([
      for pool in values(var.kubernetes.node_pools) : pool.min_nodes >= 0 && pool.max_nodes >= pool.min_nodes
    ])
    error_message = "Every node pool needs nonnegative min_nodes <= max_nodes."
  }
}

variable "services" {
  description = "Externally provisioned managed services and public routes. Keep credentials in a secret manager."
  type = object({
    postgres_endpoint              = string
    redis_primary_endpoint         = string
    nats_endpoint                  = string
    nats_monitoring_endpoint       = string
    object_bucket                  = string
    object_region                  = string
    cdn_origin                     = string
    api_dns                        = string
    websocket_dns                  = string
    media_dns                      = string
    media_dns_suffix               = string
    cdn_dns                        = string
    waf_policy_ref                 = string
    origin_restriction_ref         = string
    edge_security_binding_verified = bool
    certificate_ref                = string
    secret_manager_ref             = string
    workload_identity_ref          = string
    observability_endpoint         = string
  })
  sensitive = true
}

variable "connection_budget" {
  description = "Upper bound for backend PostgreSQL connections; include pools at HPA maxima."
  type = object({
    database_max_connections  = number
    api_max_pods              = number
    api_pool_per_pod          = number
    inbox_max_pods            = number
    inbox_pool_per_pod        = number
    vibes_max_pods            = number
    vibes_pool_per_pod        = number
    room_control_max_pods     = number
    room_control_pool_per_pod = number
    worker_max_pods           = number
    worker_pool_per_pod       = number
    reserved_connections      = number
  })
  validation {
    condition = min(
      var.connection_budget.database_max_connections,
      var.connection_budget.api_max_pods,
      var.connection_budget.api_pool_per_pod,
      var.connection_budget.inbox_max_pods,
      var.connection_budget.inbox_pool_per_pod,
      var.connection_budget.vibes_max_pods,
      var.connection_budget.vibes_pool_per_pod,
      var.connection_budget.room_control_max_pods,
      var.connection_budget.room_control_pool_per_pod,
      var.connection_budget.worker_max_pods,
      var.connection_budget.worker_pool_per_pod,
      var.connection_budget.reserved_connections
    ) > 0
    error_message = "All connection budget values must be positive."
  }
}
