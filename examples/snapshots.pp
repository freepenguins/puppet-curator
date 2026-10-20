# Nightly snapshots to an existing repository called "backups", keeping 90
# days of them. The repository itself is set up in Elasticsearch.
class { 'curator':
  hosts           => ['https://es.example.com:9200'],
  api_key_token   => Sensitive('base64-encoded-id-and-key'),
  request_timeout => 300,
  on_calendar     => '*-*-* 02:00:00',
}

curator::action { 'nightly snapshot':
  action  => 'snapshot',
  order   => 1,
  options => {
    'repository'          => 'backups',
    'name'                => 'curator-%Y.%m.%d',
    'wait_for_completion' => true,
  },
  filters => [{ 'filtertype' => 'none' }],
}

curator::action { 'delete snapshots older than 90 days':
  action  => 'delete_snapshots',
  order   => 2,
  options => { 'repository' => 'backups', 'retry_interval' => 120, 'retry_count' => 3 },
  filters => [
    { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'curator-' },
    {
      'filtertype' => 'age',
      'source'     => 'creation_date',
      'direction'  => 'older',
      'unit'       => 'days',
      'unit_count' => 90,
    },
  ],
}
