require_relative 'spec_helper'

describe file('/usr/local/bin/python2.7') do
  it { should be_executable }
  it { should be_executable.by('owner') }
  it { should be_executable.by('group') }
  it { should be_executable.by('others') }
  it { should be_file }
end

describe file('/usr/local/bin/easy_install-2.7') do
  it { should be_executable }
  it { should be_executable.by('owner') }
  it { should be_executable.by('group') }
  it { should be_executable.by('others') }
  it { should be_file }
end

describe file('/usr/local/bin/pip2.7') do
  it { should be_file }
  it { should be_executable }
  it { should be_executable.by('owner') }
  it { should be_executable.by('group') }
  it { should be_executable.by('others') }
end

describe file('/usr/local/bin/python') do
  it { should be_linked_to '/usr/local/bin/python2.7' }
end

describe file('/usr/bin/python2.7') do
  it { should be_linked_to '/usr/local/bin/python2.7' }
end
