require_relative 'spec_helper'

describe package('java-1.7.0-openjdk-devel') do
  it { should be_installed }
end
