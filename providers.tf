terraform {
 required_version = ">= 1.12.0"

 required_providers {
 aws = {
 source = "hashicorp/aws"
 version = ">= 6.0, < 7.0"
 }
 }
}

###############################################################################
# Region / provider wiring (read before use)
#
# This module does NOT declare a `region` variable (region model) and does
# NOT hard-code a provider. The network ACL, its numbered ingress/egress rules
# and its subnet associations are all created with the single inherited `aws`
# provider, so the *caller* decides the Region by choosing which provider
# configuration to pass into the `aws` slot.
#
# A network ACL is a REGIONAL, VPC-scoped resource: it must be created in the
# same Region as the VPC and subnets it protects. Wire `vpc_id` and
# `subnet_ids` from a tf_mod_aws_vpc call made against the same provider/Region
# as this module.
#
# module "nacl" {
# source = "git::https://github.com/microsoftexpert/tf_mod_aws_network_acl?ref=v1.0.0"
# # inherits the default `aws` provider (whatever Region it points at)
# vpc_id = module.vpc.vpc_id
# subnet_ids = { app-a = module.vpc.private_subnet_ids["a"] }
#...
# }
#
# Provider credentials, default_tags and assume_role all live in the caller's
# provider block — never in this module.
###############################################################################
