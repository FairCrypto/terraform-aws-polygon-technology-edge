module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = ">= 3.1.0"

  name       = var.vpc_name
  cidr_block = var.vpc_cidr_block
  az_count   = 4

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs"
    }

    private = {
      netmask                 = 24
      connect_to_public_natgw = true
    }
  }

  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}

locals {
  package_url     = var.lambda_function_zip
  downloaded      = basename(var.lambda_function_zip)
  azs             = slice(data.aws_availability_zones.current.names, 0, 4)
  private_subnets = [for _, value in module.vpc.private_subnet_attributes_by_az : value.id]
  private_azs = {
    for idx, az_name in local.azs : idx => az_name
  }
}

module "s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = ">= 3.6.0"

  bucket_prefix = var.s3_bucket_prefix
  acl           = "private"
  force_destroy = var.s3_force_destroy
}

module "security" {
  source = "./modules/security"

  vpc_id                    = module.vpc.vpc_attributes.id
  account_id                = data.aws_caller_identity.current.account_id
  s3_shared_bucket_name     = module.s3.s3_bucket_id
  ssm_parameter_id          = var.ssm_parameter_id
  region                    = data.aws_region.current.name
  internal_sec_gr_name_tag  = var.internal_sec_gr_name_tag
  alb_sec_gr_name_tag       = var.alb_sec_gr_name_tag
  lambda_function_name      = var.lambda_function_name
  rpc_cidr_allowed          = var.rpc_cidr_allowed
  metrics_cidr_allowed      = var.metrics_cidr_allowed
  node_exporter_port        = var.node_exporter_port
  polygon_edge_metrics_port = var.polygon_edge_metrics_port
  ssh_cidr_allowed          = var.ssh_cidr_allowed
}

module "instances" {
  source = "./modules/instances"

  for_each = local.private_azs

  internal_subnet             = local.private_subnets[each.key]
  internal_sec_groups         = [module.security.internal_sec_group_id]
  user_data_base64            = module.user_data[each.key].polygon_edge_node
  instance_iam_role           = module.security.ec2_to_assm_iam_policy_id
  az                          = each.value
  instance_type               = var.instance_type
  instance_name               = var.instance_name
  ebs_root_name_tag           = var.ebs_root_name_tag
  instance_interface_name_tag = var.instance_interface_name_tag
  chain_data_ebs_volume_size  = var.chain_data_ebs_volume_size
  chain_data_ebs_name_tag     = var.chain_data_ebs_name_tag
  key_name                    = var.key_name

  depends_on = [module.lambda]
}

module "user_data" {
  source = "./modules/user-data"

  for_each  = local.private_azs
  node_name = "${var.node_name_prefix}-${each.value}"

  assm_path      = var.ssm_parameter_id
  assm_region    = data.aws_region.current.name
  s3_bucket_name = module.s3.s3_bucket_id
  s3_key_name    = var.s3_key_name
  total_nodes    = length(module.vpc.private_subnet_attributes_by_az)

  polygon_edge_dir = var.polygon_edge_dir
  ebs_device       = var.ebs_device

  # Server configuration

  max_slots          = var.max_slots
  block_time         = var.block_time
  prometheus_address = var.prometheus_address
  block_gas_target   = var.block_gas_target
  nat_address        = var.nat_address
  dns_name           = format("%s.%s", var.chain_name, var.domain_name)
  price_limit        = var.price_limit

  #  # Chain configuration
  premine              = var.premine
  chain_name           = var.chain_name
  chain_id             = var.chain_id
  block_gas_limit      = var.block_gas_limit
  epoch_size           = var.epoch_size
  consensus            = var.consensus
  lambda_function_name = var.lambda_function_name
  max_validator_count  = var.max_validator_count
  min_validator_count  = var.min_validator_count
  pos                  = var.pos

}

module "alb" {
  source = "./modules/alb"

  public_subnets      = [for _, value in module.vpc.public_subnet_attributes_by_az : value.id]
  alb_sec_group       = module.security.jsonrpc_sec_group_id
  vpc_id              = module.vpc.vpc_attributes.id
  node_ids            = [for _, instance in module.instances : instance.instance_id]
  alb_ssl_certificate = var.alb_ssl_certificate
  rpc_alb_internal    = var.rpc_alb_internal

  nodes_alb_name_prefix             = var.nodes_alb_name_prefix
  nodes_alb_name_tag                = var.nodes_alb_name_tag
  nodes_alb_targetgroup_name_prefix = var.nodes_alb_targetgroup_name_prefix
}

resource "null_resource" "download_package" {
  triggers = {
    downloaded = local.downloaded
  }

  provisioner "local-exec" {
    command = "curl -L -o ${local.downloaded} ${local.package_url}"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = ">=3.3.1"

  function_name = var.lambda_function_name
  description   = "Lambda function used to initialize chain and generate genesis.json"
  handler       = "main"
  runtime       = "go1.x"
  timeout       = 20
  memory_size   = 256

  create_package         = false
  local_existing_package = data.null_data_source.downloaded_package.outputs["filename"]

  attach_policy_jsons    = true
  number_of_policy_jsons = 2
  policy_jsons           = [data.aws_iam_policy_document.genesis_s3.json, data.aws_iam_policy_document.genesis_ssm.json]
}

module "dns" {
  source = "./modules/dns"
  instance_dns_names = values(module.instances)[*].instance_dns_name
  rpc_dns_name       = module.alb.dns_name
  zone_id            = var.zone_id
  domain_name        = var.domain_name
  chain_name         = var.chain_name
}
