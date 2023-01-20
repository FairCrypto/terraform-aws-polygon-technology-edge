variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "internal_sec_gr_name_tag" {
  type        = string
  description = "Internal security group name tag"
}

variable "s3_shared_bucket_name" {
  type        = string
  description = "The name of the S3 bucket that holds shared polygon-edge nodes data"
}

variable "ssm_parameter_id" {
  description = "The id that will be used for storing and fetching from SSM Parameter Store"
  type        = string
}

variable "region" {
  type        = string
  description = "The region in which instances reside. Default: us-west-2"
}

variable "account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "alb_sec_gr_name_tag" {
  type        = string
  description = "The name tag for ALB security group"
}

variable "lambda_function_name" {
  type        = string
  description = "The name of the chain initialization Lambda function"
}

variable "rpc_cidr_allowed" {
  type        = string
  description = "The CIDR range that is allowed to access the RPC port"
  default     = "0.0.0.0/0"
}

variable "metrics_cidr_allowed" {
  type        = string
  description = "The CIDR range that is allowed to access the metrics port"
  default     = ""
}

variable "node_exporter_port" {
  type        = string
  description = "The port that node_exporter is listening on"
  default     = 9100
}

variable "polygon_edge_metrics_port" {
  type        = string
  description = "The port that polygon edge metrics is listening on"
  default     = 9090
}
