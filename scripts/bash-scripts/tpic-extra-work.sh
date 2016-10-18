#!/usr/bin/env bash

#Estos comandos se ejecutaron luego de tpic-complete-build en el server del ambiente de IC Prisma para que quede la configuración más prolija para su utilización por jenkins

#Paso node a /opt
sudo cp -r node-v0.12.0-linux-x64 /opt/

#Links simbólicos de ejecutables de node en /usr/bin/
sudo ln -s /opt/node-v0.12.0-linux-x64/bin/grunt /usr/bin/grunt
sudo ln -s /opt/node-v0.12.0-linux-x64/bin/bower /usr/bin/bower
sudo ln -s /opt/node-v0.12.0-linux-x64/bin/npm /usr/bin/npm
sudo ln -s /opt/node-v0.12.0-linux-x64/bin/node /usr/bin/node

#Links simbólicos para maven
sudo ln -s /usr/local/maven /opt/maven
sudo ln -s /usr/local/maven/bin/mvn /usr/bin/mvn
