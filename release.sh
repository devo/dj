#!/bin/bash

set -ex

# ensure working dir is clean
git status
if [[ -z $(git status -s) ]]
then
  echo "tree is clean"
else
  echo "tree is dirty, please commit changes before running this"
  exit 1
fi

git pull

version_file="main.go"
if [ -z $(grep -m1 -Eo "[0-9]+\.[0-9]+\.[0-9]+" $version_file) ]; then
  echo "did not find semantic version in $version_file"
  exit 1
fi
# https://github.com/treeder/dockers/tree/master/bump
docker run --rm -it -v $PWD:/app -w /app treeder/bump --filename $version_file patch
version=$(grep -m1 -Eo "[0-9]+\.[0-9]+\.[0-9]+" $version_file)
echo "Version: $version"

GOOS=linux go build -o dj_linux
GOOS=darwin go build -o dj_mac
GOOS=windows go build -o dj.exe
docker run --rm -v ${PWD}:/go/src/github.com/devo/dj -w /go/src/github.com/devo/dj golang:alpine go build -o dj_alpine

tag="$version"
git add -u
git commit -m "$version release [skip ci]"
git tag -f -a $tag -m "version $version"
git push
git push origin $tag

# For GitHub
url='https://api.github.com/repos/devo/dj/releases'
output=$(curl -s -u $GH_DEPLOY_USER:$GH_DEPLOY_KEY -d "{\"tag_name\": \"$version\", \"name\": \"$version\"}" $url)
upload_url=$(echo "$output" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["upload_url"]' | sed -E "s/\{.*//")
html_url=$(echo "$output" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["html_url"]')
curl --data-binary "@fn_linux"  -H "Content-Type: application/octet-stream" -u $GH_DEPLOY_USER:$GH_DEPLOY_KEY $upload_url\?name\=fn_linux >/dev/null
curl --data-binary "@fn_mac"    -H "Content-Type: application/octet-stream" -u $GH_DEPLOY_USER:$GH_DEPLOY_KEY $upload_url\?name\=fn_mac >/dev/null
curl --data-binary "@fn.exe"    -H "Content-Type: application/octet-stream" -u $GH_DEPLOY_USER:$GH_DEPLOY_KEY $upload_url\?name\=fn.exe >/dev/null
curl --data-binary "@fn_alpine" -H "Content-Type: application/octet-stream" -u $GH_DEPLOY_USER:$GH_DEPLOY_KEY $upload_url\?name\=fn_alpine >/dev/null