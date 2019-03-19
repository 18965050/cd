#! /usr/bin/zsh -lie

#交付包路径
DELIVERY_FILE_URL=
#应用根路径
APP_ROOT=/app
#应用名称
APP_NAME=
#操作.只能为deploy,start,stop,restart
OPER=
#发布环境
ENV=
#发布集群
CLUSTER=
#交付包本地名称
DELIVERY_FILE_NAME=dist.tar.gz
#应用Target工作路径
APP_TARGET_ROOT=""
#应用Target文件名
APP_TARGET_NAME=""
#应用运行lib路径
APP_RUN_LIB=""
#应用启动类
APP_MAIN_CLASS=""
#应用动态生成的属性文件路径,一般对应dubbo动态属性
APP_PROP_FILE=""
#Java JMX配置
#JAVA_JMX_OPTS=" -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9009 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
JAVA_JMX_OPTS=""
#Java 远程debug配置
#JAVA_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=2234,server=y,suspend=n "
JAVA_DEBUG_OPTS=""
#Java 内存配置
JAVA_MEM_OPTS=""
#Java 其他配置
JAVA_OPTS=""
#Java进程ID
PID=""
#应用最少服务个数,用于判断服务是否都启动好
MIN_SERVER_PROVIDER_NUM=2
#公共utils脚本路径
COMMON_UTILS_PATH=http://git.xyz.cn/dream/xyzdeploy/raw/master/rundeck/utils.sh
#Web监控页面URL
WEB_MONITOR_URL=
#Web监控成功内容
WEB_MONITOR_SUC_CONTENT=
#Web启动最多验证次数
WEB_START_MAXNUM=300

#判断文件是否存在
function checkRemoteFileExist(){
  rs=`(wget --spider $1 && echo "suc" ) || echo "failed"`
  if [ $rs = "suc" ];then
      return 0
  else
      return 1
  fi
}

#部署
function deploy(){
    if checkRemoteFileExist ${DELIVERY_FILE_URL} ;then
        #1. 停止应用
        if [ -f ${DEPLOY_ROOT}/dist/support/shell/stop.sh ];then
           cd ${DEPLOY_ROOT} && source dist/support/shell/stop.sh
        fi
        #2. 下载并解压文件
        mkdir -p ${DEPLOY_ROOT}
        #两个命令放在一起,防止rm -rf * 误删
        cd ${DEPLOY_ROOT} && (rm -rf * || true)
        wget -q -O ${DELIVERY_FILE_NAME} ${DELIVERY_FILE_URL}
        tar -zxvf ${DELIVERY_FILE_NAME}
        #3. 启动应用
        source dist/support/shell/deploy.sh
    else
        echo "交付件(${DELIVERY_FILE_URL})不存在,不能发布!!!"
    fi

}

#启动
function start(){
    cd ${DEPLOY_ROOT}
    source dist/support/shell/start.sh
}

#停止
function stop(){
    cd ${DEPLOY_ROOT}
    source dist/support/shell/stop.sh
}

#############################MAIN#####################################

local_ip=$(ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:")
echo "当前工作服务器IP : ${local_ip}\n"

#执行公共脚本
if ! checkRemoteFileExist ${COMMON_UTILS_PATH} ;then
    echo "公共Utils脚本(${COMMON_UTILS_PATH})不存在,不能发布!!!"
    exit 1
fi

if [ ! -d ${APP_ROOT} ];then
  mkdir -p ${APP_ROOT}
fi

cd ${APP_ROOT}
wget -q -O utils.sh http://git.xyz.cn/dream/xyzdeploy/raw/master/rundeck/utils.sh
source utils.sh

params=$(echo $*|tr "," "\n")
echo ${params} > ${APP_ROOT}/params.properties
readPropAsEnv ${APP_ROOT}/params.properties

# 注意, 这几个变量由于含有其他参数引用, 必须放在对参数解析之后
#应用部署根路径
DEPLOY_ROOT=${APP_ROOT}/${APP_NAME}
#应用启动日志路径
LOG_DIR=${DEPLOY_ROOT}/logs
#应用启动日志文件名
STDOUT_FILE=${LOG_DIR}/${APP_NAME}-stdout.log

case "${OPER}" in
    deploy)
        deploy
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        #由于FMQ消息平台问题, 需要应用停止一段时间后才能启动
        echo "即将休眠30s...zzz..."
        sleep 30
        start
        ;;
    *)
        echo "操作类型不正确, 输入的操作为:OPER=${OPER}"
        exit 1
esac
