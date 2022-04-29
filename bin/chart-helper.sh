#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

debug=0

display_usage() {
    echo "\n${1:-This script must be run with two argument}"
    echo "\nUsage:\n$0 [options] <command> {command specific variables} \n"
    echo "[options]: -d \n"
    echo "  -d : debug flag\n"
    echo "<command>: command to run:\n"
    echo "  gen <chart path>\n"
    echo "  update <chart path> <version>\n"
}

while getopts "h?d" opt; do
    case "${opt}" in
    h)  display_usage
        exit 0
        ;;
    d)  debug=1
        shift "$((OPTIND-1))"
        ;;
    \?) display_usage
        exit 1
        ;;
    esac
done

if [[ $debug -eq 1 ]]; then
    set -x
fi

fn_chartinfo() {
    path=$(readlink -f $1)

    artifact=$(grep artifacthub $path/Chart.yaml | sed 's/  - https:\/\/artifacthub.io\/packages\/helm\///')

    if [[ $artifact != "" ]]; then
        prefix=$(echo $artifact | cut -d / -f 1)
        chart=$(echo $artifact | cut -d / -f 2)
        repo=$(grep repository $path/Chart.yaml | awk '{print $2}')
        appVersion=$(curl --silent -X 'GET' "https://artifacthub.io/api/v1/packages/helm/$prefix/$chart" | jq -r '.app_version')
    else
        chart=$(grep "\- name:" $path/Chart.yaml | awk '{print $3}')
        repo=$(grep repository $path/Chart.yaml | awk '{print $2}')
        prefix=$(helm repo list | grep "$repo" | awk '{print $1}')
        # appVersion=$(curl --silent -X 'GET' "https://artifacthub.io/api/v1/packages/helm/$prefix/$chart" | jq -r '.app_version')
    fi
}

fn_generate() {
    if [[ $# -lt 1 ]]; then
        display_usage
        exit 1
    fi

    fn_chartinfo $1

    helm repo update

    helm show values $prefix/$chart | sed 's/^/  /' | sed "1 i\\$chart:" > $path/values.orig.yaml
    helm show values $prefix/$chart | sed 's/^/  /' | sed "1 i\\$chart:" > $path/values.yaml

    exit 0
}

fn_update() {
    if [[ $# -lt 2 ]]; then
        display_usage
        exit 1
    fi

    fn_chartinfo $1

    sed -i "s/    version: .*$/    version: $2/" $path/Chart.yaml
    sed -i "s/appVersion: .*$/appVersion: $appVersion/" $path/Chart.yaml

    helm repo update

    echo "Diff (old <, new >) :"
    echo "$(helm show values $prefix/$chart --version=$2 | sed 's/^/  /' | sed "1 i\\$chart:" | diff $path/values.orig.yaml -)"

    helm show values $prefix/$chart --version=$2 | sed 's/^/  /' | sed "1 i\\$chart:" > $path/values.new.yaml
    git merge-file --union $path/values.yaml $path/values.orig.yaml $path/values.new.yaml
    mv $path/values.new.yaml $path/values.orig.yaml

    exit 0
}

while [[ "${1}" != "" ]]; do
    case ${1} in
        gen )
            shift 1
            fn_generate $@
            ;;
        update )
            shift 1
            fn_update $@
            ;;
        * )
            display_usage
            exit 1
            ;;
    esac
    shift
done

exit 0