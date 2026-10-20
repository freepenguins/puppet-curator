# frozen_string_literal: true

require 'spec_helper'

describe 'Curator::Version' do
  ['8.0.21', '9.0.0', '8.0.22rc1', '10.0'].each do |value|
    it { is_expected.to allow_value(value) }
  end

  ['latest', '8', '8.0.21; rm -rf /', '"8.0.21"', ''].each do |value|
    it { is_expected.not_to allow_value(value) }
  end
end
