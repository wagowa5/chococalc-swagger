#!/bin/sh
set -eu

# git setting
git config --global user.name github-actions
git config --global user.email noreply@github.com

export GIT_BRANCH="$(git symbolic-ref HEAD --short 2>/dev/null)"
if [ "$GIT_BRANCH" = "" ] ; then
  GIT_BRANCH="$(git branch -a --contains HEAD | sed -n 2p | awk '{ printf $1 }')";
  export GIT_BRANCH=${GIT_BRANCH#remotes/origin/};
fi

git remote set-url origin https://${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git
git checkout $GIT_BRANCH

# バージョンが上がればv*.*.*を変更する
(cd ./bin && curl -O https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/6.2.1/openapi-generator-cli-6.2.1.jar && cd ..)


# OpenAPI Generate
export JAR_PATH=./bin/openapi-generator-cli-6.2.1.jar

## remove old generated code
rm -rf \
  kotlin-spring \
  typescript \
  dist

## generate merged oas.yaml
java -jar ${JAR_PATH} generate \
	-i ./src/host.yaml \
  -g openapi-yaml \
	-o ./dist

## validation
#java -jar ${JAR_PATH} validate 
#  -i ./dist/openapi/openapi.yaml

## generate kotlin-spring
java -jar ${JAR_PATH} generate \
  -i ./dist/openapi/openapi.yaml \
  -g kotlin-spring \
  -o kotlin-spring \
#  -t ./config/spring/mustache \
  --enable-post-process-file \
  -p useBeanValidation=true \
  -p serializationLibrary=moshi \
  -p moshiCodeGen=true \
  -p enumPropertyNaming=UPPERCASE \
  -p sortParamsByRequiredFlag=true \
  -p sortModelPropertiesByRequiredFlag=true \
  -p dateLibrary=java8 \
  -p requestDateConverter=toJson \
  -p useTags=true \
  -p gradleBuildFile=false \
  -p packageName=org.openapitools.spring \
  --skip-validate-spec
#java -jar ${JAR_PATH} generate \
#  -i ./dist/openapi/openapi.yaml \
#  -g org.openapitools.codegen.languages.KotlinSpringServerCodegen \
#  -t ./config/spring/mustache \
#  -c ./config/spring/config.yaml \
#  -o ./kotlin-spring \
#  --skip-validate-spec

rm -rf kotlin-spring/docs \
  kotlin-spring/build.gradle.kts \
  kotlin-spring/pom.xml \
  kotlin-spring/settings.gradle \
  kotlin-spring/src/main/resources \
  kotlin-spring/src/main/kotlin/org/openapitools/Application.kt \
  kotlin-spring/src/main/kotlin/org/openapitools/spring/apis/ApiUtil.kt \
  kotlin-spring/src/test

## generate typescript
java -jar ${JAR_PATH} generate \
  -i ./dist/openapi/openapi.yaml \
  -g typescript-axios \
  -t ./config/typescript/mustache \
  -o typescript

## remove all README.md
find kotlin-spring typescript -name "README.md" | xargs rm

# ignore no diff
set +e
git add .
git commit -m "add generated code"
git push origin $GIT_BRANCH
echo 'finish code-gen...'
