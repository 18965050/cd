/**
 * yarn js build方式
 * lvchenggang
 * 2019/2/12
 **/
def call() {
    sh '''#!/usr/bin/zsh -lie
        echo "start build"
        npm set registry http://192.168.51.44
        yarn install
        yarn run build
       '''
}