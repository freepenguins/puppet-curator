# @summary The actions Curator 8 and 9 can run from an actions file.
#
# @see https://www.elastic.co/guide/en/elasticsearch/client/curator/current/actions.html
type Curator::ActionName = Enum[
  'alias',
  'allocation',
  'close',
  'cluster_routing',
  'cold2frozen',
  'create_index',
  'delete_indices',
  'delete_snapshots',
  'forcemerge',
  'index_settings',
  'open',
  'reindex',
  'replicas',
  'restore',
  'rollover',
  'shrink',
  'snapshot',
]
