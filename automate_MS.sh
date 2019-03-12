#!/bin/sh
set -e
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"


for key in "$@"
do
case $key in
    --appName=*)
    APP_NAME="${key#*=}"
    shift
    ;;
    --msCount=*)
    MS_CNT="${key#*=}"
    shift
    ;;
    --gitUser=*)
    GIT_USER="${key#*=}"
    shift
    ;;
	--msName=*)
    MS_NAME="${key#*=}"
    shift
    ;;
	--loginToken=*)
    OPENSHIFT_LOGIN_TOKEN="${key#*=}"
    shift
    ;;
	--server=*)
    OPENSHIFT_SERVER="${key#*=}"
    shift
    ;;
	--githubToken=*)
    GITHUB_TOKEN="${key#*=}"
    shift
    ;;
	--ocPath=*)
    OC_PATH="${key#*=}"
    shift
    ;;
esac
done
DEFAULT_APP_NAME=demo
DEFAULT_MS_CNT=1
DEFAULT_GIT_USER=subir0071
DEFAULT_MS_NAME=cart-service
DEFAULT_OPENSHIFT_LOGIN_TOKEN=ZVAKq2Zn2eIErQhMlrJbHo1XNDIxhCB6A8tYkJrepUA
DEFAULT_OPENSHIFT_SERVER=https://masterdnsj2p5wq2nzrzvo.southindia.cloudapp.azure.com:443
DEFAULT_GITHUB_TOKEN=`echo 'NTg4OGYyMjA1YzcwYmUwYzY2ZWQ2NzllYTI4MGJjZjJkODYzNDU5MQ==' | base64 --decode`

export APP_NAME=${APP_NAME:-${DEFAULT_APP_NAME}}
export MS_CNT=${MS_CNT:-${DEFAULT_MS_CNT}}
export GIT_USER=${GIT_USER:-${DEFAULT_GIT_USER}}
export MS_NAME=${MS_NAME:-${DEFAULT_MS_NAME}}
export OPENSHIFT_LOGIN_TOKEN=${OPENSHIFT_LOGIN_TOKEN:-${DEFAULT_OPENSHIFT_LOGIN_TOKEN}}
export OPENSHIFT_SERVER=${OPENSHIFT_SERVER:-${DEFAULT_OPENSHIFT_SERVER}}
export GITHUB_TOKEN=${GITHUB_TOKEN:-${DEFAULT_GITHUB_TOKEN}}



oc login $OPENSHIFT_SERVER --token=$OPENSHIFT_LOGIN_TOKEN --insecure-skip-tls-verify=true
oc new-project ${APP_NAME,,}-cicd
oc new-app -f sonarqube-ephemeral-template.json -n ${APP_NAME,,}-cicd
SONAR_URL='http://'`oc get route/sonar | tr -s ' ' | cut -d ' ' -f2|tail -1`

curl -k -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user/repos -d '{"name":"'$MS_NAME'","description":"This repo created by acclerator"}'

mkdir -p ./ref_repo/$MS_NAME
cp -r ref_repo/spring-boot-mongodb-template/* ref_repo/$MS_NAME/
cp jenkins_config.yaml ref_repo/$MS_NAME/

cat << EOF > ./ref_repo/$MS_NAME/properties.yml
APP_NAME: ${APP_NAME,,}
MS_NAME: $MS_NAME
BRANCH: master
GIT_SOURCE_URL: https://github.com/$GIT_USER/$MS_NAME.git
SONAR_HOST_URL: $SONAR_URL
EOF

cd ref_repo/$MS_NAME/
git config --global user.email "accelerator@openshiftplusplus.com"
git config --global user.name "Accelerator"
git init
git add .
git commit -m "initial commit"
git remote add origin https://$GIT_USER:$GITHUB_TOKEN@github.com/$GIT_USER/$MS_NAME.git
git push origin master
cd ../..

oc new-app -f jenkins_template.json -e INSTALL_PLUGINS=configuration-as-code-support,credentials:2.1.16,matrix-auth:2.3,sonar,nodejs,ssh-credentials,jacoco -e CASC_JENKINS_CONFIG=https://raw.githubusercontent.com/$GIT_USER/$MS_NAME/master/jenkins_config.yaml -e OVERRIDE_PV_PLUGINS_WITH_IMAGE_PLUGINS=true -n ${APP_NAME,,}-cicd

oc new-project ${APP_NAME,,}-dev
oc new-project ${APP_NAME,,}-test
oc new-project ${APP_NAME,,}-prod

oc new-app mongo:3.4 --name=orders-db -n ${APP_NAME,,}-cicd  # need to change the db name to parameterized in next release
oc new-app mongo:3.4 --name=orders-db -n ${APP_NAME,,}-dev
oc new-app mongo:3.4 --name=orders-db -n ${APP_NAME,,}-test
oc new-app mongo:3.4 --name=orders-db -n ${APP_NAME,,}-prod

oc policy add-role-to-user system:image-puller system:serviceaccount:${APP_NAME,,}-test:default -n ${APP_NAME,,}-dev
oc policy add-role-to-user system:image-puller system:serviceaccount:${APP_NAME,,}-prod:default -n ${APP_NAME,,}-dev

oc policy add-role-to-user edit system:serviceaccount:${APP_NAME,,}-cicd:jenkins -n ${APP_NAME,,}-dev
oc policy add-role-to-user edit system:serviceaccount:${APP_NAME,,}-cicd:jenkins -n ${APP_NAME,,}-test
oc policy add-role-to-user edit system:serviceaccount:${APP_NAME,,}-cicd:jenkins -n ${APP_NAME,,}-prod


oc new-app https://github.com/$GIT_USER/$MS_NAME.git --strategy=pipeline --name=${APP_NAME,,}app-pipeline -n ${APP_NAME,,}-cicd

rm -rf ref_repo/$MS_NAME

