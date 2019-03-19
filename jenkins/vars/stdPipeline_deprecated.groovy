/**
 *
 * lvchenggang
 * 2018/3/27
 **/

def call(Map pipelineParams) {
    def distFileName = '';  // 预定义发布文件名
    def distExist = false; // 要构建发布的文件是否存在（已构建过）
    def skipBuild = false; // 是否跳过 build 相关阶段

    def GIT_HASH, GIT_NAME, GIT_EMAIL; // git 相关信息

    pipeline {
        agent { label "${pipelineParams.agentLabel}" }

        parameters {
            booleanParam(name: 'FORCE_BUILD', defaultValue: false, description: '如果已存在包，仍强制编译')
        }

        options {
            timeout(time: 20, unit: 'MINUTES')
        }

        environment {
            APP_NAME = "${pipelineParams.appName}"
            APP_OUT = "${pipelineParams.appOut}"
            DIST_DIR = 'dist'
            TERM = 'linux'
            RSYNC_HOST = '192.168.16.63'
            RSYNC_PATH = 'xyz_p_test'
            RSYNC_PASS = 'xyzrsync'
            TEMP_GIT_FILE_NAME = 'tempGitInfo.txt'
            TEMP_DIST_EXIST_FILE_NAME = 'tempDistExist.txt'
            RUNDECK_URI = 'http://192.168.56.98:4440'
            RUNDECK_USERNAME = 'rundeck_admin_for_ci'
            RUNDECK_PASSWORD = 'passwordushouldnotuse'
            RUNDECK_DOC_JOBID='69cf7bae-4ee9-46b7-9380-cf7352d414d2'
        }

        stages {
            stage('预处理') {
                steps {
                    // 将构建对应的 hash 提取为变量
                    //注意: 三个单引号中的变量为shell变量
                    sh '''
                        git clean -ffdx
                        hash=$(git rev-parse HEAD)
                        gitName=$(git --no-pager show -s --format='%an' $hash)
                        gitEmail=$(git --no-pager show -s --format='%ae' $hash)
                        hashName=${hash}.tar.gz
                        echo ${hashName},${gitName},${gitEmail} > ${TEMP_GIT_FILE_NAME}
                        rs=$((wget --spider http://${RSYNC_HOST}/${RSYNC_PATH}/${APP_NAME}/${hashName} && echo "suc") || echo "failed")
                        echo ${rs} > ${TEMP_DIST_EXIST_FILE_NAME}
                      '''
                    script {
                        def temp = readFile(env.TEMP_GIT_FILE_NAME).trim()
                        (GIT_HASH, GIT_NAME, GIT_EMAIL) = temp.split(',')
                        distFileName = GIT_HASH
                        def distExistStatus = readFile(env.TEMP_DIST_EXIST_FILE_NAME).trim()
                        if ('suc' == distExistStatus) { // 文件存在
                            distExist = true
                            if (!params.FORCE_BUILD) {
                                // 发布情况下，文件已存在，且没选择强制编译，这时候才跳过 build
                                skipBuild = true
                            }
                        }
                    }
                }
                post {
                    always {
                        // 输出变量定义，并清理临时的文件
                        //注意: 三个双引号中的变量为Jenkins变量, 这里不能使用三个单引号
                        sh """
                          echo  "发布文件名 : ${distFileName}"
                          echo  "GIT_NAME : ${GIT_NAME}"
                          echo  "GIT_EMAIL : ${GIT_EMAIL}"
                          echo  "该文件是否已存在 : ${distExist}"
                          echo  "本地是否跳过构建 : ${skipBuild}"
                          echo  "BUILD_URL: ${env.BUILD_URL}"
                          echo  "BRANCH_NAME: ${env.BRANCH_NAME}"
                          echo  "CHANGE_ID: ${env.CHANGE_ID}"
                          echo  "CHANGE_URL: ${env.CHANGE_URL}"
                          echo  "CHANGE_TITLE: ${env.CHANGE_TITLE}"
                          echo  "CHANGE_AUTHOR: ${env.CHANGE_AUTHOR}"
                          echo  "CHANGE_AUTHOR_DISPLAY_NAME: ${env.CHANGE_AUTHOR_DISPLAY_NAME}"
                          echo  "CHANGE_AUTHOR_EMAIL: ${env.CHANGE_AUTHOR_EMAIL}"
                          echo  "CHANGE_TARGET: ${env.CHANGE_TARGET}"
                          echo  "BUILD_ID: ${env.BUILD_ID}"
                          echo  "BUILD_DISPLAY_NAME: ${env.BUILD_DISPLAY_NAME}"
                          echo  "JOB_NAME: ${env.JOB_NAME}"
                          echo  "JOB_BASE_NAME: ${env.JOB_BASE_NAME}"
                          echo  "BUILD_TAG: ${env.BUILD_TAG}"
                          echo  "NODE_NAME: ${env.NODE_NAME}"
                          echo  "result: ${currentBuild.result}"
                          echo  "displayName: ${currentBuild.displayName}"
                          echo  "fullDisplayName: ${currentBuild.fullDisplayName}"
                          echo  "timeInMillis: ${currentBuild.timeInMillis}"
                          echo  "startTimeInMillis: ${currentBuild.startTimeInMillis}"
                          echo  "durationString: ${currentBuild.durationString}"
                          echo  "absoluteUrl: ${currentBuild.absoluteUrl}"
                          echo  "description: ${currentBuild.description}"
                        """
                    }
                }
            }

            stage('构建') {
                when { expression { return !skipBuild } }
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
                when { expression { return !skipBuild } }
                steps {
                    sh """
                        if [ ${APP_OUT} != ${DIST_DIR} ]; then
                            mv ${APP_OUT} ${DIST_DIR}
                        fi
                        tar -zcf ${distFileName} ${DIST_DIR}
                        RSYNC_PASSWORD=${RSYNC_PASS} rsync -vzrtopg -C --delete --include=* ${distFileName} root@${RSYNC_HOST}::${RSYNC_PATH}/${APP_NAME}/
                        branch=`echo ${BRANCH_NAME} | sed 's/\\\\//___/g'`
                        if [ -n \${branch} ];then 
                            mv ${distFileName} \${branch}.tar.gz && RSYNC_PASSWORD=${RSYNC_PASS} rsync -vzrtopg -C --delete --include=* \${branch}.tar.gz root@${RSYNC_HOST}::${RSYNC_PATH}/${APP_NAME}/ 
                        fi
                      """
                }
            }

            stage('部署') {
                when { allOf { environment name: 'APP_NAME', value: 'doc'; expression { return !skipBuild } } }
                steps {
                    sh """
                    echo "开始部署${APP_NAME}..."
                    curl -D - -X "POST" -H "Content-Type: application/x-www-form-urlencoded" -H "Cache-Control: no-cache" -d "j_username=${RUNDECK_USERNAME}&j_password=${RUNDECK_PASSWORD}" --cookie-jar rd_cookie "${RUNDECK_URI}/j_security_check"
                    curl -D - -X "POST" -H "Content-Type: application/json" \
                    -d "{ \
                        \\"logLevel\\":\\"INFO\\", \
                        \\"filter\\":\\"hostname:192.168.56.89\\", \
                        \\"argString\\":\\"-APP_NAME doc -DELIVERY_FILE_URL http://${RSYNC_HOST}/${RSYNC_PATH}/${APP_NAME}/master.tar.gz\\"} \
                    }" \
                    --cookie "@rd_cookie" "${RUNDECK_URI}/api/1/job/${RUNDECK_DOC_JOBID}/run"
                    """
                }
            }
        }

        post {
            failure {
                mail to: "${GIT_EMAIL}",
                        subject: "构建结果【${currentBuild.result}】: ${currentBuild.fullDisplayName}",
                        body: "" +
                                "${currentBuild.fullDisplayName} 构建详情请访问链接： ${env.JENKINS_URL}${env.BLUE_URL}${(env.JOB_NAME).split('/')[0]}/detail/${env.JOB_BASE_NAME}/${env.BUILD_ID}/pipeline \n\n" +
                                "分支: ${env.BRANCH_NAME} \n" +
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