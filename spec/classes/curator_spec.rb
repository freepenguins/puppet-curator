# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

describe 'curator' do
  wheel_8 = 'https://files.pythonhosted.org/packages/py3/e/elasticsearch-curator/elasticsearch_curator-8.0.21-py3-none-any.whl'
  sha_8 = '15dd1dc72a43f8b0b68e6a7b8ad4888103fa80e95c894603c6f676a1eaac54f4'
  sha_9 = '82b98d4b566d47ffbda19db3dbcdffb028ffd652bf51ed674eb726425a7d021b'
  config_file = '/root/.curator/curator.yml'
  actions_file = '/root/.curator/actions.yml'

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:config_content) do
        catalogue.resource('File', config_file)[:content]
      end
      let(:curator_yml) { YAML.safe_load(config_content) }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it 'installs python3-venv for the virtualenv' do
          is_expected.to contain_package('python3-venv').with_ensure('installed')
        end

        it 'creates the virtualenv' do
          is_expected.to contain_exec('curator-venv').with(
            command: '/usr/bin/python3 -m venv /opt/curator',
            creates: '/opt/curator/bin/pip',
          ).that_requires('Package[python3-venv]')
        end

        it 'installs Curator 8.0.21 from PyPI, checking the wheel\'s SHA-256' do
          is_expected.to contain_exec('curator-install').with(
            command: "/opt/curator/bin/pip install --disable-pip-version-check --no-input elasticsearch-curator\\ @\\ #{wheel_8}\\#sha256\\=#{sha_8}",
            provider: 'shell',
            timeout: 900,
          ).that_requires('Exec[curator-venv]')
        end

        it 'skips pip when that version is already installed' do
          is_expected.to contain_exec('curator-install').with_unless(%r{\Atest -x /opt/curator/bin/python && /opt/curator/bin/python -c .*importlib\.metadata.* 8\.0\.21\z})
        end

        it { is_expected.to contain_file('/root/.curator').with(ensure: 'directory', owner: 'root', group: 'root', mode: '0700') }

        it 'writes curator.yml readable by root only' do
          is_expected.to contain_file(config_file).with(ensure: 'file', owner: 'root', group: 'root', mode: '0600')
          expect(config_content).to start_with("# This file is managed by Puppet.\n---\n")
        end

        it 'writes the Curator 8 configuration layout' do
          expect(curator_yml).to eq(
            'elasticsearch' => {
              'client' => { 'hosts' => ['http://127.0.0.1:9200'] },
              'other_settings' => { 'master_only' => false },
            },
            'logging' => {
              'loglevel' => 'INFO',
              'logformat' => 'default',
              'blacklist' => ['elastic_transport', 'urllib3'],
            },
          )
        end

        it 'starts the actions file' do
          is_expected.to contain_concat(actions_file).with(ensure: 'present', owner: 'root', group: 'root', mode: '0600', order: 'numeric')
          is_expected.to contain_concat__fragment('curator actions header').with(
            target: actions_file,
            content: "---\n# This file is managed by Puppet.\nactions:\n",
            order: 0,
          )
        end

        it 'has no timer' do
          is_expected.to contain_systemd__timer_wrapper('curator').with_ensure('absent')
          is_expected.to contain_service('curator.timer').with(ensure: false, enable: false)
        end

        it 'installs, then configures, then schedules' do
          is_expected.to contain_class('curator::install').that_comes_before('Class[curator::config]')
          is_expected.to contain_class('curator::config').that_comes_before('Class[curator::service]')
        end
      end

      context 'with version => 9.0.0' do
        let(:params) { { version: '9.0.0' } }

        it 'uses the checksum from the module data' do
          is_expected.to contain_exec('curator-install')
            .with_command(%r{elasticsearch_curator-9\.0\.0-py3-none-any\.whl\\#sha256\\=#{sha_9}\z})
            .with_unless(%r{ 9\.0\.0\z})
        end
      end

      context 'with a version the module has no checksum for' do
        let(:params) { { version: '8.0.20' } }

        it { is_expected.to compile.and_raise_error(%r{no checksum is known for Curator 8\.0\.20; set curator::checksum}) }

        context 'and a checksum' do
          let(:params) { super().merge(checksum: 'a' * 64) }

          it { is_expected.to contain_exec('curator-install').with_command(%r{elasticsearch_curator-8\.0\.20-py3-none-any\.whl\\#sha256\\=a{64}\z}) }
        end
      end

      context 'with a local wheel, a mirror and another virtualenv' do
        let(:params) do
          {
            package_source: '/srv/wheels/elasticsearch_curator-8.0.21-py3-none-any.whl',
            pip_options: ['--index-url', 'https://pypi.example.com/simple'],
            install_dir: '/srv/curator',
            python: '/usr/bin/python3.12',
          }
        end

        it { is_expected.to contain_exec('curator-venv').with(command: '/usr/bin/python3.12 -m venv /srv/curator', creates: '/srv/curator/bin/pip') }

        it 'passes the options to pip and installs the local file' do
          is_expected.to contain_exec('curator-install').with_command(
            '/srv/curator/bin/pip install --disable-pip-version-check --no-input --index-url https://pypi.example.com/simple ' \
            "elasticsearch-curator\\ @\\ file:///srv/wheels/elasticsearch_curator-8.0.21-py3-none-any.whl\\#sha256\\=#{sha_8}",
          )
        end
      end

      context 'with manage_python => false' do
        let(:params) { { manage_python: false } }

        it { is_expected.not_to contain_package('python3-venv') }
        it { is_expected.to contain_exec('curator-venv').with_require([]) }
      end

      context 'when python3-venv is declared elsewhere' do
        let(:pre_condition) { "package { 'python3-venv': ensure => present }" }

        it { is_expected.to compile.with_all_deps }
      end

      context 'with TLS, basic authentication and logging settings' do
        let(:params) do
          {
            hosts: 'https://es.example.com:9200',
            ca_certs: '/etc/ssl/certs/es-ca.pem',
            client_cert: '/etc/ssl/certs/curator.pem',
            client_key: '/etc/ssl/private/curator.key',
            verify_certs: true,
            request_timeout: 120,
            master_only: true,
            username: 'curator',
            password: sensitive('s3cret: "quoted"'),
            log_level: 'DEBUG',
            logfile: '/var/log/curator.log',
            logformat: 'json',
            blacklist: [],
          }
        end

        it 'writes them under Curator\'s own keys' do
          expect(curator_yml['elasticsearch']).to eq(
            'client' => {
              'hosts' => ['https://es.example.com:9200'],
              'ca_certs' => '/etc/ssl/certs/es-ca.pem',
              'client_cert' => '/etc/ssl/certs/curator.pem',
              'client_key' => '/etc/ssl/private/curator.key',
              'verify_certs' => true,
              'request_timeout' => 120,
            },
            'other_settings' => {
              'master_only' => true,
              'username' => 'curator',
              'password' => 's3cret: "quoted"',
            },
          )
          expect(curator_yml['logging']).to eq(
            'loglevel' => 'DEBUG',
            'logfile' => '/var/log/curator.log',
            'logformat' => 'json',
            'blacklist' => [],
          )
        end

        it 'keeps the password out of reports' do
          expect(catalogue.resource('File', config_file).sensitive_parameters).to include(:content)
        end
      end

      context 'with a plain-text password' do
        let(:params) { { username: 'curator', password: 'secret' } }

        it 'still keeps it out of reports' do
          expect(catalogue.resource('File', config_file).sensitive_parameters).to include(:content)
          expect(curator_yml['elasticsearch']['other_settings']['password']).to eq('secret')
        end
      end

      context 'without secrets' do
        it 'leaves the content visible in diffs' do
          expect(catalogue.resource('File', config_file).sensitive_parameters).not_to include(:content)
        end
      end

      context 'with an API key ID and secret' do
        let(:params) { { api_key_id: 'key-id', api_key: sensitive('key-secret') } }

        it { expect(curator_yml['elasticsearch']['other_settings']['api_key']).to eq('id' => 'key-id', 'api_key' => 'key-secret') }
      end

      context 'with an encoded API key' do
        let(:params) { { api_key_token: sensitive('a2V5LWlkOmtleS1zZWNyZXQ=') } }

        it { expect(curator_yml['elasticsearch']['other_settings']['api_key']).to eq('token' => 'a2V5LWlkOmtleS1zZWNyZXQ=') }
      end

      context 'with Elastic Cloud' do
        let(:params) { { cloud_id: 'deployment:ZXhhbXBsZQ==' } }

        it 'writes cloud_id instead of hosts' do
          expect(curator_yml['elasticsearch']['client']).to eq('cloud_id' => 'deployment:ZXhhbXBsZQ==')
        end
      end

      context 'with settings merged over the parameters' do
        let(:params) do
          {
            hosts: ['https://es1.example.com:9200', 'https://es2.example.com:9200'],
            settings: {
              'elasticsearch' => {
                'client' => { 'ssl_assert_fingerprint' => 'AB:CD', 'http_compress' => true },
                'other_settings' => { 'skip_version_test' => true },
              },
              'logging' => { 'loglevel' => 'WARNING' },
            },
          }
        end

        it 'keeps what it doesn\'t override' do
          expect(curator_yml['elasticsearch']['client']).to eq(
            'hosts' => ['https://es1.example.com:9200', 'https://es2.example.com:9200'],
            'ssl_assert_fingerprint' => 'AB:CD',
            'http_compress' => true,
          )
          expect(curator_yml['elasticsearch']['other_settings']).to eq('master_only' => false, 'skip_version_test' => true)
          expect(curator_yml['logging']['loglevel']).to eq('WARNING')
          expect(curator_yml['logging']['logformat']).to eq('default')
        end
      end

      context 'with the configuration somewhere else' do
        let(:params) { { config_dir: '/etc/curator' } }

        it { is_expected.to contain_file('/etc/curator').with_mode('0700') }
        it { is_expected.to contain_file('/etc/curator/curator.yml') }
        it { is_expected.to contain_concat('/etc/curator/actions.yml') }

        context 'without managing the directory' do
          let(:params) { super().merge(manage_config_dir: false) }

          it { is_expected.not_to contain_file('/etc/curator') }
        end
      end

      context 'with a username but no password' do
        let(:params) { { username: 'curator' } }

        it { is_expected.to compile.and_raise_error(%r{set both username and password, or neither}) }
      end

      context 'with an API key ID but no secret' do
        let(:params) { { api_key_id: 'key-id' } }

        it { is_expected.to compile.and_raise_error(%r{set both api_key_id and api_key, or neither}) }
      end

      context 'with both kinds of API key' do
        let(:params) { { api_key_id: 'key-id', api_key: 'key-secret', api_key_token: 'token' } }

        it { is_expected.to compile.and_raise_error(%r{set either api_key_token or api_key_id and api_key, not both}) }
      end

      context 'with a host that isn\'t a URL' do
        let(:params) { { hosts: ['es.example.com'] } }

        it { is_expected.to compile.and_raise_error(%r{hosts}) }
      end

      context 'with a schedule' do
        let(:params) { { on_calendar: '*-*-* 01:30:00', timer_overrides: { 'RandomizedDelaySec' => '15m' } } }

        it { is_expected.to compile.with_all_deps }

        it 'runs Curator from a systemd timer' do
          is_expected.to contain_systemd__timer_wrapper('curator').with(
            ensure: 'present',
            command: '/opt/curator/bin/curator --config /root/.curator/curator.yml /root/.curator/actions.yml',
            on_calendar: '*-*-* 01:30:00',
            timer_overrides: { 'Persistent' => true, 'RandomizedDelaySec' => '15m' },
          )
        end

        it 'writes the service unit' do
          is_expected.to contain_systemd__manage_unit('curator.service').with(
            unit_entry: {
              'Description' => 'Elasticsearch Curator',
              'Documentation' => 'https://www.elastic.co/guide/en/elasticsearch/client/curator/current/index.html',
              'Wants' => 'network-online.target',
              'After' => 'network-online.target',
            },
            service_entry: {
              'ExecStart' => '/opt/curator/bin/curator --config /root/.curator/curator.yml /root/.curator/actions.yml',
              'Type' => 'oneshot',
              'NoNewPrivileges' => true,
              'PrivateTmp' => true,
              'ProtectSystem' => 'full',
            },
          )
          is_expected.to contain_file('/etc/systemd/system/curator.service')
            .with_content(%r{^ExecStart=/opt/curator/bin/curator --config /root/.curator/curator.yml /root/.curator/actions.yml$})
        end

        it 'enables the timer' do
          is_expected.to contain_file('/etc/systemd/system/curator.timer')
            .with_content(%r{^OnCalendar=\*-\*-\* 01:30:00$})
            .with_content(%r{^Persistent=true$})
            .with_content(%r{^RandomizedDelaySec=15m$})
            .with_content(%r{^WantedBy=timers.target$})
          is_expected.to contain_service('curator.timer').with(ensure: true, enable: true)
        end

        it { is_expected.to contain_class('curator::config').that_comes_before('Class[curator::service]') }
      end

      context 'with actions' do
        let(:params) do
          {
            actions: {
              'delete old indices' => {
                'action' => 'delete_indices',
                'order' => 1,
                'filters' => [{ 'filtertype' => 'none' }],
              },
            },
          }
        end

        it { is_expected.to contain_curator__action('delete old indices').with(action: 'delete_indices', order: 1) }
        it { is_expected.to contain_concat__fragment('curator action 1').with_target(actions_file) }
      end

      context 'with install_only => true' do
        let(:params) { { install_only: true, on_calendar: 'daily' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('curator-install') }
        it { is_expected.not_to contain_class('curator::config') }
        it { is_expected.not_to contain_file(config_file) }
        it { is_expected.not_to contain_concat(actions_file) }
        it { is_expected.to contain_systemd__timer_wrapper('curator').with_ensure('present') }
        it { is_expected.to contain_class('curator::install').that_comes_before('Class[curator::service]') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent', on_calendar: 'daily' } }

        it { is_expected.to compile.with_all_deps }

        it 'removes the timer first' do
          is_expected.to contain_systemd__timer_wrapper('curator').with_ensure('absent')
          is_expected.to contain_class('curator::service').that_comes_before('Class[curator::config]')
          is_expected.to contain_class('curator::config').that_comes_before('Class[curator::install]')
        end

        it 'removes the configuration' do
          is_expected.to contain_file(config_file).with_ensure('absent')
          is_expected.to contain_concat(actions_file).with_ensure('absent')
          is_expected.not_to contain_concat__fragment('curator actions header')
        end

        it 'removes the virtualenv, but only if it is one' do
          is_expected.to contain_exec('curator-remove-venv').with(
            command: 'rm -rf -- /opt/curator',
            onlyif: 'test -f /opt/curator/pyvenv.cfg',
          )
          is_expected.not_to contain_exec('curator-install')
          is_expected.not_to contain_package('python3-venv')
        end

        context 'for a version without a checksum' do
          let(:params) { super().merge(version: '7.0.0') }

          it { is_expected.to compile.with_all_deps }
        end
      end
    end
  end
end
