# curator

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with curator](#setup)
    * [What curator affects](#what-curator-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with curator](#beginning-with-curator)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Upgrading from cristifalcas-curator 3.x](#upgrading-from-cristifalcas-curator-3x)
1. [Development - Guide for contributing to the module](#development)

## Description

This module installs [Elasticsearch Curator](https://github.com/elastic/curator)
from PyPI into a Python virtualenv, writes its client configuration and
actions file, and can run it on a schedule with a systemd timer.

Pick the Curator release that matches your cluster:

| Elasticsearch | Curator | `version` |
|---|---|---|
| 7.14 to 8.x | 8.0.21 | `8.0.21` (the default) |
| 9.x | 9.0.0 | `9.0.0` |

Curator checks the cluster's version when it connects and refuses to work
with any other.

It is a fork of [cristifalcas/puppet-curator](https://github.com/cristifalcas/puppet-curator)
(`cristifalcas-curator` 3.5.0 on the Forge), updated for Puppet 7 and 8,
Curator 8 and 9 and the PDK. See [Upgrading](#upgrading-from-cristifalcas-curator-3x)
for what changed.

## Setup

### What curator affects

* The `python3-venv` package, for creating the virtualenv (`manage_python`).
* A virtualenv in `/opt/curator` (`install_dir`) with Curator and its Python
  dependencies, so the command is `/opt/curator/bin/curator`.
* `/root/.curator` (0700), with `curator.yml` and `actions.yml` (both root:root
  0600). `/root/.curator/curator.yml` is where Curator looks when root runs
  it without `--config`.
* With `on_calendar`: `/etc/systemd/system/curator.service` and
  `curator.timer`, with the timer enabled and started. This uses
  puppet/systemd, which includes its `systemd` class; with that class's
  defaults it also keeps `systemd-journald` running.

### Setup requirements

* Puppet 7 or 8, with puppetlabs/stdlib 9 or later, puppetlabs/concat 9 or
  later and puppet/systemd 7 or later.
* HTTPS access from each node to `files.pythonhosted.org` and `pypi.org`, or
  a mirror (see [Installing from a mirror](#installing-from-a-mirror-or-a-local-wheel)).
* Python 3.10 or later for Curator 9 (3.8 for Curator 8). Every supported
  OS ships 3.10 or later. On Ubuntu, `python3-venv` is in the universe
  component.

### Beginning with curator

```puppet
class { 'curator':
  hosts       => ['https://es.example.com:9200'],
  username    => 'curator',
  password    => Sensitive('change-me'),
  on_calendar => 'daily',
}

curator::action { 'delete old logstash indices':
  action  => 'delete_indices',
  order   => 1,
  options => { 'ignore_empty_list' => true },
  filters => [
    { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
    { 'filtertype' => 'age', 'source' => 'name', 'direction' => 'older',
      'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 30 },
  ],
}
```

This installs Curator 8.0.21, connects to `es.example.com` as `curator`, and
deletes Logstash indices older than 30 days once a day.

To try the actions without changing anything:

```
/opt/curator/bin/curator --dry-run /root/.curator/actions.yml
```

## Usage

### Connecting to Elasticsearch

`hosts` takes one or more URLs in `http[s]://host:port` form, all in the same
cluster. The connection parameters are named after the keys in Curator's
[configuration file](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/configfile.html):

```puppet
class { 'curator':
  hosts           => ['https://es1.example.com:9200', 'https://es2.example.com:9200'],
  ca_certs        => '/etc/ssl/certs/es-ca.pem',
  client_cert     => '/etc/ssl/certs/curator.pem',
  client_key      => '/etc/ssl/private/curator.key',
  request_timeout => 120,
  username        => 'curator',
  password        => Sensitive('change-me'),
}
```

* For an API key, set `api_key_id` and `api_key`, or `api_key_token` (the
  base64 `id:api_key` form Kibana shows as "Encoded").
* For Elastic Cloud, set `cloud_id`; `hosts` is then left out.
* `verify_certs => false` turns off certificate checks.
* `master_only => true` makes Curator do nothing unless it runs on the elected
  master, for installing it on every node; `hosts` must then be the local
  node.

When `curator.yml` holds a password or API key, Puppet treats its content as
sensitive and keeps it out of reports and diffs. `Sensitive` values are
unwrapped only to write the file.

### Actions

Each `curator::action` is one entry in the actions file. Its `options`,
`filters`, `add` and `remove` are written as given, in Curator's own format
(see [the actions file](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/actionfile.html)
and [filters](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/filters.html)):

```puppet
curator::action { 'nightly snapshot':
  action  => 'snapshot',
  order   => 1,
  options => { 'repository' => 'backups', 'name' => 'curator-%Y.%m.%d', 'wait_for_completion' => true },
  filters => [{ 'filtertype' => 'none' }],
}

curator::action { 'delete snapshots older than 90 days':
  action  => 'delete_snapshots',
  order   => 2,
  options => { 'repository' => 'backups' },
  filters => [
    { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'curator-' },
    { 'filtertype' => 'age', 'source' => 'creation_date', 'direction' => 'older',
      'unit' => 'days', 'unit_count' => 90 },
  ],
}
```

* Curator runs actions in ascending `order`. Every action needs its own;
  a duplicate fails the catalog.
* `action` defaults to the title, so `curator::action { 'snapshot': ... }`
  works too.
* Actions on indices or snapshots need at least one filter. To act on all of
  them, say so with `[{ 'filtertype' => 'none' }]`.
* `alias` takes its filters in `add` and `remove` (`{ 'filters' => [...] }`)
  and the alias's name in `options['name']`. `cluster_routing`,
  `create_index` and `rollover` take no filters.
* Write values as plain Puppet values: `true`, `30`, `'%Y.%m.%d'`. The module
  writes YAML and quotes what needs quoting.

The same from Hiera, with the password from eyaml:

```yaml
curator::hosts:
  - https://es.example.com:9200
curator::username: curator
curator::password: "%{lookup('creds::curator::password')}"
curator::on_calendar: '*-*-* 01:30:00'
curator::actions:
  delete old logstash indices:
    action: delete_indices
    order: 1
    options:
      ignore_empty_list: true
    filters:
      - filtertype: pattern
        kind: prefix
        value: logstash-
      - filtertype: age
        source: name
        direction: older
        timestring: '%Y.%m.%d'
        unit: days
        unit_count: 30
```

The [examples](examples/) have more: index retention, snapshots, aliases and
Elastic Cloud.

### Running on a schedule

`on_calendar` takes a systemd
[calendar event](https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events),
such as `daily`, `hourly` or `*-*-* 01:30:00`. The module then adds
`curator.service`, which runs

```
/opt/curator/bin/curator --config /root/.curator/curator.yml /root/.curator/actions.yml
```

once as root, and `curator.timer`, which starts it. The timer is
`Persistent`, so a run missed while the host was down happens at the next
boot. Add other `[Timer]` settings with `timer_overrides`, for example
`{ 'RandomizedDelaySec' => '15m' }`. Curator's output goes to the journal
(`journalctl -u curator`) unless you set `logfile`.

Unset `on_calendar` and the timer and service are removed.

### Curator 9 and Elasticsearch 9

```puppet
class { 'curator':
  version => '9.0.0',
  hosts   => ['https://es.example.com:9200'],
}
```

Changing `version` upgrades or downgrades Curator in place with pip.

### Installing from a mirror or a local wheel

`pip_options` is passed to `pip install`, for a PyPI mirror or a proxy:

```puppet
class { 'curator':
  pip_options => ['--index-url', 'https://pypi.example.com/simple'],
}
```

`package_source` replaces the Curator wheel's URL, or points at a local file.
Either way the wheel is checked against `checksum`, which defaults to the
module's checksum for `version`:

```puppet
class { 'curator':
  package_source => '/srv/wheels/elasticsearch_curator-8.0.21-py3-none-any.whl',
}
```

The module knows the checksums of 8.0.21 and 9.0.0. For other releases set
`checksum` to the SHA-256 of `elasticsearch_curator-<version>-py3-none-any.whl`
(PyPI shows it on the release's "Download files" page), or add them to
`curator::wheel_checksums` in Hiera.

### Other settings

`settings` is merged over the configuration the parameters produce, for any
of Curator's other client settings:

```puppet
class { 'curator':
  settings => {
    'elasticsearch' => {
      'client'         => { 'ssl_assert_fingerprint' => 'AB:CD:...', 'http_compress' => true },
      'other_settings' => { 'skip_version_test' => true },
    },
  },
}
```

### Managing the configuration yourself

`install_only => true` installs Curator and leaves `curator.yml` and the
actions file alone. `curator::action` can't be used then. `on_calendar`
still works, and runs `config_file` with `actions_file`.

### Removing Curator

`ensure => absent` stops and removes the timer, then removes the
configuration and actions files and the virtualenv. It leaves the
configuration directory and `python3-venv`.

## Reference

See [REFERENCE.md](REFERENCE.md).

## Limitations

* Supported on Debian 12 and 13 and Ubuntu 22.04 and 24.04, with Puppet 7
  or 8.
* Curator 8 works with Elasticsearch 7.14 to 8.x and Curator 9 with
  Elasticsearch 9 only. Curator's own documentation suggests index
  lifecycle management (ILM) in its place where ILM does what you need.
* The Curator wheel is checked against its SHA-256. Its dependencies come
  from the package index: es-client pins most of them to exact versions,
  but not their checksums.
* One Curator per host: one configuration file, one actions file and one
  timer. Curator runs as root.
* Curator fails if the actions file has no actions, so declare at least
  one before turning the timer on.
* A virtualenv is tied to the Python it was created with. If an OS upgrade
  changes the Python version, remove `install_dir` and let Puppet create it
  again.

## Upgrading from cristifalcas-curator 3.x

The old module installed Curator 4 or 5 from Elastic's package repository,
which no longer exists for current releases, and wrote a `curator.yml` that
Curator 8 rejects. Most parameters had to change. A resource-style
declaration that still passes an old parameter fails with an error naming
it, but old Hiera keys are simply ignored, so check your data.

**The class:**

| 3.x | 4.0.0 |
|---|---|
| `ensure` (a package version or `latest`) | `version` (an exact release) and `ensure` (`present` or `absent`) |
| `package_name`, `package_provider`, `manage_repo`, `repo_version` | Removed: Curator is installed with pip into a virtualenv |
| `hosts` (host names), `port`, `use_ssl` | `hosts` as URLs, such as `https://es.example.com:9200` |
| `url_prefix` | Removed: Curator 8 doesn't have it |
| `certificate` | `ca_certs` |
| `ssl_no_validate => 'True'` | `verify_certs => false` |
| `http_auth => 'user:pass'` | `username` and `password` |
| `timeout` | `request_timeout` |
| `master_only => 'True'` | `master_only => true` |
| `aws_key`, `aws_secret_key`, `aws_region` | Removed: Curator 8 doesn't sign requests for AWS |
| `log_level`, `logfile`, `logformat`, `blacklist` | Unchanged names. `logfile` now defaults to none (the journal, under the timer; it was `/var/log/curator.log`). `logformat => 'logstash'` is gone: use `json` or `ecs`. `blacklist` defaults to `['elastic_transport', 'urllib3']`. |
| `install_only`, `config_file`, `actions_file` | Unchanged, with the same default paths |

New: `config_dir`, `manage_config_dir`, `cloud_id`, API
keys, `settings`, `actions`, `on_calendar`, `timer_overrides`,
`pip_options`, `package_source`, `checksum`, `install_dir`, `python`,
`manage_python` and `ensure => absent`.

**curator::action:** the flat parameters (`continue_if_exception`, `count`,
`delay`, `option_name`, `post_allocation`, `node_filters` and so on) are now
keys of `options`, spelled as in Curator's documentation (`option_name`
becomes `options['name']`). `order` is required and must be unique: in 3.x
every action defaulted to 1, so only the last one ended up in the file.
Values are real booleans and numbers, and strings no longer need quotes
inside quotes:

```puppet
# 3.x
curator::action { 'delete_indices':
  continue_if_exception => 'True',
  filters               => [
    { 'filtertype' => 'age', 'timestring' => '"%Y.%m.%d"', 'unit' => 'days', 'unit_count' => '7', 'source' => 'name', 'direction' => 'older' },
  ],
}

# 4.0.0
curator::action { 'delete_indices':
  order   => 1,
  options => { 'continue_if_exception' => true },
  filters => [
    { 'filtertype' => 'age', 'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 7, 'source' => 'name', 'direction' => 'older' },
  ],
}
```

**On existing nodes:**

* Remove the old package (`apt-get remove elasticsearch-curator`, or
  `pip uninstall elasticsearch-curator` if it came from pip) and, if
  `manage_repo` was on, the APT source it added: `apt::source { 'curator':
  ensure => absent }` for one run, or delete
  `/etc/apt/sources.list.d/curator.list`.
* Replace any cron job that ran `/bin/curator` or `/usr/bin/curator` with
  `on_calendar`, or point it at `/opt/curator/bin/curator`.

## Development

This is a PDK module (pdk-templates 3.8.0). Run the checks with:

```
pdk validate
pdk test unit
```

The unit tests cover every supported OS on the Puppet version you run them
with; run them with `PUPPET_GEM_VERSION='~> 7'` and `'~> 8'` to cover both.

Originally written by [jlambert121](https://github.com/jlambert121) as
`jlambert121-curator` (earlier `evenup-curator`) and rewritten for Curator 4
by [Cristian Falcas](https://github.com/cristifalcas) as `cristifalcas-curator`,
with contributions from Petter Abrahamsson, Phil Fenstermacher, Richard
Pijnenburg, Miguel Gagliardo, Anna Guyen, Ardiea, Marco Cova and others in
the git history and [CHANGELOG](CHANGELOG.md). Licensed under Apache 2.0.
