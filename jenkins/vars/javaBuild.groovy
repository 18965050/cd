/**
 * 标准Java Maven build方式
 * lvchenggang
 * 2018/3/28
 **/
def call() {
    //注意, Jenkins ssh登录并不会加载登录用户的环境变量, 因此此时需要将shebang添加上
    sh '''#!/usr/bin/zsh -lie
        echo "start build"
        mvn clean package -s settings.xml -D maven.test.skip=true -P CD
       '''
}
