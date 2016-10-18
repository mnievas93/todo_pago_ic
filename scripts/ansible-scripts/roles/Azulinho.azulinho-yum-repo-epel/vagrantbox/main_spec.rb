require_relative 'spec_helper'

describe yumrepo('epel') do
  it { should exist }
end

describe file('/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6') do
  it { should be_file }
end
