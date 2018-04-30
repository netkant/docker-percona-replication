#!/bin/bash
BASELINE="/tmp/.db-replication-status"
CURRENT="/tmp/.db-replication-status-current"

if [ "${MYSQL_REPLICATION_ROLE}" == "" ]; then
    exit;
fi

if [ "${MYSQL_REPLICATION_ROLE}" == "slave" ]; then
    export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}
    # ...
    STATUS=$(mysql --user=root -e "SHOW SLAVE STATUS \G;" | grep -e "_Running:" -e "Seconds" -e "Slave_" -e "Master_Host")

    # ...
    if [ "${SLACK_CHANNEL}" != "" ]; then
        if [ ! -f ${BASELINE} ]; then
            echo "${STATUS}" > ${BASELINE}
        else
            echo "${STATUS}" > ${CURRENT}

            BASELINE_MD5=$(md5sum ${BASELINE} | cut -d " " -f1)
            CURRENT_MD5=$(md5sum ${CURRENT} | cut -d " " -f1)

            if [ "${BASELINE_MD5}" != "${CURRENT_MD5}" ]; then
                curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Replication status changed to:\n${STATUS}\"}" ${SLACK_CHANNEL} > /dev/null 2>&1
                echo "${STATUS}" > ${BASELINE}
            fi

            rm -rf ${CURRENT}
        fi
    fi

    echo "${STATUS}"
fi
