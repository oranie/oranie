#!/bin/bash

NGINX_DIR="/usr/local/nginx/logs"
ACCESS_LOG="access.log"
ERROR_LOG="error.log"

DATE=`date '+%Y%m%d%H%M'`
RENAME_ACCESS_LOG="${ACCESS_LOG}_${DATE}"
RENAME_ERROR_LOG="${ERROR_LOG}_${DATE}"

test -e ${NGINX_DIR}/nginx.pid && mv ${NGINX_DIR}/${ACCESS_LOG} ${NGINX_DIR}/${RENAME_ACCESS_LOG} &&
mv ${NGINX_DIR}/${ERROR_LOG}  ${NGINX_DIR}/${RENAME_ERROR_LOG} 


/bin/kill -USR1 `/bin/cat ${NGINX_DIR}/nginx.pid 2>/dev/null` 2>/dev/null 

sleep 10
/usr/bin/gzip ${NGINX_DIR}/${RENAME_ACCESS_LOG}
/usr/bin/gzip ${NGINX_DIR}/${RENAME_ERROR_LOG}

#old log erase
find ${NGINX_DIR} -type f -name "*.gz" -mtime +31 | xargs rm -f
