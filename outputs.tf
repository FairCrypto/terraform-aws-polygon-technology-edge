output "jsonrpc_dns_name" {
  value       = module.alb.dns_name
  description = "The dns name for the JSON-RPC API"
}

output "vpc_id" {
  value       = module.vpc.vpc_attributes.id
  description = "vpc id"
}
