#!/bin/bash
function nss_wrapper() {
    local user_id=$(id -u)
    local group_id=$(id -g)
    
    if [ "${user_id}" != "0" ]; then
        NSS_WRAPPER_PASSWD=${1}/passwd
        NSS_WRAPPER_GROUP=/etc/group
    
        cp /etc/passwd ${NSS_WRAPPER_PASSWD}
        echo "default:x:${user_id}:${group_id}:Default Application User:${1}:/sbin/nologin" >> ${NSS_WRAPPER_PASSWD}
    
        export NSS_WRAPPER_PASSWD
        export NSS_WRAPPER_GROUP
        export LD_PRELOAD=libnss_wrapper.so
    fi
}
