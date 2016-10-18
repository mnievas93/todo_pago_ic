#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC
BASE_REPO_DIR=$HOME/repos
GITHUB_USR_PASS=usr-ci-prisma:Pris1802
BRANCH=develop

echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE BACKEND de PANEL *****\n"

# Variables Panel
echo -e "\n"$APP_NAME" --> Seteando variables para acceso a recursos del panel ...\n"
PANEL_REPOID=boton_panel_back
PANEL_DIR=$BASE_REPO_DIR/$PANEL_REPOID
PANEL_BACK_DIR=$PANEL_DIR/backend

echo "PORTAL_BACK_DIR: "$PANEL_BACK_DIR

## Compilación del Backend del Panel ##
echo -e "\n"$APP_NAME" ***** Compilación del Backend del Panel *****\n"

echo -e "\n"$APP_NAME" --> Yendo a directorio del frontend del Panel ...\n"
cd $PANEL_BACK_DIR
echo -e "\n"$APP_NAME" --> Realizando build del Backend del Panel ...\n"
mvn clean install -DskipTests


echo -e "\n"$APP_NAME" ***** COMPILACIÓN DE BACKEND de PANEL FINALIZADA *****\n"
