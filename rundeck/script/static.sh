#! /usr/bin/zsh -lie

##################################################################
# 前端项目解压脚本
##################################################################

RUNDECK_EXEC_ID=
DMS_HOST=http://dms.xyz.cn
#交付包路径
DELIVERY_FILE_URL=
#应用根路径
APP_ROOT=/app
#应用名称
APP_NAME=
#发布环境
ENV=
#交付包本地名称
DELIVERY_FILE_NAME=dist.tar.gz
#公共utils脚本路径
COMMON_UTILS_PATH=http://git.xyz.cn/dream/xyzdeploy/raw/master/rundeck/utils.sh

#判断文件是否存在
function checkRemoteFileExist(){
  rs=`(wget --spider $1 && echo "suc" ) || echo "failed"`
  if [ $rs = "suc" ];then
      return 0
  else
      return 1
  fi
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

if [ -n "${RUNDECK_EXEC_ID}" ];then
  echo "RUNDECK_EXEC_ID: ${RUNDECK_EXEC_ID}"
  echo "DMS_HOST: ${DMS_HOST}"
  curl -s -X POST ${DMS_HOST}/api/deployment/changeByRundeckId/${RUNDECK_EXEC_ID}/start || true
fi

# server.properties 设置有部署环境变量 env
#readPropAsEnv /opt/settings/server.properties

# 注意, 这几个变量由于含有其他参数引用, 必须放在对参数解析之后
#应用部署根路径
DEPLOY_ROOT=${APP_ROOT}/${APP_NAME}

mkdir -p ${DEPLOY_ROOT}
#两个命令放在一起,防止rm -rf * 误删
cd ${DEPLOY_ROOT} && (rm -rf * || true)

rm -rf ${DEPLOY_ROOT}/${DELIVERY_FILE_NAME}
rm -rf ${DEPLOY_ROOT}/dist

wget -q -O ${DELIVERY_FILE_NAME} ${DELIVERY_FILE_URL}

tar -zxvf ${DELIVERY_FILE_NAME}

# 根据 env ，替换 auth.xyz.cn 域名，以请求到正确的认证服务器
case "${ENV}" in
    DEV)
        sed -i 's/auth.xyz.cn/dauth.xyz.cn/g' ${DEPLOY_ROOT}/dist/*.js || true
        echo "已替换 auth.xyz.cn 为 dauth.xyz.cn"
        ;;
    FAT)
        sed -i 's/auth.xyz.cn/tauth.xyz.cn/g' ${DEPLOY_ROOT}/dist/*.js || true
        echo "已替换 auth.xyz.cn 为 tauth.xyz.cn"
        ;;
    UAT)
        sed -i 's/auth.xyz.cn/pauth.xyz.cn/g' ${DEPLOY_ROOT}/dist/*.js || true
        echo "已替换 auth.xyz.cn 为 pauth.xyz.cn"
        ;;
    PRO)
        echo "无需替换 auth.xyz.cn"
        ;;
    *)
        echo "此应用不需要环境变量或环境变量配置不正确：env=${ENV}"
esac

