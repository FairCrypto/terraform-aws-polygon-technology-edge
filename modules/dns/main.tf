resource "aws_route53_record" "rpc_domain" {
  zone_id = var.zone_id
  name    = format("%s.%s", var.chain_name, var.domain_name)
  type    = "CNAME"
  ttl     = "300"
  records = [var.rpc_dns_name]
}

resource "aws_route53_record" "node_domain" {
  count = length(var.instance_dns_names)
  zone_id = var.zone_id
  name    = format("%s%s.%s", var.chain_name, count.index, var.domain_name)
  type    = "CNAME"
  ttl     = "300"
  records = [var.instance_dns_names[count.index]]
}
