require_relative 'spec_helper'

describe package('yum-plugin-versionlock') do
  it { should be_installed }
end
