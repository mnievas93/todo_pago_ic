require_relative 'spec_helper'

packages = [
  'python-devel',
  'zlib-devel',
  'bzip2-devel',
  'openssl-devel',
  'ncurses-devel',
  'sqlite-devel',
  'readline-devel',
  'tk-devel',
  'gdbm-devel',
  'db4-devel',
  'libpcap-devel',
  'xz-devel',
  'autoconf',
  'automake',
  'binutils',
  'bison',
  'flex',
  'gcc',
  'gcc-c++',
  'gettext',
  'libtool',
  'make',
  'patch',
  'pkgconfig',
  'redhat-rpm-config',
  'rpm-build',
  'byacc',
  'cscope',
  'ctags',
  'cvs',
  'diffstat',
  'doxygen',
  'elfutils',
  'gcc-gfortran',
  'git',
  'indent',
  'intltool',
  'patchutils',
  'rcs',
  'subversion',
  'swig',
  'systemtap' ]


packages.each do |pkg|
  describe package(pkg) do
    it { should be_installed }
  end
end
