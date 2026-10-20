# Keep the "logs-current" alias on the last seven days of daily indices.
class { 'curator':
  hosts       => ['http://127.0.0.1:9200'],
  on_calendar => 'hourly',
}

curator::action { 'logs-current alias':
  action  => 'alias',
  order   => 1,
  options => { 'name' => 'logs-current', 'warn_if_no_indices' => true },
  add     => {
    'filters' => [
      { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' },
      {
        'filtertype' => 'age',
        'source'     => 'name',
        'direction'  => 'younger',
        'timestring' => '%Y.%m.%d',
        'unit'       => 'days',
        'unit_count' => 7,
      },
    ],
  },
  remove  => {
    'filters' => [
      { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' },
      {
        'filtertype' => 'age',
        'source'     => 'name',
        'direction'  => 'older',
        'timestring' => '%Y.%m.%d',
        'unit'       => 'days',
        'unit_count' => 7,
      },
    ],
  },
}
