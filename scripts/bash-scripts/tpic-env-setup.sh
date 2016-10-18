#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC

## Instalacion de Software Necesario ##
echo -e "\n"$APP_NAME" ***** Instalación de Software Necesario *****\n"
cd

# Instalación de jdk 7u67-b01 de Oracle (esta es la que tienen actualmente en los servidores de producción)
if [ -f ./jdk-7u67-linux-x64.rpm ]; then
  echo -e "\n"$APP_NAME" --> jdk 7u67-b01 de Oracle ya descargada\n"
else
  echo -e "\n"$APP_NAME" --> Descargando jdk 7u67-b01 de Oracle ...\n"
  curl -LO -H "Cookie: oraclelicense=accept-securebackup-cookie" \
  "http://download.oracle.com/otn-pub/java/jdk/7u67-b01/jdk-7u67-linux-x64.rpm"
fi

echo -e "\n"$APP_NAME" --> Instalando jdk 7u67-b01 de Oracle ...\n"
sudo rpm -i jdk-7u67-linux-x64.rpm

# Instalación de git
echo -e "\n"$APP_NAME" --> Instalando git ...\n"
sudo yum -y --quiet install git

# Instalación de wget
echo -e "\n"$APP_NAME" --> Instalando wget ...\n"
sudo yum -y --quiet install wget

# Instalación de Maven 3.3.9 (El último al momento)
if [ -f ./apache-maven-3.3.9-bin.tar.gz ]; then
  echo -e "\n"$APP_NAME" --> Maven 3.3.9 ya descargado \n"
else
  echo -e "\n"$APP_NAME" --> Descargando Maven 3.3.9 ...\n"
  wget http://apache.dattatec.com/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
fi

echo -e "\n"$APP_NAME" --> Descomprimiendo Maven ...\n"
sudo tar xzf apache-maven-3.3.9-bin.tar.gz -C /usr/local
echo -e "\n"$APP_NAME" --> Agregando link simbolico para Maven ...\n"
sudo ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven

echo -e "\n"$APP_NAME" --> Configurando variables de entorno para maven ...\n"
echo "export M2_HOME=/usr/local/maven" >> $HOME/.bash_profile
echo "export PATH=\${M2_HOME}/bin:\${PATH}" >> $HOME/.bash_profile
echo -e "\n"$APP_NAME" --> Configurando variables de entorno para maven en sesión actual ...\n"
export M2_HOME=/usr/local/maven
export PATH=$M2_HOME/bin:$PATH

# Instalación de paquete de seguridad necesario para maven
#( Esto es para eliminar el siguiente warning (error) que da maven: ""[WARNING] Failure to transfer org.apache.maven.plugins/maven-metadata.xml from https://repo.maven.apache.org/maven2 was cached in the local repository, resolution will not be reattempted until the update interval of central has elapsed or updates are forced. Original error: Could not transfer metadata org.apache.maven.plugins/maven-metadata.xml from/to central (https://repo.maven.apache.org/maven2): java.security.ProviderException: java.security.KeyException")
echo -e "\n"$APP_NAME" --> Instalando nss ... \n"
sudo yum -y --quiet install nss

# Instalación de node js

if [ -f ./node-v0.12.0-linux-x64.tar.gz ]; then
  echo -e "\n"$APP_NAME" --> Node JS ya descargado \n"
else
  echo -e "\n"$APP_NAME" --> Descargando node js ...\n"
  wget https://nodejs.org/download/release/v0.12.0/node-v0.12.0-linux-x64.tar.gz
fi

echo -e "\n"$APP_NAME" --> Desplegando targz del NodeJs ...\n"
tar xzf ./node-v0.12.0-linux-x64.tar.gz
echo -e "\n"$APP_NAME" --> Agregando NodeJs al Path ...\n"
export PATH=$PATH:$HOME/node-v0.12.0-linux-x64/bin
echo "export PATH=\$PATH:\$HOME/node-v0.12.0-linux-x64/bin" >> $HOME/.bash_profile

# Instalación de Ruby

echo -e "\n"$APP_NAME" --> Instalando Ruby: centos-release-SCL (no necesario para red hat)...\n"
sudo yum -y --quiet install centos-release-SCL
# En CENTOS 7 el paquete centos-release-SCL se llama centos-release-scl
echo -e "\n"$APP_NAME" --> Instalando Ruby: centos-release-scl (en Centos 7 este es el nombre del paquete) ...\n"
sudo yum -y --quiet install centos-release-scl
echo -e "\n"$APP_NAME" --> Instalando Ruby: ruby193 ...\n"
sudo yum -y --quiet install ruby193
echo -e "\n"$APP_NAME" --> Instalando Ruby: Habilitando ruby ...\n"
echo "source /opt/rh/ruby193/enable" | sudo tee -a /etc/profile.d/ruby193.sh
source /opt/rh/ruby193/enable
echo -e "\n"$APP_NAME" --> Instalando Ruby: herramientas de desarrollo ...\n"
sudo yum -y --quiet install ruby193-ruby-devel.x86_64
# Instalación de Sass
echo -e "\n"$APP_NAME" --> Instalando Sass ...\n"
gem install sass

# Instalación de herramientos de compilación para el Frontend del Panel
# Esto es para tener los headers y la herramienta de compilación que requiere el compass para instalarse
echo -e "\n"$APP_NAME" --> Instalando Dependencias para el Frontend del Panel ...\n"
#TODO: ¡¡Hay que chequearlo!!
# Instalación de gcc
echo -e "\n"$APP_NAME" --> Instalando gcc ...\n"
sudo yum -y --quiet install gcc
#Instalacion de compass
echo -e "\n"$APP_NAME" --> Instalando Compass ...\n"
gem install compass
