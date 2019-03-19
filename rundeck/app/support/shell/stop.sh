#! /usr/bin/zsh -lie

source dist/support/shell/const.sh

case "${APP_NAME}" in
    metis-mount-default)
        APP_MAIN_CLASS=com.focustech.ins.metis.mount.MountDefaultProvider
        javaStop
        ;;
    metis-app-mount)
        APP_MAIN_CLASS=cn.xyz.server.bootstrap.EmbedTomcatMountWebServer
        javaStop
        ;;
    metis-app-vdisk)
        APP_MAIN_CLASS=cn.xyz.server.bootstrap.EmbedTomcatVdiskWebServer
        javaStop
        ;;
    *)
        echo "应用名称不正确, 输入的名称为:APP_NAME=${APP_NAME}"
        exit 1
esac
