# Security

## Reporting a vulnerability

Please report security issues privately using GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository, rather than opening a public issue.

Include the file and resource involved, what an attacker could do with it, and
the module version you are using. We aim to acknowledge within five working
days.

## Scope

In scope: a default in this repository that leaves an account or workload
exposed, an IAM policy or resource policy that grants more than it should, a
misleading variable description, or an example that would be unsafe if copied.

Out of scope: findings in AWS itself, and findings that depend on a variable
being deliberately set to an insecure value. Some variables can be set
insecurely on purpose. Where that is true the description says so.

## What these modules do not do

They configure infrastructure. They do not review your application, your
container image, your dependencies or your data handling. A green Security Hub
dashboard is not the same as a secure service.

Before running anything from here in production, read the code. It is short on
purpose so that you can.
