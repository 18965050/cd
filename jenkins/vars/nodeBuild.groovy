/**
 * node js build方式
 * lvchenggang
 * 2018/3/29
 **/
def call() {
    sh '''#!/usr/bin/zsh -lie
        echo "start build"
        npm set registry http://192.168.51.44
        npm install
        npm run build
       '''
}