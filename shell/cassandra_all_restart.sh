#!/bin/bash

KEY_NAME="operator.pem"
KEY_FILE=${JENKINS_HOME}/${KEY_NAME}
DATE=`date +'%Y%m%d%H%M'`
JAVA_HOME="/usr/java/latest" 
OPERATION_USER="operator"
CASSANDRA_USER="cassandra"
CASSANDRA_LOG="/var/log/cassandra/cassandra.log"
NODETOOL="/usr/local/cassandra/bin/nodetool" 
SSH_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

##SERVER LISTをnodetool ringの情報を元にsortして作成します。

TMP_LIST=(`${NODETOOL} -h 192.168.1.1 ring| grep 192.168 | awk '{print $1}'`)
TMP_LIST_LAST_NUM=`expr ${#TMP_LIST[*]} - 1`
SORT_LIST=()
SKIP_NUM="3"
SEQ_LAST_NUM=`expr $SKIP_NUM - 1`
 
 
for t in `seq 0 $SEQ_LAST_NUM`
do
    for i in `seq $t $SKIP_NUM $TMP_LIST_LAST_NUM`
    do
        SORT_LIST+=(${TMP_LIST[$i]})
    done
done
#LAST NUM にいれた数までの配列にします。10台しかやりたくない時は10-1=9をLAST_NUMに入れて下さい。
START_NUM="0"
LAST_NUM="9"
LAST_LIST=()
for t in `seq ${START_NUM} ${LAST_NUM}`
do
    LAST_LIST+=(${SORT_LIST[$t]})
done
SORT_LIST=("${LAST_LIST[@]}")
SERVER_LIST=(${SORT_LIST[@]})

echo "実行するのは${SERVER_LIST[@]}です"


before_restart(){
    HOST=$1

    ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST} "sudo -s ${NODETOOL} -h ${HOST} disablethrift && sleep 10 && sudo -s ${NODETOOL} -h ${HOST} disablegossip && sleep 10" 
    if [ $? -eq 0 ];
    then
        echo "nodetool disablethrift OK!!"
    else
        echo "nodetool disablethrift NG!! This host cassandra restart & job stop!!!!"
        ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${SERVER} "sudo -s /etc/init.d/cassandra stop"
        sleep 10
        ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${SERVER} "sudo -s /etc/init.d/cassandra start"
        exit 1
    fi

    sleep 10

    ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST} "sudo -s ${NODETOOL} -h ${HOST} flush"
    if [ $? -eq 0 ];
    then
        echo "nodetool flush OK!!"
    else
        exit 1
    fi

}

after_restart(){
    HOST=$1
    ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST}  "tail -n 2 ${CASSANDRA_LOG}"
    ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST} "sudo -s ${NODETOOL} ring  | grep -w ${HOST}"

    STATUS=`ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST} "sudo -s ${NODETOOL} ring  | grep -w ${HOST} | grep 'Up' | wc -l"`

    if [ ${STATUS} -eq 1 ];
    then
        echo "SERVER RESTART OK ${HOST}" 
    else
        echo "SERVER RESTART NG!! STATUS is ${STATUS}.  AFTER CHECK NG ! EXECUTE STOP!! ${HOST}" 
        exit 1
    fi

    ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${HOST}  "cat ${CASSANDRA_LOG} | grep 'Bootstrap/Replace/Move completed! Now serving reads.'"
}

for SERVER in ${SERVER_LIST[@]};
do
     echo "EXECUTE START!!! ${SERVER}"

     before_restart ${SERVER} && ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${SERVER} "sudo -s /etc/init.d/cassandra stop"
     sleep 5
     echo ${RESTART}
     ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} ${SERVER} "sudo -s /etc/init.d/cassandra start"
    sleep 60
    after_restart ${SERVER}
    if [ $? -eq 0 ];
    then
        echo "EXECUTE OK!!! ${SERVER}" 
    else
        exit 1
    fi

done

ssh ${SSH_OPTIONS} -i ${KEY_FILE} -l ${OPERATION_USER} 192.168.1.1 "sudo -s  ${NODETOOL} ring"
echo "${SERVER_LIST} is all OK"
