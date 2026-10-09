# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

Breaking. Services now share one load balancer instead of creating one each.

### Added

- `modules/alb`: the load balancer, its certificate, its WAF and its access log
  bucket, stood up once and shared. New inputs on the root module to attach to
  it: `listener_arn`, `alb_security_group_id`, `alb_arn_suffix`, `host_headers`
  and `listener_rule_priority`.
- The HTTPS listener's default action refuses with a configurable status, so a
  hostname pointed at the load balancer before its service exists gets a 403
  rather than whichever service happens to be first.
- `listener_rule_arn` output on the root module. `arn_suffix` output on
  `modules/alb`.
- Tests for `modules/alb`, run in CI alongside the root module's.

### Changed

- Each service creates a target group, a listener rule claiming its hostnames,
  and a single egress rule on the shared security group to its own tasks. It no
  longer creates a load balancer, a WAF or an access log bucket.
- The origin secret header is now a second condition on the service's rule
  rather than the listener's default action, so one load balancer can carry
  services with and without it.
- The example deploys two services behind one load balancer.

### Removed

Moved to `modules/alb`: `public_subnet_ids`, `certificate_arn`,
`additional_certificate_arns`, `ssl_policy`, `internal`, `idle_timeout`,
`enable_deletion_protection`, `access_logs_retention_days`,
`alb_ingress_cidrs`, `alb_ingress_prefix_list_ids`, `enable_waf`,
`waf_rate_limit`, `waf_managed_rule_groups`,
`waf_rate_limit_forwarded_ip_header`. Outputs `alb_dns_name`, `alb_zone_id`,
`alb_arn`, `alb_security_group_id`, `access_logs_bucket` and `web_acl_arn` moved
with them.

### Why

At five services the old shape meant five load balancers and five WAFs, about
$170 a month on duplicated infrastructure. See the upgrade notes in the README
for the `terraform state mv` commands that make this a rename rather than a
rebuild.

## [0.1.0]

First release.

- Application Load Balancer, HTTPS with a TLS 1.3 and 1.2 policy, HTTP
  redirect, access logs to S3, ingress restricted to CDN ranges or a managed
  prefix list
- Optional origin secret header enforced as a listener rule, so the origin is
  tied to your CDN distribution rather than to the CDN as a whole
- AWS WAF with three AWS managed rule groups, a rate limit that can aggregate
  on a forwarded client address, and logging with sensitive headers redacted
- ECS Fargate service in private subnets, no public IP, deployment circuit
  breaker, CPU target tracking autoscaling
- Deployment rollback driven by load balancer alarms, not only by failing tasks
- Service alarms: 5xx rate, unhealthy targets, running tasks below the floor
- Separate execution and task roles with confused deputy conditions, execution
  role scoped to exactly the secrets named in the task definition
- ECR with scan on push, immutable tags, lifecycle policy, account scoped pull
- `modules/network`: two tier VPC, NAT, flow logs, emptied default security
  group, optional interface endpoints
