###############################################################################
# Identity
###############################################################################

variable "name" {
 description = <<EOT
Logical name for the network ACL. A network ACL has no native `name` argument in
the AWS API, so this value is surfaced purely as the `Name` tag on the NACL (and
takes precedence over any `Name` key supplied in var.tags). Leave null to omit
the Name tag entirely. This is the human-friendly identity used in the console
and in tag-based governance.
EOT
 type = string
 default = null
}

variable "vpc_id" {
 description = <<EOT
ID of the VPC the network ACL is created in. REQUIRED and FORCE-NEW — a NACL
cannot move between VPCs, so changing this destroys and recreates the NACL (and
its rules and associations). Wire from tf_mod_aws_vpc (vpc_id).
EOT
 type = string

 validation {
 condition = can(regex("^vpc-[0-9a-f]{8,}$", var.vpc_id))
 error_message = "vpc_id must be a valid VPC id (e.g. vpc-0123456789abcdef0)."
 }
}

###############################################################################
# Ingress rules (child collection — for_each over map(object))
#
# SECURE DEFAULT: no rule is added implicitly. A freshly created NACL denies all
# traffic until the caller adds explicit rules, so the empty default ({}) yields
# a deny-all boundary. NACLs are STATELESS — return traffic is NOT automatically
# allowed, so an ingress allow almost always needs a matching egress allow for
# the ephemeral port range (typically 1024-65535) and vice versa.
###############################################################################

variable "ingress_rules" {
 description = <<EOT
Map of inbound (ingress) rules keyed by a stable caller-chosen label, each
rendered as one aws_network_acl_rule with egress = false. The key is the map key
used in the rule_ids output; the rule_number controls evaluation order. Lower
rule_number wins; numbers must be unique within the ingress direction. Rule 32767
is the implicit, unmanaged deny-all.

 - rule_number: evaluation order, 1-32766. Unique per direction. (required)
 - protocol: "tcp", "udp", "icmp", "icmpv6", "-1" (all), or an IANA
 protocol number as a string. "-1" matches all ports. (required)
 - rule_action: "allow" or "deny". (required)
 - cidr_block: IPv4 network range to match (e.g. "10.0.0.0/16"). Supply
 exactly one of cidr_block or ipv6_cidr_block.
 - ipv6_cidr_block: IPv6 network range to match. Supply exactly one of
 cidr_block or ipv6_cidr_block.
 - from_port: start of the port range (ignored when protocol is "-1").
 - to_port: end of the port range (ignored when protocol is "-1").
 - icmp_type: ICMP type (required when protocol is "icmp"/"icmpv6"; -1 = all).
 - icmp_code: ICMP code (required when protocol is "icmp"/"icmpv6"; -1 = all).

 ingress_rules = {
 allow-https-in = { rule_number = 100, protocol = "tcp", rule_action = "allow", cidr_block = "10.0.0.0/8", from_port = 443, to_port = 443 }
 allow-ephemeral-in = { rule_number = 200, protocol = "tcp", rule_action = "allow", cidr_block = "0.0.0.0/0", from_port = 1024, to_port = 65535 }
 }
EOT
 type = map(object({
 rule_number = number
 protocol = string
 rule_action = string
 cidr_block = optional(string)
 ipv6_cidr_block = optional(string)
 from_port = optional(number)
 to_port = optional(number)
 icmp_type = optional(number)
 icmp_code = optional(number)
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.ingress_rules: v.rule_number >= 1 && v.rule_number <= 32766])
 error_message = "Each ingress_rules[*].rule_number must be between 1 and 32766 (32767 is the reserved implicit deny)."
 }

 validation {
 condition = alltrue([for k, v in var.ingress_rules: contains(["allow", "deny"], v.rule_action)])
 error_message = "Each ingress_rules[*].rule_action must be either \"allow\" or \"deny\"."
 }

 validation {
 condition = alltrue([for k, v in var.ingress_rules: can(regex("^(-1|tcp|udp|icmp|icmpv6|[0-9]{1,3})$", v.protocol))])
 error_message = "Each ingress_rules[*].protocol must be \"-1\", \"tcp\", \"udp\", \"icmp\", \"icmpv6\", or an IANA protocol number string."
 }

 validation {
 condition = alltrue([for k, v in var.ingress_rules: (try(v.cidr_block, null) != null) != (try(v.ipv6_cidr_block, null) != null)])
 error_message = "Each ingress_rules[*] must set exactly one of cidr_block or ipv6_cidr_block."
 }
}

###############################################################################
# Egress rules (child collection — for_each over map(object))
###############################################################################

variable "egress_rules" {
 description = <<EOT
Map of outbound (egress) rules keyed by a stable caller-chosen label, each
rendered as one aws_network_acl_rule with egress = true. Same object schema and
validations as ingress_rules; rule_number must be unique within the egress
direction (ingress and egress are numbered independently). Because NACLs are
stateless, this is where the matching ephemeral-port allow for inbound replies
usually lives.

 egress_rules = {
 allow-all-out = { rule_number = 100, protocol = "-1", rule_action = "allow", cidr_block = "0.0.0.0/0" }
 }

See ingress_rules for the full field reference.
EOT
 type = map(object({
 rule_number = number
 protocol = string
 rule_action = string
 cidr_block = optional(string)
 ipv6_cidr_block = optional(string)
 from_port = optional(number)
 to_port = optional(number)
 icmp_type = optional(number)
 icmp_code = optional(number)
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.egress_rules: v.rule_number >= 1 && v.rule_number <= 32766])
 error_message = "Each egress_rules[*].rule_number must be between 1 and 32766 (32767 is the reserved implicit deny)."
 }

 validation {
 condition = alltrue([for k, v in var.egress_rules: contains(["allow", "deny"], v.rule_action)])
 error_message = "Each egress_rules[*].rule_action must be either \"allow\" or \"deny\"."
 }

 validation {
 condition = alltrue([for k, v in var.egress_rules: can(regex("^(-1|tcp|udp|icmp|icmpv6|[0-9]{1,3})$", v.protocol))])
 error_message = "Each egress_rules[*].protocol must be \"-1\", \"tcp\", \"udp\", \"icmp\", \"icmpv6\", or an IANA protocol number string."
 }

 validation {
 condition = alltrue([for k, v in var.egress_rules: (try(v.cidr_block, null) != null) != (try(v.ipv6_cidr_block, null) != null)])
 error_message = "Each egress_rules[*] must set exactly one of cidr_block or ipv6_cidr_block."
 }
}

###############################################################################
# Subnet associations (child collection — for_each over map(string))
###############################################################################

variable "subnet_ids" {
 description = <<EOT
Map of subnet associations keyed by a stable caller-chosen label, value being the
subnet id to bind to this NACL. Each entry is rendered as one
aws_network_acl_association. Wire subnet ids from tf_mod_aws_vpc.

A subnet is always associated with exactly one NACL: associating it here MOVES it
off the VPC default NACL; on destroy the subnet reverts to the VPC default NACL.
Keys are caller-supplied labels (not the subnet ids) so a single subnet can be
re-pointed without re-keying the rest of the map, and so for_each stays stable
even when the underlying subnet ids are not known until apply.

 subnet_ids = {
 app-a = module.vpc.private_subnet_ids["a"]
 app-b = module.vpc.private_subnet_ids["b"]
 }
EOT
 type = map(string)
 default = {}
}

###############################################################################
# Universal tail
###############################################################################

variable "tags" {
 description = <<EOT
Map of tags to assign to the network ACL (the only taggable resource in this
module — aws_network_acl_rule and aws_network_acl_association are not taggable).
These merge with provider-level default_tags; resource tags win on key conflict.
When var.name is set it is applied as the Name tag and overrides any Name key
supplied here. The computed tags_all output reflects the fully merged set.
EOT
 type = map(string)
 default = {}
}
