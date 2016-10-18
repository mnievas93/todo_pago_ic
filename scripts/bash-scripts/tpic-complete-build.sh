#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
WORK_DIR=$HOME

echo -e "\n"$APP_NAME" ********** CONFIGURACIÓN DE AMBIENTE PARA COMPILACIÓN DE PORTAL Y PANEL **********\n"

. $WORK_DIR/tpic-env-setup.sh

echo -e "\n"$APP_NAME" --> Seteando variables generales ...\n"
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop

. $WORK_DIR/tpic-notifications-build.sh

. $WORK_DIR/tpic-portal-front-build.sh

. $WORK_DIR/tpic-portal-back-build.sh

. $WORK_DIR/tpic-panel-front-build.sh

. $WORK_DIR/tpic-panel-back-build.sh

######
echo -e "\n"$APP_NAME" ********** CONFIGURACIÓN DE AMBIENTE PARA COMPILACIÓN DE PORTAL Y PANEL FINALIZADA **********\n"
