#!/bin/sh

echo -n "Enter Application Name :"
read APP_NAME
echo -n "Enter Number of Microservice :"
read MS_CNT
echo -n "Enter Github user (Will be used to create new Repository):"
read GIT_USER
echo -n "Enter Github password :"
read GIT_PASS
#idx = 0
#while [ $idx -lt $MS_CNT ]
#do
  echo -n "Enter microservice name :"
  read MS_NAME
#done
echo "git repo name :" $MS_NAME
oc new-project ${APP_NAME,,}-cicd
oc project ${APP_NAME,,}"-cicd"
oc new-app -f jenkins_template.json -e INSTALL_PLUGINS=credentials,matrix-auth,configuration-as-code-support,sonar,nodejs,ssh-credentials -e CASC_JENKINS_CONFIG="jenkins_config.yamal"

curl -u $GIT_USER:$GIT_PASS https://api.github.com/user/repos -d '{"name":"'$MS_NAME'","description":"This repo created by acclerator"}'

mkdir -p ./ref_repo/$MS_NAME
cp -r ref_repo/springboot_template/* ref_repo/$MS_NAME/
cd ref_repo/$MS_NAME/
git config --global user.name "$GIT_USER"
git config --global user.password "GIT_PASS"
git init 
git remote add origin https://github.com/$GIT_USER/$MS_NAME.git
git push origin master


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

oc new-app https://github.com/$GIT_USER/$MS_NAME.git --strategy=pipeline --name=spring-pipeline -n ${APP_NAME,,}-cicd
#curl https://api.github.com -u $GIT_USER:$GIT_PASS

#mkdir -p ref_repo
#git clone https://github.com/fmarchioni/mastertheboss.git  --separate-git-dir=spring/demo-spring-boot

#git remote add origin git@github.com:$GIT_USER/${MS_NAME_0}.git
#git push -u origin master
