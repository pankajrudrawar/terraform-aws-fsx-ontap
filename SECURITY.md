# Security policy

## Supported versions

Security fixes go into the latest release. Please upgrade before reporting an issue against an older version.

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's private reporting instead: open the **Security** tab of this repository and choose **Report a vulnerability**. Include:

- what the problem is and which module version it affects
- a minimal configuration that shows it
- the impact you expect, for example data exposed or access granted

This is a personal open-source project, so responses are best effort. I will acknowledge reports as soon as I can and credit you in the fix if you want.

## Scope

In scope: insecure defaults or unsafe behavior in the module code, such as overly open security group rules, disabled encryption, or secrets exposed in outputs.

Out of scope: vulnerabilities in Terraform, OpenTofu, the cloud providers or their services. Report those to the vendors. Misconfiguration in your own use of the module is also out of scope, but a documentation fix is welcome.
