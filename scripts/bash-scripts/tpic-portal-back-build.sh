#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE BACKEND de PORTAL *****\n"

# Variables Portal
echo -e "\n"$APP_NAME" --> Seteando variables para acceso a recursos del backend de portal ...\n"
PORTAL_BACK_REPOID=boton_portal_back
PORTAL_BACK_DIR=$BASE_REPO_DIR/$PORTAL_BACK_REPOID
PORTAL_BACK_URL=https://$GITHUB_USR_PASS@github.com/TodoPago/$PORTAL_BACK_REPOID.git

echo "PORTAL_BACK_URL: "$PORTAL_BACK_URL
echo "PORTAL_BACK_DIR: "$PORTAL_BACK_DIR


#if [ -d "$PORTAL_BACK_DIR" ]; then
  # Pull de proyecto Portal Backend
#  echo -e "\n"$APP_NAME" --> Ya existe directorio. Clone ya realizado. Realizando pull de backend portal ...\n"
#  cd $PORTAL_BACK_DIR
#  git pull $PORTAL_BACK_URL
#else
  # Clone de proyecto Front de Portal
  echo -e "\n"$APP_NAME" --> Realizando clone de backend portal ...\n"
  git clone -b $BRANCH $PORTAL_BACK_URL $PORTAL_BACK_DIR
#fi

## Compilación del Backend del Portal ##
echo -e "\n"$APP_NAME" ***** Compilación del Backend del Portal *****\n"

echo -e "\n"$APP_NAME" --> Yendo a directorio del backend del Portal ...\n"
cd $PORTAL_BACK_DIR
echo -e "\n"$APP_NAME" --> Realizando build del Backend del Portal ...\n"
mvn clean install -DskipTests


echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE BACKEND de PORTAL FINALIZADA *****\n"
