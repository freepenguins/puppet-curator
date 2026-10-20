# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

describe 'curator::action' do
  actions_file = '/root/.curator/actions.yml'

  let(:title) { 'delete old logstash indices' }
  let(:params) do
    {
      action: 'delete_indices',
      order: 3,
      options: { 'ignore_empty_list' => true, 'timeout_override' => 300 },
      filters: [
        { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
        { 'filtertype' => 'age', 'source' => 'name', 'direction' => 'older',
          'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 30 },
      ],
    }
  end

  # The actions file as Curator reads it: the header plus every action's
  # fragment, in order.
  let(:actions) do
    fragments = catalogue.resources.select { |r| r.type == 'Concat::Fragment' && r[:target] == actions_file }
    YAML.safe_load(fragments.sort_by { |r| r[:order].to_i }.map { |r| r[:content] }.join)
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('curator') }

      it 'adds the action to the actions file under its order' do
        is_expected.to contain_concat__fragment('curator action 3').with(target: actions_file, order: 3)
        expect(actions).to eq(
          'actions' => {
            3 => {
              'action' => 'delete_indices',
              'description' => 'delete old logstash indices',
              'options' => { 'ignore_empty_list' => true, 'timeout_override' => 300 },
              'filters' => [
                { 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logstash-' },
                { 'filtertype' => 'age', 'source' => 'name', 'direction' => 'older',
                  'timestring' => '%Y.%m.%d', 'unit' => 'days', 'unit_count' => 30 },
              ],
            },
          },
        )
      end

      it 'quotes strings YAML would otherwise misread' do
        expect(catalogue.resource('Concat::Fragment', 'curator action 3')[:content]).to include(%(timestring: "%Y.%m.%d"\n))
      end

      context 'with the action as the title and a multi-line description' do
        let(:title) { 'snapshot' }
        let(:params) do
          {
            order: 1,
            description: "Nightly snapshot:\nall indices",
            options: { 'repository' => 'backups', 'name' => 'curator-%Y.%m.%d', 'wait_for_completion' => true },
            filters: [{ 'filtertype' => 'none' }],
          }
        end

        it 'keeps the YAML valid' do
          expect(actions['actions'][1]).to eq(
            'action' => 'snapshot',
            'description' => "Nightly snapshot:\nall indices",
            'options' => { 'repository' => 'backups', 'name' => 'curator-%Y.%m.%d', 'wait_for_completion' => true },
            'filters' => [{ 'filtertype' => 'none' }],
          )
        end
      end

      context 'with several actions' do
        let(:pre_condition) do
          <<~PUPPET
            curator::action { 'close': order => 10, filters => [{ 'filtertype' => 'closed', 'exclude' => true }] }
            curator::action { 'forcemerge': order => 2, options => { 'max_num_segments' => 1 }, filters => [{ 'filtertype' => 'forcemerged', 'max_num_segments' => 1, 'exclude' => true }] }
          PUPPET
        end

        it { is_expected.to contain_concat__fragment('curator action 2').with_order(2) }
        it { is_expected.to contain_concat__fragment('curator action 10').with_order(10) }

        it 'writes them all, in order' do
          expect(actions['actions'].keys).to eq([2, 3, 10])
          expect(actions['actions'].values.map { |a| a['action'] }).to eq(['forcemerge', 'delete_indices', 'close'])
        end
      end

      context 'with an order that is already taken' do
        let(:pre_condition) { "curator::action { 'other': action => 'close', order => 3, filters => [{ 'filtertype' => 'none' }] }" }

        it { is_expected.to compile.and_raise_error(%r{order 3 is already used by another curator::action}) }
      end

      context 'without filters' do
        let(:params) { { action: 'delete_indices', order: 1 } }

        it { is_expected.to compile.and_raise_error(%r{delete_indices needs at least one filter}) }
      end

      context 'with an unknown action' do
        let(:params) { { action: 'optimize', order: 1, filters: [{ 'filtertype' => 'none' }] } }

        it { is_expected.to compile.and_raise_error(%r{action}) }
      end

      context 'with an alias' do
        let(:title) { 'logs-current' }
        let(:params) do
          {
            action: 'alias',
            order: 2,
            options: { 'name' => 'logs-current' },
            add: { 'filters' => [{ 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' }] },
            remove: { 'filters' => [{ 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-old-' }] },
          }
        end

        it 'writes add and remove instead of filters' do
          expect(actions['actions'][2]).to eq(
            'action' => 'alias',
            'description' => 'logs-current',
            'options' => { 'name' => 'logs-current' },
            'add' => { 'filters' => [{ 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-' }] },
            'remove' => { 'filters' => [{ 'filtertype' => 'pattern', 'kind' => 'prefix', 'value' => 'logs-old-' }] },
          )
        end

        context 'without add or remove' do
          let(:params) { super().reject { |k, _| [:add, :remove].include?(k) } }

          it { is_expected.to compile.and_raise_error(%r{alias needs add, remove or both}) }
        end

        context 'without the alias name' do
          let(:params) { super().merge(options: {}) }

          it { is_expected.to compile.and_raise_error(%r{alias needs the alias's name in options\['name'\]}) }
        end

        context 'with filters' do
          let(:params) { super().merge(filters: [{ 'filtertype' => 'none' }]) }

          it { is_expected.to compile.and_raise_error(%r{alias takes its filters in add and remove}) }
        end
      end

      context 'with add on another action' do
        let(:params) { super().merge(add: { 'filters' => [] }) }

        it { is_expected.to compile.and_raise_error(%r{add and remove are only for alias}) }
      end

      ['cluster_routing', 'create_index', 'rollover'].each do |action|
        context "with #{action}" do
          let(:title) { action }

          context 'and no filters' do
            let(:params) { { order: 1, options: { 'name' => 'x' } } }

            it { expect(actions['actions'][1]).to eq('action' => action, 'description' => action, 'options' => { 'name' => 'x' }) }
          end

          context 'and filters' do
            let(:params) { { order: 1, filters: [{ 'filtertype' => 'none' }] } }

            it { is_expected.to compile.and_raise_error(%r{#{action} doesn't take filters}) }
          end
        end
      end

      context 'with install_only => true' do
        let(:pre_condition) { "class { 'curator': install_only => true }" }

        it { is_expected.to compile.and_raise_error(%r{doesn't manage the actions file with install_only => true}) }
      end

      context 'with curator absent' do
        let(:pre_condition) { "class { 'curator': ensure => absent }" }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_concat__fragment('curator action 3') }
      end
    end
  end
end
