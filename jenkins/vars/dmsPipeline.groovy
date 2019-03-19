
def call(Map pipelineParams) {
    //noinspection GroovyAssignabilityCheck
    def distFileName = "${params.GIT_HASH}.tar.gz";  // 预定义发布文件名
    def dmsCallBackUrl = params.DMS_CALL_BACK_URL // 回调地址

    pipeline {
        agent { label 'ci-builder' }
        parameters {
            string(name: 'REPO_ID', description: 'DMS 中仓库 ID，交付包路径用')
            string(name: 'REPO_NAME', description: 'DMS 中仓库名，唯一，包含path，交付包路径用')
            string(name: 'GIT_REPO_URL', description: '仓库 URL， checkout 代码用')
            string(name: 'GIT_HASH', description: '要构建的 HASH,按照此值生成特定版本构建,与 branch 等其他字段无关')
            string(name: 'GIT_BRANCH', description: '分支号,只作为生成包的一个参考,不按照此参数进行构建;不传,则只生成 hash 的包')
            string(name: 'DMS_CALL_BACK_URL', description: '构建过程的回调,及时上报构建状态')
            string(name: 'GIT_AUTHOR_NAME', description: '作者姓名,不从 hash 中再提取')
            string(name: 'GIT_AUTHOR_EMAIL', description: '作者邮箱(失败反馈邮箱),不从 hash 中再提取')
        }
        options {
            timeout(time: 20, unit: 'MINUTES')
        }
        environment {
            GIT_CREDENTIALS_ID = 'bb13eb6c-47ac-47e5-93ed-e0fdde909d4e'
            DIST_APP_PATH = "${params.REPO_ID}__${params.REPO_NAME}"
            APP_OUT = "${pipelineParams.appOut}"
            DIST_DIR = 'dist'
            TERM = 'linux'
            RSYNC_HOST = '192.168.56.21'
            RSYNC_PATH = 'packages'
            RSYNC_PASS = 'xyzrsync'
            DIST_FILE_NAME="${distFileName}"
        }
        stages {
            stage('预处理') {
                steps {
                    dmsCallBack(step: 1, status: "ing", url: "${dmsCallBackUrl}")
                    checkout([
                            $class: 'GitSCM',
                            branches: [[name: "${params.GIT_HASH}"]],
                            doGenerateSubmoduleConfigurations: false,
                            extensions: [[$class: 'CleanBeforeCheckout']],
                            submoduleCfg: [],
                            userRemoteConfigs: [
                                    [
                                            url: "${params.GIT_REPO_URL}",
                                            credentialsId: "${env.GIT_CREDENTIALS_ID}"
                                    ]
                            ]
                    ])
                }
                post {
                    always {
                        logInfo(distFileName: "${distFileName}")
                    }
                }
            }
            stage('构建') {
                steps {
                    sh """
                    rm -rf ${DIST_DIR}
                    """
                    script {
                        switch (pipelineParams.buildType) {
                            case 'java':
                                javaBuild()
                                break
                            case 'node':
                                nodeBuild()
                                break
                            case 'yarn':
                                yarnBuild()
                                break
                            case 'script':
                                scriptBuild()
                                break
                            default:
                                throw new IllegalArgumentException('buildType参数错误,current=' + pipelineParams.buildType)
                        }

                    }
                }
            }
            stage('交付') {
                steps {
                    sh """
                    if [ ${APP_OUT} != ${DIST_DIR} ]; then
                        time mv ${APP_OUT} ${DIST_DIR}
                    fi
                    time tar -zcf ${distFileName} ${DIST_DIR}
                    time RSYNC_PASSWORD=${RSYNC_PASS} rsync -vzrtopg -C --delete --include=* ${distFileName} root@${RSYNC_HOST}::${RSYNC_PATH}/${DIST_APP_PATH}/
                  """
                }
            }
        }
        post {
            success {
                script {
                    dmsCallBack(step: 4, status: "suc", url: "${dmsCallBackUrl}", artifactUrl: "http://${RSYNC_HOST}/${RSYNC_PATH}/${DIST_APP_PATH}/${distFileName}")
                }
            }
            aborted {
                script {
                    dmsCallBack(step: 4, status: "abort", url: "${dmsCallBackUrl}")
                }
            }
            failure {
                script {
                    dmsCallBack(step: 1, status: "fail", url: "${dmsCallBackUrl}")
                }
                mail to: "${params.GIT_AUTHOR_EMAIL}",
                        subject: "构建结果【${currentBuild.result}】: ${currentBuild.fullDisplayName}",
                        body: "" +
                                "${currentBuild.fullDisplayName} 构建详情请访问链接： ${env.JENKINS_URL}${env.BLUE_URL}${URLEncoder.encode(env.JOB_NAME, "UTF-8")}/detail/${env.JOB_BASE_NAME}/${env.BUILD_ID}/pipeline \n\n" +
                                "仓库ID: ${params.REPO_ID} \n" +
                                "仓库名: ${(params.REPO_NAME).replace("__", "/")} \n" +
                                "第一次提交所属分支: ${params.GIT_BRANCH} \n" +
                                "构建编号: ${env.BUILD_DISPLAY_NAME} \n" +
                                "构建节点: ${env.NODE_NAME} \n" +
                                "构建结果: ${currentBuild.result} \n" +
                                "构建开始: ${new Date(currentBuild.startTimeInMillis).format('yyyy-MM-dd HH:mm:ss.SSS')} \n" +
                                "构建持续时间: ${currentBuild.durationString} \n" +
                                "构建参数: ${currentBuild.buildVariables} \n" +
                                "描述: ${currentBuild.description} \n" +
                                ""
            }
        }
    }

}