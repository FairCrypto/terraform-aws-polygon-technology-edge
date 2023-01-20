variable "zone_id" {
  type        = string
  description = "The zone id of the domain"
}

variable "rpc_dns_name" {
  type        = string
  description = "The DNS name of the RPC server"
}

variable "domain_name" {
  type        = string
  description = "The domain name"
}

variable "instance_dns_names" {
  type        = list(string)
  description = "The DNS names of the instances"
}

variable "chain_name" {
  type        = string
  description = "Set the name of chain"
  default     = ""
}
