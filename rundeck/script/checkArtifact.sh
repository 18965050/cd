#!/usr/bin/env bash
echo 'oper: @option.OPER@'
echo 'repoId: @option.repoId@'
echo 'branchName: @option.branchName@'
echo 'tagName: @option.tagName@'
echo 'failForceBuild: @option.failForceBuild@'
echo 'sucForceBuild: @option.sucForceBuild@'
echo 'dmsHost: @option.dmsHost@'

if [[ "@option.OPER@" != "deploy" ]];then
  echo "非 deploy, 不需要 checkArtifact"
  exit 0
fi

wantRes=$(curl -s -X POST -H "Content-Type: application/json" @option.dmsHost@/api/deployment/wantByRundeck \
-d '{ "rundeckExecId": @job.execid@, "repoId": "@option.repoId@", "branchName": "@option.branchName@", "tagName": "@option.tagName@", "failForceBuild": @option.failForceBuild@, "sucForceBuild": @option.sucForceBuild@ }')
maxNum=120
tryNum=1
while [ true ]; do
  ret=$(echo ${wantRes} | jq ".ret")
  if [ -z "${ret}" ] || [ "${ret}" != 0 ] ;then
    echo "请求出错!"
    echo ${wantRes}
    exit 1
  fi
  deployId=$(echo ${wantRes} | jq ".data.deployId")
  buildStatus=$(echo ${wantRes} | jq ".data.buildStatus")
  artifactUrl=$(echo ${wantRes} | jq ".data.artifactUrl")
  buildId=$(echo ${wantRes} | jq ".data.buildId")
  if [ ${buildStatus} -eq 0 ];then
    echo "此次提交构建失败,请提交对应的开发人员解决问题后再发布!!!如果不相信命运,要重新构建,请配置 failForceBuild 为 true 再试!"
    echo "deployId: ${deployId}"
    echo "buildStatus: ${buildStatus}"
    echo "artifactUrl: ${artifactUrl}"
    echo "buildId: ${buildId}"
    echo ""
    exit 1
  fi
  if [ ${buildStatus} -eq 1 ];then
    echo "已经构建,可以发布"
    echo "RUNDECK:DATA:deployId=${deployId}"
    echo "buildStatus: ${buildStatus}"
    echo "RUNDECK:DATA:buildId=${buildId}"
    echo "RUNDECK:DATA:artifactUrl=${artifactUrl//\"/}"
    echo ""
    exit 0
  fi
  if [ ${buildStatus} -eq 2 ];then
    echo "构建中...请等待...."
    echo "deployId: ${deployId}"
    echo "buildStatus: ${buildStatus}"
    echo "artifactUrl: ${artifactUrl}"
    echo "buildId: ${buildId}"
    echo ""
    sleep 5
  fi
  if [ ${buildStatus} -eq 3 ];then
    echo "构建被取消...这不科学...请确认..."
    echo "deployId: ${deployId}"
    echo "buildStatus: ${buildStatus}"
    echo "artifactUrl: ${artifactUrl}"
    echo "buildId: ${buildId}"
    echo ""
    exit 1
  fi
  tryNum=$(($tryNum+1))
  if [ ${tryNum} -ge ${maxNum} ]; then
    echo "共尝试$(($maxNum))次,仍未等到合理构建结果,取消发布,请检查状态!"
    echo ${wantRes}
    exit 1
  fi
  wantRes=$(curl -s -X POST -H "Content-Type: application/json" @option.dmsHost@/api/deployment/want/${deployId} \
  -d '{ "repoId": "@option.repoId@", "branchName": "@option.branchName@", "tagName": "@option.tagName@", "failForceBuild": @option.failForceBuild@, "sucForceBuild": @option.sucForceBuild@ }')

done
