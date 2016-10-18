#!/usr/bin/env bash

APP_NAME=TODOPAGO-IC


echo -e "\n"$APP_NAME" ********** Eliminación de archivos innecesarios de front-esb, back-esb y dss **********\n"

echo -e "\n"$APP_NAME" ***** Eliminación de logs *****\n"

rm front-esb/repository/logs/*
rm back-esb/repository/logs/*
rm dss/repository/logs/*

echo -e "\n"$APP_NAME" ***** Eliminación de archivos temporales *****\n"

rm -r front-esb/tmp/*
rm -r back-esb/tmp/*
rm -r dss/tmp/*

echo -e "\n"$APP_NAME" ***** Eliminación de componentes deployados en el root tenant *****\n"

rm back-esb/repository/deployment/server/synapse-configs/default/api/*
rm back-esb/repository/deployment/server/synapse-configs/default/local-entries/*
rm back-esb/repository/deployment/server/synapse-configs/default/endpoints/*
rm back-esb/repository/deployment/server/synapse-configs/default/proxy-services/*
rm back-esb/repository/deployment/server/synapse-configs/default/sequences/*

rm front-esb/repository/deployment/server/synapse-configs/default/api/*
rm front-esb/repository/deployment/server/synapse-configs/default/endpoints/*
rm front-esb/repository/deployment/server/synapse-configs/default/local-entries/*
rm front-esb/repository/deployment/server/synapse-configs/default/proxy-services/*
rm front-esb/repository/deployment/server/synapse-configs/default/sequences/*

rm dss/repository/deployment/server/dataservices/*

echo -e "\n"$APP_NAME" ***** Eliminación de componentes deployados en el tenant 2 (tenant 1.2) *****\n"

rm back-esb/repository/tenants/2/synapse-configs/default/api/*
rm back-esb/repository/tenants/2/synapse-configs/default/local-entries/*
rm back-esb/repository/tenants/2/synapse-configs/default/endpoints/*
rm back-esb/repository/tenants/2/synapse-configs/default/proxy-services/*
rm back-esb/repository/tenants/2/synapse-configs/default/sequences/*

rm front-esb/repository/tenants/2/synapse-configs/default/api/*
rm front-esb/repository/tenants/2/synapse-configs/default/endpoints/*
rm front-esb/repository/tenants/2/synapse-configs/default/local-entries/*
rm front-esb/repository/tenants/2/synapse-configs/default/proxy-services/*
rm front-esb/repository/tenants/2/synapse-configs/default/sequences/*

rm dss/repository/tenants/33/dataservices/*

echo -e "\n"$APP_NAME" ***** Eliminación de componentes deployados en el tenant 1 (tenant 1.1) *****\n"

rm back-esb/repository/tenants/1/synapse-configs/default/api/*
rm back-esb/repository/tenants/1/synapse-configs/default/local-entries/*
rm back-esb/repository/tenants/1/synapse-configs/default/endpoints/*
rm back-esb/repository/tenants/1/synapse-configs/default/proxy-services/*
rm back-esb/repository/tenants/1/synapse-configs/default/sequences/*

rm front-esb/repository/tenants/1/synapse-configs/default/api/*
rm front-esb/repository/tenants/1/synapse-configs/default/endpoints/*
rm front-esb/repository/tenants/1/synapse-configs/default/local-entries/*
rm front-esb/repository/tenants/1/synapse-configs/default/proxy-services/*
rm front-esb/repository/tenants/1/synapse-configs/default/sequences/*

rm dss/repository/tenants/1/dataservices/*

tar cvfz dss.tar.gz dss
tar cfvz back-esb.tar.gz back-esb
tar cvfz front-est.tar.gz front-esb

scp front-esb.tar.gz VISA2\\usr_ci@192.168.74.14:/home/VISA2/usr_ci/
scp back-esb.tar.gz VISA2\\usr_ci@192.168.74.15:/home/VISA2/usr_ci/
scp dss.tar.gz VISA2\\usr_ci@192.168.74.15:/home/VISA2/usr_ci/
