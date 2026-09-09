# Complete example

A public web service: VPC, load balancer, WAF, ECS Fargate service, ECR
repository and a secret read at start up.

```bash
cp terraform.tfvars.example terraform.tfvars
# edit certificate_arn, container_image and cdn_ingress_cidrs
terraform init
terraform plan
```

Three values need replacing before this will apply:

- `certificate_arn`: an ACM certificate in the same region as the load
  balancer, covering the hostname you will serve.
- `container_image`: your image. Use a digest or an immutable tag.
- `cdn_ingress_cidrs`: your CDN's published origin ranges. The placeholder is
  a documentation range and will not let any real traffic through.

The example creates the SSM parameter that holds `DATABASE_URL` but not its
value, and ignores changes to it. Set the real value out of band so the secret
is neither in the repository nor in state.

DNS and the CDN itself are not created here. Take `alb_dns_name` from the
outputs and point your CDN origin at it.
