#! /usr/bin/zsh -lie

#检测进程是否存在
function checkRunning() {
    logInfo=${2-true}
    if [ ${logInfo} = true ]; then
      echo "校验 java 进程执行，匹配参数:[$1]"
    fi
    PID=$(ps -ef | grep java | grep "$1" | awk '{print $2}')
    if [ ${logInfo} = true ]; then
      echo ${PID}
    fi
    if [ -n "${PID}" ]; then
        return 0
    else
        return 1
    fi
}

#读取属性文件并放入变量中
function readPropAsEnv(){
  maxNum=${2-1}
  tryNum=0
  while true; do
    tryNum=$(($tryNum+1))
    if [ -f "$1" ]
    then
      echo "第${tryNum}次检查，发现文件：$1 "
      while IFS='=' read -r key value
      do
        if [[ $key =~ "#.*" ]]; then
            continue
        fi
        key=$(echo $key | tr '.' '_'|sed 's/^ //g;s/ $//g')
        value=$(echo $value |sed 's/^ //g;s/ $//g')
        CMD="${key}='${value}'"
        eval $CMD
        echo "设置变量:${CMD}"
      done < "$1"
      return 0
    elif [ $tryNum -ge $maxNum ]; then
      echo "共尝试${tryNum}次,未发现文件：$1, 读取失败"
      return 1
    else
      echo "第${tryNum}次检查，未发现文件：$1"
      sleep 1
    fi
  done
}

function checkUntilStarted(){
  #TODO 检查日志文件或其他一些方式，判定程序启动成功
  return 1
}

#服务化应用启动流程
function serviceStart(){
    if checkRunning $APP_MAIN_CLASS; then
        echo "应用已经启动,We will do nothing!!!"
    else
        mkdir -p ${LOG_DIR}
        if [ -f ${APP_PROP_FILE} ]; then
            rm -rf $APP_PROP_FILE
            rm -rf $STDOUT_FILE || true
        fi
        touch ${STDOUT_FILE}

        #启动服务
        echo "启动应用"
        CMD='nohup java '${JAVA_OPTS}' '${JAVA_DUBBO_OPTS}' '${JAVA_MEM_OPTS}' '${JAVA_JMX_OPTS}' '${JAVA_DEBUG_OPTS}' -cp "${APP_RUN_LIB}" '${APP_MAIN_CLASS}'  > '${STDOUT_FILE}' 2>&1 & '
        echo "在目录 [$(pwd)] 执行命令: \n  -- [${CMD}]"
        eval ${CMD}
        echo "应用开始启动"

        # 校验进程启动, 防止瞬间执行瞬间后失败
        sleep 1
        if ! checkRunning $APP_MAIN_CLASS; then
          echo "启动失败，进程不存在！请查看日志： ${STDOUT_FILE}, 以下是最后一百行："
          tail -n 100 ${STDOUT_FILE}
          exit 1
        fi
        # 读取应用启动临时变量
        if ! readPropAsEnv $APP_PROP_FILE 10; then
          echo "启动失败，在固定时间内未读取到临时配置！请查看日志： ${STDOUT_FILE}, 以下是最后一百行："
          tail -n 100 ${STDOUT_FILE}
          exit 2
        fi

        # 校验启动成功
        echo "dubbo 启动端口：${dubbo_protocol_port}"
        echo "dubbo QOS端口：${dubbo_application_qos_port-$dubbo_qos_port}"
        echo "应用启动中，请等待."
        servicePortOpen=false
        while [ true ]; do
          # 通过 QOS 检测服务状态
          serviceInfo=$(curl -s --connect-timeout 1 "http://localhost:${dubbo_application_qos_port-$dubbo_qos_port}/ls" || echo "notOK")
          # 匹配到的“Provider”数量
          serviceProviderNum=$(echo $serviceInfo|grep 'Provider *| Y'|wc -l)

          if ! checkRunning $APP_MAIN_CLASS false; then
            # 启动后线程又由于某种原因被干掉
            echo "启动失败，线程终止！请查看日志： ${STDOUT_FILE}, 以下是最后一百行："
            tail -n 100 ${STDOUT_FILE}
            exit 3
          elif [ $serviceProviderNum -eq 0 ] && [ $servicePortOpen = false ]; then
            ## 端口未打开
              echo "."
          elif [ $serviceProviderNum -eq 0 ]; then
            ## 端口打开后服务数量变为0，则启动失败
              echo "\n启动失败！！详情见日志：${STDOUT_FILE} , 以下是最后一百行："
              tail -n 100 ${STDOUT_FILE}
              exit 4
          elif [ $servicePortOpen = false ]; then
            ## 服务数量不为零，之前端口未打开，说明端口刚刚打开
            servicePortOpen=true
            echo "\n服务端口打开，请等待服务启动完成."
          elif [ $serviceProviderNum -lt ${MIN_SERVER_PROVIDER_NUM} ]; then
            ## 服务数量小于10（实际包含额外说明字符占用数量）说明未启动完全
              echo "."
          else
              echo "启动成功！服务如下："
              echo $serviceInfo
              exit 0
          fi
          sleep 1
        done
    fi
}

#Java应用停止
function javaStop(){
    echo "停止应用"
    if checkRunning $APP_MAIN_CLASS; then
        kill $PID
        while [ true ]; do
            sleep 1
            if ! checkRunning $APP_MAIN_CLASS; then
                break
            fi
        done
        echo "停止应用成功"
    else
        echo "应用未启动,We will do nothing!!!"
    fi
}

#Springboot应用停止
function bootStop(){
    echo "停止应用"
    if checkRunning $APP_TARGET_NAME; then
        kill $PID
        while [ true ]; do
            sleep 1
            if ! checkRunning $APP_TARGET_NAME; then
                break
            fi
        done
        echo "停止应用成功"
    else
        echo "应用未启动,We will do nothing!!!"
    fi
}

#服务化应用部署流程
function serviceDeploy(){
    cd ${APP_TARGET_ROOT}
    tar -xvf ${APP_TARGET_NAME}
    serviceStart
}

#Java Web应用部署流程
function webDeploy(){
    cd ${APP_TARGET_ROOT}
    unzip ${APP_TARGET_NAME}
    webStart
}

# SpringBoot Web应用部署流程
function bootWebDeploy(){
    cd ${APP_TARGET_ROOT}
    bootWebStart
}


# SpringBoot Web应用启动流程
function bootWebStart(){
    # boot应用没有$APP_MAIN_CLASS, 通过包名称校验
    if checkRunning $APP_TARGET_NAME; then
        echo "应用已经启动,We will do nothing!!!"
    else
        mkdir -p ${LOG_DIR}
        if [ -f ${STDOUT_FILE} ]; then
            rm -rf $STDOUT_FILE
        fi
        touch ${STDOUT_FILE}

        #启动服务
        echo "启动应用"
        CMD='nohup java '${JAVA_OPTS}' '${JAVA_DUBBO_OPTS}' '${JAVA_MEM_OPTS}' '${JAVA_JMX_OPTS}' '${JAVA_DEBUG_OPTS}' -jar '${APP_TARGET_NAME}'  > '${STDOUT_FILE}' 2>&1 & '
        echo "在目录 [$(pwd)] 执行命令: \n  -- [${CMD}]"
        eval ${CMD}
        echo "应用开始启动"

        # 校验进程启动, 防止瞬间执行瞬间后失败
        sleep 1
        if ! checkRunning $APP_TARGET_NAME; then
          echo "启动失败，进程不存在！请查看日志： ${STDOUT_FILE}, 以下是最后一百行："
          tail -n 100 ${STDOUT_FILE}
          exit 1
        fi

        # 校验启动成功
        echo "应用启动中，请等待."
        tryNum=0
        while [ true ]; do
          tryNum=$(($tryNum+1))
          echo "."
          # 通过 curl 检测服务状态
          CONTENT=$(curl -s -X GET ${WEB_MONITOR_URL} || echo "notOK")
          if [[ "${CONTENT}" = *"${WEB_MONITOR_SUC_CONTENT}"* ]];then
            echo "应用启动成功"
            exit 0
          fi
          if [ ${tryNum} -ge ${WEB_START_MAXNUM} ];then
            echo "应用启动验证超时!详情见日志：${STDOUT_FILE} , 以下是最后一百行："
            tail -n 100 ${STDOUT_FILE}
            exit 1
          fi
          sleep 1
        done
    fi
}

#Java Web应用启动流程
function webStart(){
    if checkRunning $APP_MAIN_CLASS; then
        echo "应用已经启动,We will do nothing!!!"
    else
        mkdir -p ${LOG_DIR}
        if [ -f ${STDOUT_FILE} ]; then
            rm -rf $STDOUT_FILE
        fi
        touch ${STDOUT_FILE}

        #启动服务
        echo "启动应用"
        CMD='nohup java '${JAVA_OPTS}' '${JAVA_DUBBO_OPTS}' '${JAVA_MEM_OPTS}' '${JAVA_JMX_OPTS}' '${JAVA_DEBUG_OPTS}' -cp "${APP_RUN_LIB}" '${APP_MAIN_CLASS}'  > '${STDOUT_FILE}' 2>&1 & '
        echo "在目录 [$(pwd)] 执行命令: \n  -- [${CMD}]"
        eval ${CMD}
        echo "应用开始启动"

        # 校验进程启动, 防止瞬间执行瞬间后失败
        sleep 1
        if ! checkRunning $APP_MAIN_CLASS; then
          echo "启动失败，进程不存在！请查看日志： ${STDOUT_FILE}, 以下是最后一百行："
          tail -n 100 ${STDOUT_FILE}
          exit 1
        fi

        # 校验启动成功
        echo "应用启动中，请等待."
        tryNum=0
        while [ true ]; do
          tryNum=$(($tryNum+1))
          echo "."
          # 通过 curl 检测服务状态
          CONTENT=$(curl -s -X GET ${WEB_MONITOR_URL} || echo "notOK")
          if [ "${CONTENT}"x = "${WEB_MONITOR_SUC_CONTENT}"x ];then
            echo "应用启动成功"
            exit 0
          fi
          if [ ${tryNum} -ge ${WEB_START_MAXNUM} ];then
            echo "应用启动验证超时!详情见日志：${STDOUT_FILE} , 以下是最后一百行："
            tail -n 100 ${STDOUT_FILE}
            exit 1
          fi
          sleep 1
        done
    fi
}
