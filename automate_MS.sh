#!/bin/sh

set -e

source ./automate_MS.properties

oc login https://master.na39.openshift.opentlc.com --token=$OPENSHIFT_LOGIN_TOKEN
oc new-project ${APP_NAME,,}-cicd
oc new-app -f sonarqube-ephemeral-template.json
SONAR_URL='http://'`oc get route/sonar | tr -s ' ' | cut -d ' ' -f2|tail -1`

curl -u $GIT_USER:$GIT_PASS https://api.github.com/user/repos -d '{"name":"'$MS_NAME'","description":"This repo created by acclerator"}'

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
git config --global user.name "$GIT_USER"
git config --global user.password "GIT_PASS"
git init
git remote add origin https://github.com/$GIT_USER/$MS_NAME.git
git add .
git commit -m "initial commit"
git push origin master

cd ../..
oc new-app -f jenkins_template.json -e INSTALL_PLUGINS=credentials,matrix-auth,configuration-as-code-support,sonar,nodejs,ssh-credentials -e CASC_JENKINS_CONFIG=https://raw.githubusercontent.com/$GIT_USER/$MS_NAME/master/jenkins_config.yaml

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

