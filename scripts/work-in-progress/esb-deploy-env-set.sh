
#con usr_ci
mkdir ci-repo
cd ci-repo

#Paso a un usuario que tenga sudo
su - VISA2\\esicomar

sudo bash

groupadd ci

usermod -G ci VISA2\\usr_ci

yum install ansible

#Vuelta al usuario VISA2\\usr_ci
exit
exit

GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop
CI_REPOID=integracion_continua
CI_URL=https://$GITHUB_USR_PASS@github.com/TodoPago/$CI_REPOID.git

# git clone -b develop https://usr-ci-prisma:Pris1802@github.com/TodoPago/integracion_continua.git
git clone -b $BRANCH $CI_URL
# git clone -b develop https://usr-ci-prisma:Pris1802@github.com/TodoPago/WSO2-DataService.git
git clone -b develop https://$GITHUB_USR_PASS@github.com/TodoPago/WSO2-DataService.git

#Seteo de la autenticacion al 14 y al 15 por ssh para conexión ansible (de otra manera pide password por cada tarea que ejecuta (otra opción en utilizar ansible vault))
cd $HOME/.ssh
ssh-keygen -t rsa
ssh-copy-id VISA2\\usr_ci@192.168.74.14
ssh-copy-id VISA2\\usr_ci@192.168.74.15


cd $HOME/ci-repo/WSO2-DataService/deploy
#Modificación del ansible.cfg

# ansible.cfg
#
# [defaults]
# roles_path = ../../integracion_continua/ansible-scripts/esb-deploy/roles
# private_key_file = /home/VISA2/usr_ci/.ssh/id_rsa
# host_key_checking = False
#

# Comando para deployar
ansible-playbook deploy.yml -i ../../integracion_continua/ansible-scripts/esb-deploy/environments/prismaci/hosts
