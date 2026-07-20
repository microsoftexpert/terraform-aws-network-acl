# terraform-aws-network-acl — SCOPE

Composite module for a subnet-level Network ACL. It owns the NACL plus its
numbered ingress/egress rules and the subnet associations, modeled as `for_each`
over `map(object(...))`. NACLs are a stateless, defense-in-depth layer above the
stateful security groups owned by `terraform-aws-security-group`.

- **Module type:** Composite
- **Primary resource (keystone):** `aws_network_acl.this`

## In-scope resources

The module manages **all** of the following (allow-list):

- `aws_network_acl` — keystone
- `aws_network_acl_rule` — numbered ingress/egress rules (`for_each` over a map)
- `aws_network_acl_association` — NACL ↔ subnet bindings (`for_each` over subnet ids)

## Out-of-scope resources (consumed by reference)

Referenced by `id`, never created here:

- VPC — `vpc_id` (from `terraform-aws-vpc`)
- Subnets to associate — `subnet_ids` (from `terraform-aws-vpc`)

## Consumes

| Input | Type | Source module |
|---|---|---|
| `vpc_id` | `string` (VPC id) | `terraform-aws-vpc` |
| `subnet_ids` | `map(string)` / `set(string)` (subnet ids) | `terraform-aws-vpc` |

## Required IAM permissions

| Action | Required for |
|---|---|
| `ec2:CreateNetworkAcl`, `ec2:DeleteNetworkAcl`, `ec2:DescribeNetworkAcls` | NACL lifecycle |
| `ec2:CreateNetworkAclEntry`, `ec2:DeleteNetworkAclEntry`, `ec2:ReplaceNetworkAclEntry` | Numbered rules |
| `ec2:ReplaceNetworkAclAssociation` | Associate the NACL with subnets |
| `ec2:CreateTags`, `ec2:DeleteTags` | Tagging |

No `iam:PassRole` and no service-linked role required.

## AWS Prerequisites

- **No service-linked role** required.
- **VPC + subnets must exist** — wire `vpc_id` and `subnet_ids` from `terraform-aws-vpc`.
- **Quotas:** 200 NACLs per VPC (adjustable); 20 inbound + 20 outbound rules per
  NACL by default, raisable to 40 inbound + 40 outbound (80 total, with possible
  network-performance impact). Rule numbers must be unique per direction (1–32766;
  32767 is the reserved implicit deny). See
  [Amazon VPC quotas → Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html).
- A subnet is always associated with exactly one NACL — associating it here moves
  it off the VPC default NACL.

## Emits

| Output | Description | Consumed by |
|---|---|---|
| `id` / `network_acl_id` | NACL id | subnet/route documentation, audits |
| `arn` | NACL ARN (`arn:aws:ec2:<region>:<account>:network-acl/<id>`) | IAM/policy references |
| `rule_ids` | Map of managed rule keys → rule metadata | drift inspection |
| `association_ids` | Map of subnet id → association id | audit |
| `tags_all` | All tags incl. provider `default_tags` | governance/audit |

## Provider gotchas

- **`vpc_id` is FORCE-NEW.** A NACL cannot move VPCs.
- **Stateless rules.** Unlike security groups, NACLs evaluate inbound and
  outbound independently — you must allow ephemeral return ports (1024–65535) on
  the opposite direction. Document this in the README.
- **Rule numbering is significant.** Lower rule number wins; rule `32767` is the
  implicit deny. Reordering = renumbering, which replaces the affected rule
  resources.
- **Association is a move, not an add.** `aws_network_acl_association` reassigns a
  subnet from its current NACL; on destroy the subnet reverts to the VPC default
  NACL.
- **`tags` vs `tags_all`.** `var.tags` flows to the NACL; `tags_all` merges
  resource tags over provider `default_tags` (resource tags win). `default_tags`
  is the caller's concern. (Rule and association sub-resources are not taggable.)
- **`arn` is the cross-resource reference type.**

## Secure-by-default decisions

| Posture | Default | Opt-out |
|---|---|---|
| Ingress / egress | caller-defined numbered rules; **no implicit allow added** | add explicit rules |
| Default-NACL behavior | a fresh NACL denies all until rules are added | add rules |
| Ephemeral-port guidance | documented (stateless return traffic) | n/a |
| Subnet association | explicit via `subnet_ids` | omit to leave subnets on default NACL |

## Design decisions

- One composite owns the NACL, its numbered rules, and its associations so a
  subnet's coarse-grained boundary is described in a single call.
- Rules and associations are `map(object(...))` / keyed `for_each`, never `count`,
  so adding/removing one rule never renumbers or re-associates the others.
- NACLs are positioned as **defense-in-depth** above security groups; the README
  states that SGs (stateful) remain the primary control and NACLs are a coarse
  subnet-level backstop.
