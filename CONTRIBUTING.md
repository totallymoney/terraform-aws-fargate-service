# Contributing

Issues and pull requests are welcome.

Before opening a pull request:

```bash
terraform fmt -recursive -check
cd examples/complete && terraform init -backend=false && terraform validate
```

Guidelines:

- Keep defaults secure. If a variable can be set to something unsafe, say so in
  its description.
- New resources need a reason in the pull request, not just in the diff.
- No account ids, CIDRs, domain names, ARNs or email addresses from real
  environments, in code, examples or commit messages.
- Comments explain why, not what. The resource type already says what.
