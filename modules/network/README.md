# network

A two tier VPC: public subnets for the load balancer and NAT, private subnets
for the tasks.

Subnets are cut out of `cidr_block` automatically, so the only network decision
you have to make is which range to use. Pick one that will not overlap anything
you might peer with later, including the other side's ranges. A /16 gives /20
subnets, public in the first block and private starting at offset 8, which
leaves room for a third tier.

Nothing that serves a request belongs in a public subnet. The load balancer has
the public address; the tasks reach the internet outbound through NAT and are
not addressable from it.

## Default security group

Terraform adopts a VPC's default security group rather than creating one.
Declaring it with no rules empties it, so anything that lands on it by accident
can talk to nothing. This is CIS AWS Foundations control 5.4.

## Cost

Two things here cost real money.

- **NAT gateways.** Charged per hour and per GB processed. One per AZ is the
  default because a single NAT makes one AZ a single point of failure for
  outbound traffic from all of them. `single_nat_gateway = true` is reasonable
  for a test environment.
- **Interface VPC endpoints.** Charged per hour per AZ, seven endpoints when
  enabled. They keep image pulls, log writes and secret reads inside the VPC.
  Off by default so the cost is a decision rather than a surprise. The S3
  gateway endpoint has no hourly charge and is created alongside them.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | required | Prefix for every resource |
| `cidr_block` | string | `10.0.0.0/16` | Must be /20 or larger |
| `availability_zone_count` | number | `2` | 2 to 4 |
| `single_nat_gateway` | bool | `false` | Cheaper, less available |
| `enable_flow_logs` | bool | `true` | Flow logs are what you read after an incident |
| `flow_log_retention_days` | number | `90` | |
| `kms_key_arn` | string | `null` | CMK for the flow log group |
| `enable_vpc_endpoints` | bool | `false` | See cost above |
| `tags` | map(string) | `{}` | |

## Outputs

`vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`,
`availability_zones`.
