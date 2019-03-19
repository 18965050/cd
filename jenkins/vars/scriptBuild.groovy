/**
 * 自定义脚本 build方式
 * lvchenggang
 * 2018/3/29
 **/
def call(){
    sh """#! /usr/bin/zsh -lie
        source ${WORKSPACE}/jenkinsBuild.sh
       """
}