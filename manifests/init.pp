# @summary Installs Elasticsearch Curator and manages its configuration, actions and schedule.
#
# Curator is installed from PyPI into a Python virtualenv in `install_dir`.
# The Curator wheel is checked against a SHA-256 checksum; its dependencies
# come from the package index at the versions es-client pins.
#
# The module writes Curator's client configuration (`curator.yml`) and an
# actions file built from `curator::action` resources, and can run Curator
# on a schedule with a systemd timer.
#
# Curator 8.0.21, the default, works with Elasticsearch 7.14 to 8.x. Curator
# 9 works only with Elasticsearch 9: set `version` to `9.0.0` for those
# clusters.
#
# @example Delete Logstash indices older than 30 days every night
#   class { 'curator':
#     hosts       => ['https://es1.example.com:9200', 'https://es2.example.com:9200'],
#     username    => 'curator',
#     password    => Sensitive('change-me'),
#     ca_certs    => '/etc/ssl/certs/es-ca.pem',
#     on_calendar => '*-*-* 01:30:00',
#     actions     => {
#       'delete old logstash indices' => {
#         'action'  => 'delete_indices',
#         'order'   => 1,
#         'options' => { 'ignore_empty_list' => true },
#         'filters' => [
#           { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
#           { 'filtertype' => 'age', 'source' => 'name', 'direction' => 'older',
#             'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 30 },
#         ],
#       },
#     },
#   }
#
# @example Curator 9 for an Elasticsearch 9 cluster, with an API key
#   class { 'curator':
#     version       => '9.0.0',
#     hosts         => ['https://es.example.com:9200'],
#     api_key_token => Sensitive('base64-encoded-id-and-key'),
#   }
#
# @example Installing only, with the configuration managed elsewhere
#   class { 'curator':
#     install_only => true,
#   }
#
# @param version
#   The Curator release to install from PyPI, such as `8.0.21` or `9.0.0`.
# @param wheel_checksums
#   SHA-256 checksums of Curator's wheels, keyed by release. The module's data
#   has 8.0.21 and 9.0.0; add others in Hiera (the hashes are merged) or set
#   `checksum`.
# @param python_packages
#   OS packages that provide `python` with the `venv` module. Defaults to
#   `python3-venv` on Debian and Ubuntu.
# @param ensure
#   `absent` removes the timer, the configuration and actions files and the
#   virtualenv. The configuration directory and `python_packages` are left
#   in place.
# @param checksum
#   SHA-256 of the Curator wheel. Defaults to the entry for `version` in
#   `wheel_checksums`; required for releases not listed there.
# @param package_source
#   Where to get the Curator wheel: a URL, or the absolute path of a local
#   file. Defaults to the wheel for `version` on files.pythonhosted.org.
# @param pip_options
#   Extra options for `pip install`, such as
#   `['--index-url', 'https://pypi.example.com/simple']` for a mirror or
#   `['--proxy', 'http://proxy.example.com:3128']`.
# @param install_dir
#   The virtualenv Curator is installed into. `curator` is
#   `<install_dir>/bin/curator`.
# @param python
#   The Python interpreter that creates the virtualenv. Curator 8 needs
#   Python 3.8 or later, Curator 9 Python 3.10 or later.
# @param manage_python
#   Whether to install `python_packages`.
# @param install_only
#   Only install Curator; leave `curator.yml` and the actions file alone.
#   `curator::action` can't be used then.
# @param config_dir
#   Directory for `curator.yml` and the actions file, created root-only
#   (0700). `/root/.curator` is where Curator looks for `curator.yml` when
#   root runs it without `--config`.
# @param manage_config_dir
#   Whether to create `config_dir`.
# @param config_file
#   Path of Curator's client configuration file.
# @param actions_file
#   Path of the actions file.
# @param hosts
#   Elasticsearch URLs, in `http[s]://host:port` form, all in one cluster.
#   Not written when `cloud_id` is set.
# @param cloud_id
#   Elastic Cloud deployment ID, used instead of `hosts`.
# @param ca_certs
#   CA certificate file to verify Elasticsearch's certificate with.
# @param client_cert
#   Client certificate file, for TLS client authentication.
# @param client_key
#   Key file for `client_cert`, if it isn't in the same file.
# @param verify_certs
#   Whether to verify Elasticsearch's certificate. Unset, Curator verifies it.
# @param request_timeout
#   Client request timeout in seconds. Unset, Curator's default applies.
# @param master_only
#   Only run Curator on the elected master node, for installing Curator on
#   every node of a cluster. `hosts` must then be the local node only.
# @param username
#   Elasticsearch user for basic authentication. Needs `password`.
# @param password
#   That user's password.
# @param api_key_id
#   API key ID. Needs `api_key`.
# @param api_key
#   API key secret for `api_key_id`.
# @param api_key_token
#   API key as a single base64-encoded token (`id:api_key`), instead of
#   `api_key_id` and `api_key`.
# @param log_level
#   Curator's log level (`loglevel` in curator.yml).
# @param logfile
#   File to log to. Unset, Curator logs to standard output, which goes to
#   the journal when the timer runs it.
# @param logformat
#   Log format.
# @param blacklist
#   Loggers whose messages are dropped.
# @param settings
#   Anything else for `curator.yml`, merged over what the parameters above
#   produce (yours win), for example
#   `{ 'elasticsearch' => { 'client' => { 'ssl_assert_fingerprint' => '...' } } }`.
# @param actions
#   `curator::action` resources to declare, keyed by title. Handy from Hiera.
# @param on_calendar
#   When to run Curator, as a systemd `OnCalendar` value such as `daily` or
#   `*-*-* 01:30:00`. Set, the module adds a `curator.timer` and
#   `curator.service`; unset, it removes them.
# @param timer_overrides
#   Extra `[Timer]` settings for `curator.timer`, such as
#   `{ 'RandomizedDelaySec' => '15m' }`.
class curator (
  # Defaults for these are in the module's Hiera data.
  Curator::Version                                   $version,
  Hash[Curator::Version, Curator::Sha256]            $wheel_checksums,
  Array[String[1]]                                   $python_packages,
  Enum['present', 'absent']                          $ensure            = 'present',
  Optional[Curator::Sha256]                          $checksum          = undef,
  Optional[Variant[Stdlib::HTTPUrl, Stdlib::Absolutepath]] $package_source = undef,
  Array[String[1]]                                   $pip_options       = [],
  Stdlib::Absolutepath                               $install_dir       = '/opt/curator',
  Stdlib::Absolutepath                               $python            = '/usr/bin/python3',
  Boolean                                            $manage_python     = true,
  Boolean                                            $install_only      = false,
  Stdlib::Absolutepath                               $config_dir        = '/root/.curator',
  Boolean                                            $manage_config_dir = true,
  Stdlib::Absolutepath                               $config_file       = "${config_dir}/curator.yml",
  Stdlib::Absolutepath                               $actions_file      = "${config_dir}/actions.yml",
  Variant[Stdlib::HTTPUrl, Array[Stdlib::HTTPUrl, 1]] $hosts            = ['http://127.0.0.1:9200'],
  Optional[String[1]]                                $cloud_id          = undef,
  Optional[Stdlib::Absolutepath]                     $ca_certs          = undef,
  Optional[Stdlib::Absolutepath]                     $client_cert       = undef,
  Optional[Stdlib::Absolutepath]                     $client_key        = undef,
  Optional[Boolean]                                  $verify_certs      = undef,
  Optional[Variant[Integer[1], Float]]               $request_timeout   = undef,
  Boolean                                            $master_only       = false,
  Optional[String[1]]                                $username          = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $password          = undef,
  Optional[String[1]]                                $api_key_id        = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $api_key           = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $api_key_token     = undef,
  Enum['NOTSET', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'] $log_level = 'INFO',
  Optional[Stdlib::Absolutepath]                     $logfile           = undef,
  Enum['default', 'json', 'ecs']                     $logformat         = 'default',
  Array[String[1]]                                   $blacklist         = ['elastic_transport', 'urllib3'],
  Hash[String[1], Data]                              $settings          = {},
  Hash[String[1], Hash]                              $actions           = {},
  Optional[Systemd::Unit::Timespan]                  $on_calendar       = undef,
  Systemd::Unit::Timer                               $timer_overrides   = {},
) {
  if ($username =~ Undef) != ($password =~ Undef) {
    fail('curator: set both username and password, or neither.')
  }
  if ($api_key_id =~ Undef) != ($api_key =~ Undef) {
    fail('curator: set both api_key_id and api_key, or neither.')
  }
  if $api_key_token =~ NotUndef and $api_key_id =~ NotUndef {
    fail('curator: set either api_key_token or api_key_id and api_key, not both.')
  }

  $_checksum = $checksum ? {
    undef   => $wheel_checksums[$version],
    default => $checksum,
  }
  if $ensure == 'present' and $_checksum =~ Undef {
    fail("curator: no checksum is known for Curator ${version}; set curator::checksum to the SHA-256 of its wheel.")
  }

  $_package_source = $package_source ? {
    undef                => "https://files.pythonhosted.org/packages/py3/e/elasticsearch-curator/elasticsearch_curator-${version}-py3-none-any.whl",
    Stdlib::Absolutepath => "file://${package_source}",
    default              => $package_source,
  }

  contain curator::install
  unless $install_only {
    contain curator::config
  }
  contain curator::service

  $actions.each |String[1] $action_title, Hash $params| {
    curator::action { $action_title:
      * => $params,
    }
  }

  if $ensure == 'present' {
    Class['curator::install'] -> Class['curator::service']
    unless $install_only {
      Class['curator::install'] -> Class['curator::config'] -> Class['curator::service']
    }
  } else {
    Class['curator::service'] -> Class['curator::install']
    unless $install_only {
      Class['curator::service'] -> Class['curator::config'] -> Class['curator::install']
    }
  }
}
