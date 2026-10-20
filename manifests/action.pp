# @summary Adds an action to Curator's actions file.
#
# Each action is written under its `order`, which Curator runs in ascending
# order, so every action needs its own. `options`, `filters`, `add` and
# `remove` are written as given, in Curator's own format; see
# https://www.elastic.co/guide/en/elasticsearch/client/curator/current/actionfile.html.
#
# Actions that work on a list of indices or snapshots need at least one
# filter. To act on all of them, say so with `[{ 'filtertype' => 'none' }]`.
#
# @example Delete Logstash indices older than 30 days
#   curator::action { 'delete old logstash indices':
#     action  => 'delete_indices',
#     order   => 1,
#     options => { 'ignore_empty_list' => true },
#     filters => [
#       { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
#       { 'filtertype' => 'age', 'source' => 'name', 'direction' => 'older',
#         'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 30 },
#     ],
#   }
#
# @example Point an alias at this week's indices
#   curator::action { 'logs-current alias':
#     action  => 'alias',
#     order   => 2,
#     options => { 'name' => 'logs-current', 'warn_if_no_indices' => true },
#     add     => {
#       'filters' => [
#         { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' },
#         { 'filtertype' => 'period', 'period_type' => 'relative', 'source' => 'name',
#           'range_from' => 0, 'range_to' => 0, 'timestring' => '%Y.%m.%d', 'unit' => 'weeks' },
#       ],
#     },
#     remove  => {
#       'filters' => [
#         { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' },
#       ],
#     },
#   }
#
# @param order
#   The action's number in the actions file. Curator runs actions in
#   ascending order; no two actions may share one.
# @param action
#   The Curator action, such as `delete_indices` or `snapshot`. Defaults to
#   the title.
# @param description
#   The action's description, which Curator logs.
# @param options
#   The action's options, such as `{ 'repository' => 'backups' }` for
#   `snapshot`.
# @param filters
#   The filters that pick the indices or snapshots to act on. Not used by
#   `alias`, `cluster_routing`, `create_index` and `rollover`.
# @param add
#   `alias` only: filters for the indices to add to the alias, as
#   `{ 'filters' => [...] }`.
# @param remove
#   `alias` only: filters for the indices to remove from the alias, as
#   `{ 'filters' => [...] }`.
define curator::action (
  Integer[1]                      $order,
  Curator::ActionName             $action      = $title,
  String[1]                       $description = $title,
  Hash[String[1], Data]           $options     = {},
  Array[Hash[String[1], Data]]    $filters     = [],
  Optional[Hash[String[1], Data]] $add         = undef,
  Optional[Hash[String[1], Data]] $remove      = undef,
) {
  include curator

  if $curator::install_only {
    fail("curator::action[${title}]: the module doesn't manage the actions file with install_only => true.")
  }

  case $action {
    'alias': {
      unless $filters.empty {
        fail("curator::action[${title}]: alias takes its filters in add and remove, not in filters.")
      }
      if $add =~ Undef and $remove =~ Undef {
        fail("curator::action[${title}]: alias needs add, remove or both.")
      }
      unless 'name' in $options {
        fail("curator::action[${title}]: alias needs the alias's name in options['name'].")
      }
    }
    'cluster_routing', 'create_index', 'rollover': {
      unless $filters.empty {
        fail("curator::action[${title}]: ${action} doesn't take filters.")
      }
    }
    default: {
      if $filters.empty {
        fail("curator::action[${title}]: ${action} needs at least one filter; use [{ 'filtertype' => 'none' }] to act on everything.")
      }
    }
  }

  if $action != 'alias' and ($add =~ NotUndef or $remove =~ NotUndef) {
    fail("curator::action[${title}]: add and remove are only for alias.")
  }

  $fragment = "curator action ${order}"
  if defined(Concat::Fragment[$fragment]) {
    fail("curator::action[${title}]: order ${order} is already used by another curator::action.")
  }

  if $curator::ensure == 'present' {
    $body = {
      'action'      => $action,
      'description' => $description,
      'options'     => $options.empty ? {
        true    => undef,
        default => $options,
      },
      'filters'     => $filters.empty ? {
        true    => undef,
        default => $filters,
      },
      'add'         => $add,
      'remove'      => $remove,
    }.filter |$key, $value| { $value =~ NotUndef }

    # The action as YAML under its number, indented to sit under the
    # file's "actions:" key.
    $yaml = stdlib::to_yaml({ $order => $body }).regsubst(/\A---\n/, '')

    concat::fragment { $fragment:
      target  => $curator::actions_file,
      content => $yaml.regsubst(/^/, '  ', 'G'),
      order   => $order,
    }
  }
}
