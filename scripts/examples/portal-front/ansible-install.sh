#!/usr/bin/env bash

wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm
echo "Installing: epel ..."
yum install epel -y
echo "Installing: ansible ..."
yum install ansible -y
echo "localhost ansible_connection=local" >> /etc/ansible/hosts
