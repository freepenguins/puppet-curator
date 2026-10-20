# Curator for an Elasticsearch 8 cluster, run every night by a systemd
# timer. It deletes Logstash indices after 30 days.
class { 'curator':
  hosts       => ['https://es1.example.com:9200', 'https://es2.example.com:9200'],
  ca_certs    => '/etc/ssl/certs/es-ca.pem',
  username    => 'curator',
  password    => Sensitive('change-me'),
  on_calendar => '*-*-* 01:30:00',
  actions     => {
    'delete old logstash indices' => {
      'action'  => 'delete_indices',
      'order'   => 1,
      'options' => { 'ignore_empty_list' => true },
      'filters' => [
        { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
        {
          'filtertype' => 'age',
          'source'     => 'name',
          'direction'  => 'older',
          'timestring' => '%Y.%m.%d',
          'unit'       => 'days',
          'unit_count' => 30,
        },
      ],
    },
  },
}
