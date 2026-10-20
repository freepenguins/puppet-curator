# Index retention: delete daily indices by age, close them a week before,
# and don't fail when there is nothing to do. Curator runs the actions in
# order.
class { 'curator':
  hosts       => ['http://127.0.0.1:9200'],
  on_calendar => 'daily',
}

curator::action { 'close indices older than 23 days':
  action  => 'close',
  order   => 1,
  options => { 'ignore_empty_list' => true, 'delete_aliases' => false },
  filters => [
    { 'filtertype' => 'pattern', 'kind' => 'regex', 'value' => '^(logstash|filebeat)-' },
    {
      'filtertype' => 'age',
      'source'     => 'name',
      'direction'  => 'older',
      'timestring' => '%Y.%m.%d',
      'unit'       => 'days',
      'unit_count' => 23,
    },
  ],
}

curator::action { 'delete indices older than 30 days':
  action  => 'delete_indices',
  order   => 2,
  options => { 'ignore_empty_list' => true },
  filters => [
    { 'filtertype' => 'pattern', 'kind' => 'regex', 'value' => '^(logstash|filebeat)-' },
    {
      'filtertype' => 'age',
      'source'     => 'name',
      'direction'  => 'older',
      'timestring' => '%Y.%m.%d',
      'unit'       => 'days',
      'unit_count' => 30,
    },
  ],
}
