#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC

echo -e "\n"$APP_NAME" --> Instalando grunt ...\n"
npm install -g grunt
echo -e "\n"$APP_NAME" --> Instalando grunt-cli ...\n"
npm install -g grunt-cli
echo -e "\n"$APP_NAME" --> Instalando bower ...\n"
npm install -g bower
echo -e "\n"$APP_NAME" --> Instalando demás dependencias npm del proyecto ...\n"
npm install
echo -e "\n"$APP_NAME" --> Instalando demás dependencias bower del proyecto ...\n"
bower install
echo -e "\n"$APP_NAME" --> Haciendo grunt build del Frontend del Portal ...\n"
grunt build
