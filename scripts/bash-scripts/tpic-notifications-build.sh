#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
# TODO: Cambiar a develop, cuando exista el branch
BRANCH=master

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE NOTIFICATIONS *****\n"

# Variables Notifications
echo -e "\n"$APP_NAME" --> Seteando variables para acceso a recursos del proyecto notifications ...\n"
NOTIFICATIONS_REPOID=boton_notifications_service
NOTIFICATIONS_DIR=$BASE_REPO_DIR/$NOTIFICATIONS_REPOID
NOTIFICATIONS_URL=https://$GITHUB_USR_PASS@github.com/TodoPago/$NOTIFICATIONS_REPOID.git

echo "NOTIFICATIONS_URL: "$NOTIFICATIONS_URL
echo "NOTIFICATIONS_DIR: "$NOTIFICATIONS_DIR

#if [ -d "$NOTIFICATIONS_DIR" ]; then
  # Pull de proyecto Notifications
#  echo -e "\n"$APP_NAME" --> Ya existe directorio. Clone ya realizado. Realizando pull de proyecto notifications ...\n"
#  cd $NOTIFICATIONS_DIR
#  git pull $NOTIFICATIONS_URL
#else
  # Clone de proyecto Notifications
  echo -e "\n"$APP_NAME" --> Realizando clone de proyecto notifications ...\n"
  git clone -b $BRANCH $NOTIFICATIONS_URL $NOTIFICATIONS_DIR
#fi

## Compilación del Proyecto Notifications ##
echo -e "\n"$APP_NAME" ***** Compilación de Notifications *****\n"

echo -e "\n"$APP_NAME" --> Yendo a directorio de Notifications ...\n"
cd $NOTIFICATIONS_DIR
echo -e "\n"$APP_NAME" --> Realizando build de Notifications ...\n"
mvn clean install -DskipTests

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE NOTIFICATIONS FINALIZADA *****\n"
