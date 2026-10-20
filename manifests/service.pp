# @summary Runs Curator on a schedule with a systemd timer.
#
# @api private
class curator::service {
  assert_private()

  # Without on_calendar the timer and service are removed, so turning the
  # schedule off cleans up after an earlier run.
  $timer_ensure = ($curator::ensure == 'present' and $curator::on_calendar =~ NotUndef) ? {
    true    => 'present',
    default => 'absent',
  }

  systemd::timer_wrapper { 'curator':
    ensure                 => $timer_ensure,
    command                => "${curator::install_dir}/bin/curator --config ${curator::config_file} ${curator::actions_file}",
    on_calendar            => $curator::on_calendar,
    service_unit_overrides => {
      'Description'   => 'Elasticsearch Curator',
      'Documentation' => 'https://www.elastic.co/guide/en/elasticsearch/client/curator/current/index.html',
      'Wants'         => 'network-online.target',
      'After'         => 'network-online.target',
    },
    service_overrides      => {
      'NoNewPrivileges' => true,
      'PrivateTmp'      => true,
      'ProtectSystem'   => 'full',
    },
    timer_unit_overrides   => {
      'Description' => 'Run Elasticsearch Curator',
    },
    # Persistent: catch up on a run missed while the host was down.
    timer_overrides        => { 'Persistent' => true } + $curator::timer_overrides,
  }
}
