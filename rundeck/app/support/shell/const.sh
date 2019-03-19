#! /usr/bin/zsh -lie


APP_PROP_FILE=/tmp/conf/${APP_NAME}/app-properties.properties
MIN_SERVER_PROVIDER_NUM=10

JAVA_MEM_OPTS=" -server -Xmx2g -Xms2g -Xmn512m -XX:MetaspaceSize=128m  -XX:MaxMetaspaceSize=192m -Xss256k -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:LargePageSizeInBytes=128m -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 "
JAVA_OPTS=" -Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Ddubbo.shutdown.hook=true -Denv=${ENV} -Dapollo.cluster=${CLUSTER} -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=utf-8 "

case "${APP_NAME}" in
  metis-mount-default)
    JAVA_JMX_OPTS=" -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=18009 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
    JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=2234,server=y,suspend=n "
    ;;
  metis-app-mount)
    JAVA_JMX_OPTS=" -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=18010 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
    JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=2235,server=y,suspend=n "
    ;;
  metis-app-vdisk)
    JAVA_JMX_OPTS=" -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=18011 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
    JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=2236,server=y,suspend=n "
    ;;
  *)
    echo "应用名称不正确, 输入的名称为:APP_NAME=${APP_NAME}"
    exit 1
esac
