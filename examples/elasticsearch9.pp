# Curator 9 for an Elasticsearch 9 cluster on Elastic Cloud, installed
# through a PyPI mirror.
class { 'curator':
  version     => '9.0.0',
  cloud_id    => 'my-deployment:ZXUtd2VzdC0xLmF3cy5mb3VuZC5pbyRhYmMkZGVm',
  api_key_id  => 'curator-key-id',
  api_key     => Sensitive('curator-key-secret'),
  pip_options => ['--index-url', 'https://pypi.example.com/simple'],
}
