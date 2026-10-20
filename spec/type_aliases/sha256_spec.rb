# frozen_string_literal: true

require 'spec_helper'

describe 'Curator::Sha256' do
  it { is_expected.to allow_value('15dd1dc72a43f8b0b68e6a7b8ad4888103fa80e95c894603c6f676a1eaac54f4') }
  it { is_expected.not_to allow_value('15DD1DC72A43F8B0B68E6A7B8AD4888103FA80E95C894603C6F676A1EAAC54F4') }
  it { is_expected.not_to allow_value('15dd1dc7') }
  it { is_expected.not_to allow_value("#{'a' * 64}\n") }
end
