#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC

mkdir -p /todopago/wso2
groupadd ci
useradd -G ci VISA2\usr_ci
chown -R VISA2\\usr_ci:ci /todopago

#Copia  de las aplicaciones wso2 a /todopago/wso2

#Cambio de propiedad offset a 0 en esb back y en 100 el dss
#/todopago/wso2/back-esb/repository/conf/carbon.xml
#/todopago/wso2/dss/repository/conf/carbon.xml


curl -LO -H "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u67-b01/jdk-7u67-linux-x64.rpm"

echo -e "\n"$APP_NAME" --> Instalando jdk 7u67-b01 de Oracle ...\n"
sudo rpm -i jdk-7u67-linux-x64.rpm

#Ejecución del back esb y dss



JAVA_HOME=/usr/java/jdk1.7.0_67 /todopago/wso2/back-esb/bin/wso2server.sh &
JAVA_HOME=/usr/java/jdk1.7.0_67 /todopago/wso2/dss/bin/wso2server.sh &
JAVA_HOME=/usr/java/jdk1.7.0_67 /todopago/wso2/front-esb/bin/wso2server.sh &
