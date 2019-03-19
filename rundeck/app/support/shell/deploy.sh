#! /usr/bin/zsh -lie

source dist/support/shell/const.sh

case "${APP_NAME}" in
    metis-mount-default)
        APP_MAIN_CLASS=com.focustech.ins.metis.mount.MountDefaultProvider
        APP_TARGET_ROOT=${DEPLOY_ROOT}/dist/metis-mount/metis-mount-default/target
        APP_TARGET_NAME=metis-mount-default-assembly.tar
        APP_RUN_LIB=${APP_TARGET_ROOT}/lib/*
        serviceDeploy
        ;;
    metis-app-mount)
        APP_MAIN_CLASS=cn.xyz.server.bootstrap.EmbedTomcatMountWebServer
        APP_TARGET_ROOT=${DEPLOY_ROOT}/dist/metis-app/metis-app-mount/target
        APP_TARGET_NAME=metis-app-mount.war
        APP_RUN_LIB=${APP_TARGET_ROOT}/WEB-INF/classes:${APP_TARGET_ROOT}/WEB-INF/lib/*
        WEB_MONITOR_URL=http://localhost:9000/monitor
        WEB_MONITOR_SUC_CONTENT=OK
        webDeploy
        ;;
    metis-app-vdisk)
        APP_MAIN_CLASS=cn.xyz.server.bootstrap.EmbedTomcatVdiskWebServer
        APP_TARGET_ROOT=${DEPLOY_ROOT}/dist/metis-app/metis-app-vdisk/target
        APP_TARGET_NAME=metis-app-vdisk.war
        APP_RUN_LIB=${APP_TARGET_ROOT}/WEB-INF/classes:${APP_TARGET_ROOT}/WEB-INF/lib/*
        WEB_MONITOR_URL=http://localhost:9001/monitor
        WEB_MONITOR_SUC_CONTENT=OK
        webDeploy
        ;;
    *)
        echo "应用名称不正确, 输入的名称为:APP_NAME=${APP_NAME}"
        exit 1
esac
