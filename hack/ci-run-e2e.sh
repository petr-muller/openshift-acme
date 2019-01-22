#!/usr/bin/env bash
set -eEuxo pipefail
#trap "sleep infinity" ERR

env

oc create route edge test --service a --port 8080 && oc get route test -o yaml

sleep infinity

#ngrok=$( which ngrok || true)
#if [ -z ${ngrok} ]; then
#    bin=$( mktemp -d)
#    curl -L https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip | bsdtar -xvf- -C ${bin} && chmod +x ${bin}/ngrok
#    ngrok=${bin}/ngrok
#fi
#
#logfile=$( mktemp )
#${ngrok} http -log stdout -log-level debug -log-format json 5000 > ${logfile} &
#
#export TEST_DOMAIN=$( tail -n +0 -f ${logfile} | grep --text -m 1 'Hostname' | sed -r 's/.*Hostname:([^] ]*).*/\1/') || [[ $? == 141 ]]
#echo "TEST_DOMAIN: '${TEST_DOMAIN}'"

export TEST_DOMAIN=$( cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1 || [[ $? == 141 ]] ).serveo.net
source "$(dirname "${BASH_SOURCE[0]}")/lib/nss_wrapper.sh"
nss_wrapper $( mktemp -d )
ssh -o StrictHostKeyChecking=no -R ${TEST_DOMAIN}:80:localhost:5000 serveo.net &

oc port-forward -n default dc/router 5000:80 &

oc get projects

# Deploy
project=acme-$( cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1 || [[ $? == 141 ]] )
oc new-project ${project}
oc adm pod-network make-projects-global ${project} || true
export DELETE_ACCOUNT_BETWEEN_STEPS_IN_NAMESPACE=${project}

oc create -fdeploy/letsencrypt-staging/cluster-wide/imagestream.yaml
oc tag -d openshift-acme:latest
oc tag registry.svc.ci.openshift.org/${OPENSHIFT_BUILD_NAMESPACE}/pipeline:openshift-acme openshift-acme:latest

tmpFile=$( mktemp )
oc create -fdeploy/letsencrypt-staging/cluster-wide/{clusterrole,serviceaccount,deployment}.yaml
oc adm policy add-cluster-role-to-user openshift-acme -z openshift-acme

timeout 10m oc rollout status deploy/openshift-acme

make -j64 test-extended GOFLAGS="-v -race"
