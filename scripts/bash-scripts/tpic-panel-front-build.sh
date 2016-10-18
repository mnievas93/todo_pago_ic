#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop
WORK_DIR=$HOME

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE FRONTEND de PANEL *****\n"

source /opt/rh/ruby193/enable

# Variables Panel
echo -e "\n"$APP_NAME" --> Seteando variables para acceso a recursos del panel ...\n"
PANEL_REPOID=boton_panel_back
PANEL_DIR=$BASE_REPO_DIR/$PANEL_REPOID
PANEL_FRONT_DIR=$PANEL_DIR/frontend
PANEL_URL=https://$GITHUB_USR_PASS@github.com/TodoPago/$PANEL_REPOID.git

echo "PANEL_URL: "$PANEL_URL
echo "PANEL_FRONT_DIR: "$PANEL_FRONT_DIR

#if [ -d "$PANEL_DIR" ]; then
  # Pull de proyecto Panel
#  echo -e "\n"$APP_NAME" --> Ya existe directorio. Clone ya realizado. Realizando pull de proyecto panel ...\n"
#  cd $PANEL_DIR
#  git pull $PANEL_URL
#else
  # Clone de proyecto Panel
  echo -e "\n"$APP_NAME" --> Realizando clone de proyecto panel ...\n"
  git clone -b $BRANCH $PANEL_URL $PANEL_DIR
#fi

## Instalación de dependencias y Build de portal front ##
echo -e "\n"$APP_NAME" ***** Instalación de dependencias y Build del Frontend del Panel *****\n"

echo -e "\n"$APP_NAME" --> Yendo a directorio del repo del Frontend del Panel ...\n"
cd $PANEL_FRONT_DIR

. $WORK_DIR/tpic-front-build-common.sh

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE FRONTEND de PANEL FINALIZADA *****\n"
