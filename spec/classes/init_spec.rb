require 'spec_helper'
describe 'was' do

  context 'with defaults for all parameters' do
    it { should contain_class('was') }
  end
end
