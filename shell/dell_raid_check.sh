#!/bin/bash

#DELLサーバでRAIDと物理Diskをチェックして、OK以外の文字列があればエラーにします

PHYSICAL=`/opt/dell/srvadmin/bin/omreport storage pdisk controller=0| grep ^Status | grep -v Ok |wc -l`
VIRTUAL=`/opt/dell/srvadmin/bin/omreport storage vdisk controller=0 | grep ^Status | grep -v Ok |wc -l`

DISK=($PHYSICAL $VIRTUAL)

HOST=`hostname`
MAIL_TITLE="$HOST DELL SERVER DISK FAIL!!!!! "
MAIL_ADDRESS="hogehoge@example.com"

for (( i = 0 ; i < ${#DISK[@]}; i++ ))
do
    if [ ${DISK[$i]} -eq 0 ]
    then
        echo "Disk OK!"
    else
        echo "Disk NG!!"
        body=`/opt/dell/srvadmin/bin/omreport storage pdisk controller=0 && /opt/dell/srvadmin/bin/omreport storage vdisk controller=0`
        echo "Disk NG!!!!!!!! $body" | /bin/mail -s "${MAIL_TITLE} "  ${MAIL_ADDRESS}
        exit
    fi
done


