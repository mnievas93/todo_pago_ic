require_relative 'spec_helper'

describe yumrepo('jenkins') do
  it { should exist }
end

describe command('rpm -q gpg-pubkey-d50582e6') do
  its(:exit_status) { should eq 0 }
end
