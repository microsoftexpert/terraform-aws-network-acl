###############################################################################
# Primary outputs (id + arn)
###############################################################################

output "id" {
 description = "The ID of the network ACL."
 value = aws_network_acl.this.id
}

output "arn" {
 description = <<EOT
The ARN of the network ACL (cross-resource reference type:
arn:aws:ec2:<region>:<account>:network-acl/<id>). Used in IAM/SCP policy
resource references that scope actions to this NACL.
EOT
 value = aws_network_acl.this.arn
}

output "network_acl_id" {
 description = "Alias of id, for explicit cross-module wiring and audit documentation."
 value = aws_network_acl.this.id
}

###############################################################################
# Resource attributes
###############################################################################

output "vpc_id" {
 description = "The ID of the VPC the network ACL belongs to."
 value = aws_network_acl.this.vpc_id
}

output "owner_id" {
 description = "The ID of the AWS account that owns the network ACL."
 value = aws_network_acl.this.owner_id
}

###############################################################################
# Rules
#
# Keyed by the namespaced rule key ("ingress/<label>", "egress/<label>") so a
# specific managed rule can be resolved for drift inspection.
###############################################################################

output "rule_ids" {
 description = "Map of namespaced rule key (ingress/<label>, egress/<label>) => network_acl_rule resource id."
 value = { for k, r in aws_network_acl_rule.this: k => r.id }
}

output "rules" {
 description = "Map of namespaced rule key => rule metadata (rule_number, egress, protocol, rule_action) for drift inspection and audit."
 value = {
 for k, r in aws_network_acl_rule.this: k => {
 rule_number = r.rule_number
 egress = r.egress
 protocol = r.protocol
 rule_action = r.rule_action
 }
 }
}

###############################################################################
# Associations
###############################################################################

output "association_ids" {
 description = "Map of subnet id => network_acl_association id for every subnet bound to this NACL."
 value = { for k, a in aws_network_acl_association.this: a.subnet_id => a.id }
}

###############################################################################
# Tags
###############################################################################

output "tags_all" {
 description = "All tags on the network ACL, including those inherited from provider default_tags (resource tags win on key conflict)."
 value = aws_network_acl.this.tags_all
}
