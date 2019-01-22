#!/usr/bin/env bash
set -eEuxo pipefail
trap "sleep infinity" ERR

# Deploy
project=acme-$( cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1 || [[ $? == 141 ]] )
oc new-project ${project}
oc adm pod-network make-projects-global ${project} || true

#FIXME:remove test
curl $( oc get route test -o go-template --template={{.spec.host}} )

export TEST_DOMAIN=""
# Likely not needed given we get unique domains in each namespace
export DELETE_ACCOUNT_BETWEEN_STEPS_IN_NAMESPACE=${project}

oc create -fdeploy/letsencrypt-staging/cluster-wide/imagestream.yaml
oc tag -d openshift-acme:latest
oc tag registry.svc.ci.openshift.org/${OPENSHIFT_BUILD_NAMESPACE}/pipeline:openshift-acme openshift-acme:latest

tmpFile=$( mktemp )
oc create -fdeploy/letsencrypt-staging/cluster-wide/{clusterrole,serviceaccount,deployment}.yaml
oc adm policy add-cluster-role-to-user openshift-acme -z openshift-acme

timeout 10m oc rollout status deploy/openshift-acme

make -j64 test-extended GOFLAGS="-v -race"
