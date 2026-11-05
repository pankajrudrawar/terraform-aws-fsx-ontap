# Contributing

Thanks for taking the time to improve this module. Bug reports, fixes, docs and new options are all welcome.

Please read the [Code of Conduct](CODE_OF_CONDUCT.md) first. For questions and ideas, use [Discussions](../../discussions) before opening an issue.

## Reporting a bug

Open an issue with the bug template. The most useful reports include:

- the module version (tag or commit), Terraform or OpenTofu version, and provider version
- a minimal configuration that reproduces the problem
- the error or the unexpected plan output

Do not post secrets. Security problems go through the [Security tab](../../security/advisories/new), as described in [SECURITY.md](SECURITY.md).

## Proposing a change

1. For anything larger than a small fix, open an issue or discussion first so we can agree on the approach.
2. Fork the repository and create a branch from `main`.
3. Make your change, update the example if the change affects how the module is used, and run the checks below.
4. Open a pull request and fill in the template.

## Local setup

You need Terraform 1.5.7 or later (OpenTofu works too), plus these tools:

- [pre-commit](https://pre-commit.com)
- [TFLint](https://github.com/terraform-linters/tflint)
- [terraform-docs](https://terraform-docs.io)

Then run:

```bash
pre-commit install
pre-commit run -a
```

The hooks format the code, validate it, run TFLint and regenerate the inputs and outputs tables in `README.md`. Do not edit the content between `BEGIN_TF_DOCS` and `END_TF_DOCS` by hand.

GitHub Actions runs `terraform fmt`, `terraform validate` and TFLint for the module and its examples on every pull request. These checks do not create real infrastructure. If you applied an example against a real account, say so in the pull request, with the provider version you used.

## Design conventions

These keep the modules consistent and their plans small and predictable.

- **Secure by default.** Encryption on, public access off, TLS enforced. Riskier settings need an explicit input.
- **Keyed maps for repeated things.** Use `map(object({...}))` with static keys for mount targets, volumes, rules and similar, never lists indexed by position.
- **Secrets are separate variables.** Passwords are their own `sensitive` variables, keyed like the map they belong to, so the rest of the object stays visible in plans.
- **A `create` switch.** Every resource honors `var.create`.
- **Fail early.** Use `validation` blocks for single inputs and `precondition` blocks for combinations the provider rejects.
- **No provider blocks inside the module.** Callers configure providers.
- **Declare provider floors honestly.** If you use an argument that needs a newer provider, raise the minimum in `versions.tf` and mention it in the pull request.
- **Self-contained examples.** Each example must run with `terraform init` and `terraform validate` without extra files.
- **Describe every variable and output** in plain sentences, in sentence case, without a trailing period on short fragments.

## Commits and pull requests

Keep pull requests focused on one change. Clear, imperative commit messages are enough, for example `Add One Zone support`. Note breaking changes in the pull request description and in `CHANGELOG.md`.

## Releases

Maintainers tag releases with semantic versions such as `v0.2.0`. A tag triggers a GitHub release with generated notes. While the version is below `1.0.0`, minor releases may include breaking changes, and they will be listed in the changelog.
