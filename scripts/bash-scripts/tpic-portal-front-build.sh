#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop
WORK_DIR=$HOME

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE FRONTEND de PORTAL *****\n"

source /opt/rh/ruby193/enable

# Variables Portal
echo -e "\n"$APP_NAME" --> Seteando variables para acceso a recursos del fronend del portal ...\n"
PORTAL_FRONT_REPOID=boton_portal_front
PORTAL_FRONT_DIR=$BASE_REPO_DIR/$PORTAL_FRONT_REPOID
PORTAL_FRONT_URL=https://$GITHUB_USR_PASS@github.com/TodoPago/$PORTAL_FRONT_REPOID.git

echo "PORTAL_FRONT_URL: "$PORTAL_FRONT_URL
echo "PORTAL_FRONT_DIR: "$PORTAL_FRONT_DIR

#if [ -d "$PORTAL_FRONT_DIR" ]; then
  # Pull de proyecto Portal Frontend
#  echo -e "\n"$APP_NAME" --> Ya existe directorio. Clone ya realizado. Realizando pull de frontend portal ...\n"
#  cd $PORTAL_FRONT_DIR
#  git pull $PORTAL_FRONT_URL
#else
  # Clone de proyecto Front de Portal
  echo -e "\n"$APP_NAME" --> Realizando clone de proyectos portal ...\n"
  git clone -b $BRANCH $PORTAL_FRONT_URL $PORTAL_FRONT_DIR
#fi

## Instalación de dependencias y Build de portal front ##
echo -e "\n"$APP_NAME" ***** Instalación de dependencias y Build del Frontend del Portal *****\n"

echo -e "\n"$APP_NAME" --> Yendo a directorio del repo del Frontend del Portal ...\n"
cd $PORTAL_FRONT_DIR

. $WORK_DIR/tpic-front-build-common.sh

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE FRONTEND de PORTAL FINALIZADA *****\n"
