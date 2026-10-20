# @summary Writes curator.yml and starts the actions file.
#
# @api private
class curator::config {
  assert_private()

  if $curator::ensure == 'present' {
    if $curator::manage_config_dir {
      file { $curator::config_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0700',
      }
    }

    $password = $curator::password ? {
      Sensitive => $curator::password.unwrap,
      default   => $curator::password,
    }
    $api_key = $curator::api_key ? {
      Sensitive => $curator::api_key.unwrap,
      default   => $curator::api_key,
    }
    $api_key_token = $curator::api_key_token ? {
      Sensitive => $curator::api_key_token.unwrap,
      default   => $curator::api_key_token,
    }

    $client = {
      'hosts'           => $curator::cloud_id ? {
        undef   => [$curator::hosts].flatten,
        default => undef,
      },
      'cloud_id'        => $curator::cloud_id,
      'ca_certs'        => $curator::ca_certs,
      'client_cert'     => $curator::client_cert,
      'client_key'      => $curator::client_key,
      'verify_certs'    => $curator::verify_certs,
      'request_timeout' => $curator::request_timeout,
    }.filter |$key, $value| { $value =~ NotUndef }

    $api_key_settings = {
      'id'      => $curator::api_key_id,
      'api_key' => $api_key,
      'token'   => $api_key_token,
    }.filter |$key, $value| { $value =~ NotUndef }

    $other_settings = {
      'master_only' => $curator::master_only,
      'username'    => $curator::username,
      'password'    => $password,
      'api_key'     => $api_key_settings.empty ? {
        true    => undef,
        default => $api_key_settings,
      },
    }.filter |$key, $value| { $value =~ NotUndef }

    $logging = {
      'loglevel'  => $curator::log_level,
      'logfile'   => $curator::logfile,
      'logformat' => $curator::logformat,
      'blacklist' => $curator::blacklist,
    }.filter |$key, $value| { $value =~ NotUndef }

    $config = deep_merge(
      {
        'elasticsearch' => {
          'client'         => $client,
          'other_settings' => $other_settings,
        },
        'logging'       => $logging,
      },
      $curator::settings,
    )

    $yaml = stdlib::to_yaml($config)
    $content = "# This file is managed by Puppet.\n${yaml}"
    # Keep the file out of reports and diffs when it holds a secret.
    $has_secrets = [$password, $api_key, $api_key_token].any |$value| { $value =~ NotUndef }
    $file_content = $has_secrets ? {
      true    => Sensitive($content),
      default => $content,
    }

    file { $curator::config_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => $file_content,
    }

    concat { $curator::actions_file:
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0600',
      order  => 'numeric',
    }

    concat::fragment { 'curator actions header':
      target  => $curator::actions_file,
      content => "---\n# This file is managed by Puppet.\nactions:\n",
      order   => 0,
    }
  } else {
    file { $curator::config_file:
      ensure => absent,
    }

    concat { $curator::actions_file:
      ensure => absent,
    }
  }
}
