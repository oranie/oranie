#!/bin/bash

CH=(web_hoge web_fuga )

THIS_MON=`date +"%Y-%m" `
LAST_MON=`date +"%Y-%m" -d "1 month ago"`
LAST_YEAR=`date +"%Y" -d "1 month ago"`

DIR="/data/work/${LAST_YEAR}"
SHELL_LOG="/data/work/result.log"


#作業ディレクトリのチェック
if [ ! -d ${DIR} ]
then
    mkdir -p ${DIR}
fi

if [ ! -d "/data/tmp" ]
then
    mkdir -p /data/tmp
fi
cd /data/tmp/

#シェルのログ取得
put_log_start(){
    echo `date` >> ${SHELL_LOG}
    echo "start" >> ${SHELL_LOG}
    return 0
}

put_log_end(){
    echo `date` >> ${SHELL_LOG}
    echo "end" >> ${SHELL_LOG}
    return 0
}

echo "" > ${SHELL_LOG}

log_parse(){
    egrep -v '_Mod-Status|nagios|192.168.' |\
    awk -F'"' '{print $1 $2 $3 $NF}'|\
    sed -e 's/^- \|192.168.210.2[0-9][0-9]\|[0-9].* - - \| HTTP\/[0-9].[0-9]\|\[\|\]\|+0900//g' |\
    sed -e 's/,//g'|\
    sed -e 's/ \+/,/g'
}

log_check(){
   TEXT=$1 
   for i in 1..6
   do 
       $t=`expr $i -1`
       TEST[$t]=echo $TEXT | cut -d , -f $i
   done 
}


for SERVER in ${CH[*]}
do
       SERVER_NAME=`echo ${SERVER} | sed 's/\/\[0-1\]\[0-9\]\///'`
       LOG_FILE="all_${SERVER_NAME}_acccess_${LAST_MON}.log"
       put_log_start
       zip_list=$(find /data/server -name "access_log.${LAST_MON}-*.zip"| grep -e ${SERVER}| sort)
       for FILE in ${zip_list[*]}
       do
           echo $FILE >> /data/work/result.log
           zcat $FILE | log_parse >> ${DIR}/${SERVER_NAME}/${LOG_FILE}
       done
       gzip ${DIR}/${SERVER_NAME}/${LOG_FILE}
       rm -f ${DIR}/${SERVER_NAME}/${LOG_FILE}
       put_log_end
done

