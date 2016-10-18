require_relative 'spec_helper'

describe yumrepo('rpmforge') do
  it { should exist }
end

describe file('/etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag') do
  it { should be_file }
end
