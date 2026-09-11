# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
