# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.0.0] - 2026-10-20

First release as `freepenguins-curator`, forked from
[cristifalcas/puppet-curator](https://github.com/cristifalcas/puppet-curator)
3.5.0. See "Upgrading from cristifalcas-curator 3.x" in the README.

### Added
- Puppet 7 and 8 support, on Debian 12/13 and Ubuntu 22.04/24.04.
- Curator 8 (Elasticsearch 7.14 to 8.x) and Curator 9 (Elasticsearch 9)
  support. 8.0.21 is the default.
- Installation from PyPI into a Python virtualenv (`install_dir`), with
  the Curator wheel checked against a SHA-256 checksum (`checksum`,
  `wheel_checksums`). `package_source` and `pip_options` for mirrors,
  proxies and local wheels.
- Connection settings named after Curator's own: `cloud_id`, `ca_certs`,
  `verify_certs`, `request_timeout`, `username`/`password`, `api_key_id`/
  `api_key` and `api_key_token`, plus `settings` for anything else.
- `on_calendar` and `timer_overrides`: run Curator from a systemd timer.
- `actions`: declare `curator::action` resources from Hiera.
- `ensure => absent`, `config_dir`, `manage_config_dir`, `python` and
  `manage_python`.
- All 17 Curator 8/9 actions in `curator::action`, which now takes
  Curator's `options`, `filters`, `add` and `remove`.
- Unit tests for every supported OS.

### Changed
- Converted to PDK 3.4.0 with pdk-templates 3.8.0.
- `curator.yml` uses Curator 8/9's layout (`elasticsearch.client`,
  `elasticsearch.other_settings`, `logging`) and is written with
  `stdlib::to_yaml`; `hosts` are URLs.
- `curator.yml` and the actions file are root-only (0600, in a 0700
  directory), and `curator.yml` is kept out of reports when it holds a
  password or API key.
- `curator::action` writes YAML instead of filling in an ERB template, so
  booleans and numbers keep their types and strings are quoted when they
  need to be. `order` is required and must be unique, actions on indices
  or snapshots need a filter, and alias actions are checked.
- `logfile` defaults to none (standard output), and `blacklist` to
  `['elastic_transport', 'urllib3']`.
- Dependencies: puppetlabs/stdlib 9–10, puppetlabs/concat 9–10 and
  puppet/systemd 7–10; puppetlabs/apt is no longer needed.

### Fixed
- Every `curator::action` defaulted to order 1, so they all used the same
  key in the actions file and only the last one took effect.
- The `allocation_type` failure messages in `curator::action` printed the
  value instead of the parameter's name.
- `curator.yml`, which can hold a password, was world-readable (0644).

### Removed
- Puppet versions before 7, and RedHat/CentOS 6–7, Ubuntu 12.04/14.04 and
  Debian 8.
- Curator 4 and 5, and the parameters for Elastic's package repository
  (`package_name`, `package_provider`, `manage_repo`, `repo_version`) and
  `curator::repo`: Elastic no longer publishes Curator packages.
- `port`, `use_ssl`, `url_prefix`, `certificate`, `ssl_no_validate`,
  `http_auth`, `timeout` and the AWS settings, replaced by or removed
  with Curator 8's configuration.
- The flat `curator::action` parameters, now keys of `options`.
- Travis CI and the Beaker acceptance tests.

## 3.0.0 to 3.5.0

Released by Cristian Falcas as `cristifalcas-curator` without changelog
entries; see the git history.

## [2.3.1] - 2016-02-14
### Fixed
- Fixed issue with strict variables.

## [2.3.0] - 2016-02-14
### Added
- Support SSL certificate path and expose auth parameters at a global
  level (Greg Swift).

## [2.2.0] - 2016-01-13
### Changed
- Rename evenup-curator to jlambert121-curator.
### Added
- Support for curator jobs in hiera (Petter Abrahamsson).
- apt/yum repo management and additional ES connection params (Petter
  Abrahamsson).
- use_ssl and http_auth arguments (Dan Sajner).

## [2.1.2] - 2015-08-28
### Fixed
- Fixed remove parameter in alias (zyronix).
- Send cron stdout to /dev/null (mjs510).

## [2.1.1] - 2015-06-25
### Fixed
- Correct inline_templates.
- Correct timestring (SteveDevOps).

## [2.1.0] - 2015-06-16
### Fixed
- Correct logfile parameter location (SteveDevOps).
### Added
- Support repository flag on delete.

## [2.0.1] - 2015-03-25
### Fixed
- Correct some command strings.
- Ensure timestring is included.

## [2.0.0] - 2015-03-24
### Changed
- Updated for curator >= 3.0.0.
- Reworked job defined type - no longer supports multiple jobs.
### Added
- Acceptance tests.

## [1.1.0] - 2014-11-19
### Added
- Support for --timestring parameter (bflad).
- snapshot_recent, snapshot_delete_order (phononet).
- Support for multiple commands, master-only (bodgit).
### Removed
- Single letter args support, removed in curator 2.0.2 (phononet).
- Separator option, removed in curator 1.2.0 (dspangen).

## [1.0.1] - 2014-07-03
### Fixed
- Fix ordering for command options.

## [1.0.0] - 2014-07-03
### Changed
- Update for curator >= 1.1.0.

## [0.0.1] - 2014-06-06
- Initial release.
