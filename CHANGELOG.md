# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [3.0.1](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v3.0.1) - 2026-11-25


### 📝 Other

- Update CHANGELOG.md for v3.0.1 ([0041b97f](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/0041b97f7236b8f0b1b16bf4f236db100aeb87b4))
- Validate the module with Terraform and pin both toolchains ([bffeed09](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/bffeed09b5eaa8fb8c795f68352ba1b68d6d3307))
- Rewrite input and output descriptions as single-line prose so they render on the Terraform Registry ([ecece3a3](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/ecece3a33312ffb0aacf538186b9f4913413de33))
## [3.0.0](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v3.0.0) - 2026-11-01


### 📝 Other

- Send every password write-only, group instance inputs into objects, add a public endpoint and trim outputs ([102b502d](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/102b502df503ac956d36be081098838e8350d4d9))
## [2.0.0](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v2.0.0) - 2026-10-31


### 📝 Other

- Add clone_from and manual backup expiry, raise the Scaleway provider floor to 2.89 ([2c1923ee](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/2c1923ee87f45814c7b13f4476818d79fe438d26))
## [1.2.2](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.2.2) - 2026-10-28


### 📝 Other

- Fix project resolution, add ACL and backup size warnings, require a private network address mode ([9c1488e5](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/9c1488e5ef88ed4087b96a2f2eec6a771b9c6d74))
## [1.2.1](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.2.1) - 2026-10-28


### 📝 Other

- Key the pre-commit cache on mise.toml and .pre-commit-config.yaml ([4c9b99b8](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/4c9b99b89d4d30e26d3658cc682311ecef08b5aa))
- Install mise 2026.10.17 in CI to avoid the GitHub API rate limit ([e2943ee2](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/e2943ee2710ab79b303f1ead32eeec34f5545321))
- Run validate:specs in merge request pipelines ([218b8680](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/218b86800887c36290c7878fadf91cb84f4467b6))
- Adopt OpenSpec and publish the baseline specs ([7421d239](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/7421d2394be737c0c9bede6d00693b419e510891))
## [1.2.0](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.2.0) - 2026-10-14


### 🚀 Features

- Add write-only admin and user passwords, upgrade scaleway provider to ~> 2.86 ([d8966a32](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/d8966a32276d318563539443e2d0d5165c3fe94e))
## [1.1.2](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.1.2) - 2025-12-25


### 📝 Other

- Creates CHANGELOG.md ([47a17ff4](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/47a17ff46eb54989cf547f177984bec35131f29f))
- Configures git-cliff for changelog generation ([6877efcc](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/6877efccc78607cd38ea3b5a62a02d6b48ba99f8))
- Updates release job definition ([e01cfc3e](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/e01cfc3e8cdc56dfa2f5b90db71427e9ad47cd40))
- Adds changelog verification to release process ([4df72a5a](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/4df72a5a4d0157f045175f5186cb2b4daef870d4))
## [1.1.1](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.1.1) - 2025-12-25


### 📝 Other

- Sets up CI/CD with changelog generation ([e5bac117](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/e5bac117774007b8c4f609078b863461d02cb6fb))
## [1.1.0](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.1.0) - 2025-12-25


### 👷 CI/CD

- Downgrade OSV scanner action to v1 ([4111f70c](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/4111f70c1ca0ed2b012bc2b5070a06736332248f))


### 📝 Other

- Adds OSV scanner to CI workflow ([26d2b2e9](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/26d2b2e9d86f49eb042098c7b1e493c7b09d4ba7))
- Simplifies CI and release workflows with actions ([467244b1](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/467244b18cb448ffc4d07de572c1b93c3da8d545))
- Removes trailing whitespace in pre-commit config ([63abfd25](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/63abfd25b98c18261750c1b6a80f9a6b7dfa4cbd))
- Sets up CI/CD pipelines with git-cliff integration ([1fceb03d](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/1fceb03deccfb7876709bf7f6a1e6ffa606eeb14))
## [1.0.0](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v1.0.0) - 2025-12-24


### 📝 Other

- Enables git-cliff and adds engine outputs ([c5bb8b21](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/c5bb8b213b441c648e64771d415c0c42427e7ec7))
- Fix pre-commit terraform hooks with mise PATH ([2a40d02b](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/2a40d02bd1e755048a30f241ac505b7ef8539b5d))
- Removes git-cliff pre-commit hook ([109d2dd7](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/109d2dd79d7578fcd2746b51c794b5a93e57cf82))
- Pre-commit ([4e2afe92](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/4e2afe929033f814695384146e13ec67f1d04403))
- Main preparation ([368aa54f](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/368aa54fbe0a29dade392d63559a4d5d2c12384f))
- Removes deprecated `bssd` volume type ([93caea97](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/93caea974f45f50227324e07848519bd0c2472c5))
- Adds Scaleway RDB Terraform module ([43c6fdab](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/43c6fdab5d473579b9cc18bdd9d6dac45abe8644))
- WIP Initializes Scaleway RDB Terraform module ([8029c8d2](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/8029c8d2e07acd5733943002ac7c67e1267a548e))
- Main preparation ([ecb9241e](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/ecb9241e70ab25744ea6b46ebd297b31098a6562))
## [0.0.1](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/releases/v0.0.1) - 2025-05-20


### 🐛 Bug Fixes

- Fix output ([7b8363df](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/7b8363df910d1f85809764ba95fcbb311422f751))


### 📝 Other

- Wip ([c1147ef4](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/c1147ef449b21f4f66eb6889f48cae19c86b718c))
- Wip ([72b70140](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/72b7014031f03fe231453222d83885979ee7851e))
- Wip ([f22a5b08](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/f22a5b0899569980ba7f573d6b204384a45bd549))
- Wip ([1218ed2f](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/1218ed2f111b396ec617204a7ded30e06b3f7807))
- Add output.tf ([f216f8b8](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/f216f8b83d1f87fd09a47f622d16cc001ce3da8b))
- Wip ([53ab9429](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/53ab942936cee9c8678a7ae2ae1b5c5a959eee07))
- First commit ([ea87b363](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/ea87b3634f3d2a64f4ec5f0004c9afa862539f9f))
- Initial commit ([60f85589](https://gitlab.com/leminnov/terraform/modules/scaleway-rdb/-/commit/60f855892f69fd4479de6a8602261a2539523688))
