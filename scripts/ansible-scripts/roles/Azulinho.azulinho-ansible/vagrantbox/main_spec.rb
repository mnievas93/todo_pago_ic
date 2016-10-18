require_relative 'spec_helper'

ansible_files = [
  '/usr/local/bin/ansible',
  '/usr/local/bin/ansible-playbook']


ansible_files.each do |ansible_file|
  describe file(ansible_file) do
    it { should be_executable }
    it { should be_executable.by('owner') }
    it { should be_executable.by('group') }
    it { should be_executable.by('others') }
    it { should be_file }
  end
end
