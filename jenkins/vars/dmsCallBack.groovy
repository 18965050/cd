def call(Map callbackParam) {
    script {
        //noinspection GroovyAssignabilityCheck
        def jsonParam = """
            {
              "jenkinsBuildStep": ${callbackParam.step},
              "jenkinsBuildAllStatus": "${callbackParam.status}",
              "artifactUrl": "${callbackParam.artifactUrl}",
              "buildUrl": "${env.BUILD_URL}",
              "changeId": "${env.CHANGE_ID}",
              "changeUrl": "${env.CHANGE_URL}",
              "changeTitle": "${env.CHANGE_TITLE}",
              "changeAuthor": "${env.CHANGE_AUTHOR}",
              "changeTarget": "${env.CHANGE_TARGET}",
              "jenkindBuildId": "${env.BUILD_ID}",
              "jenkindBuildDisplayName": "${env.BUILD_DISPLAY_NAME}",
              "JOB_NAME": "${env.JOB_NAME}",
              "JOB_BASE_NAME": "${env.JOB_BASE_NAME}",
              "BUILD_TAG": "${env.BUILD_TAG}",
              "NODE_NAME": "${env.NODE_NAME}",
              "result": "${currentBuild.result}",
              "displayName": "${currentBuild.displayName}",
              "fullDisplayName": "${currentBuild.fullDisplayName}",
              "timeInMillis": "${currentBuild.timeInMillis}",
              "startTimeInMillis": "${currentBuild.startTimeInMillis}",
              "durationString": "${currentBuild.durationString}",
              "absoluteUrl": "${currentBuild.absoluteUrl}",
              "description": "${currentBuild.description}"
            }
        """
        httpRequest acceptType: 'APPLICATION_JSON_UTF8', contentType: 'APPLICATION_JSON_UTF8', httpMode: 'PUT', requestBody: jsonParam, url: "${callbackParam.url}"
    }
}