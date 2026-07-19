###############################################################################
# Local derivations
#
# Ingress and egress rules arrive as two separate caller-facing maps for
# readability (the stateless return-traffic concern is explicit at the call
# site). They are merged here into a single keyed collection so the module owns
# ONE child rule resource. Keys are namespaced by direction ("ingress/<key>",
# "egress/<key>") so an ingress and an egress rule may share the same caller
# label without colliding, and the egress flag is injected per entry.
###############################################################################

locals {
 ingress_rules = {
 for k, v in var.ingress_rules: "ingress/${k}" => merge(v, { egress = false })
 }

 egress_rules = {
 for k, v in var.egress_rules: "egress/${k}" => merge(v, { egress = true })
 }

 rules = merge(local.ingress_rules, local.egress_rules)

 # var.name, when set, is surfaced as the Name tag and wins over any Name key
 # the caller passed in var.tags.
 tags = var.name != null ? merge(var.tags, { Name = var.name }): var.tags
}

###############################################################################
# Network ACL (keystone)
#
# vpc_id is FORCE-NEW — a NACL cannot move VPCs. Rules and subnet associations
# are managed as standalone resources (aws_network_acl_rule /
# aws_network_acl_association), so this resource intentionally declares NO inline
# ingress/egress blocks and NO subnet_ids attribute: mixing the inline form with
# the standalone resources would cause the provider to fight over ownership.
###############################################################################

resource "aws_network_acl" "this" {
 vpc_id = var.vpc_id

 tags = local.tags
}

###############################################################################
# Numbered rules (ingress + egress)
#
# A fresh NACL denies all traffic until rules are added (the secure baseline);
# nothing is injected implicitly. Reordering a rule = changing its rule_number,
# which replaces that single rule resource without disturbing the others.
###############################################################################

resource "aws_network_acl_rule" "this" {
 for_each = local.rules

 network_acl_id = aws_network_acl.this.id
 rule_number = each.value.rule_number
 egress = each.value.egress
 protocol = each.value.protocol
 rule_action = each.value.rule_action

 cidr_block = try(each.value.cidr_block, null)
 ipv6_cidr_block = try(each.value.ipv6_cidr_block, null)
 from_port = try(each.value.from_port, null)
 to_port = try(each.value.to_port, null)
 icmp_type = try(each.value.icmp_type, null)
 icmp_code = try(each.value.icmp_code, null)
}

###############################################################################
# Subnet associations
#
# Associating a subnet here MOVES it off the VPC default NACL; on destroy the
# subnet reverts to the default NACL. for_each is keyed by the caller's stable
# label so re-pointing one subnet never churns the others.
###############################################################################

resource "aws_network_acl_association" "this" {
 for_each = var.subnet_ids

 network_acl_id = aws_network_acl.this.id
 subnet_id = each.value
}
