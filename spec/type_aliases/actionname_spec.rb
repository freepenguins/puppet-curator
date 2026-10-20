# frozen_string_literal: true

require 'spec_helper'

describe 'Curator::ActionName' do
  ['alias', 'cold2frozen', 'delete_indices', 'delete_snapshots', 'rollover', 'snapshot'].each do |value|
    it { is_expected.to allow_value(value) }
  end

  # Curator 3 had optimize and delete commands; Curator 4 and later don't.
  ['optimize', 'delete', 'Delete Indices', ''].each do |value|
    it { is_expected.not_to allow_value(value) }
  end
end
