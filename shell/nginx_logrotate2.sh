#!/bin/sh
#
# This Script rotate logs & gzip logs & delete 7days ago dairy 2:10 by root cron
# script: /usr/local/sbin/nginx_logrotate.sh
# ex) /usr/local/sbin/nginx_logrotate.sh
#
#========================================================================
# Environment
#========================================================================
# Linux Command Environment
PGREPPATH="/usr/bin/pgrep"
ECHO="/bin/echo"
MV="/bin/mv"
MKDIR="/bin/mkdir"
GZIP="/bin/gzip"
RM="/bin/rm"

# Nginx Log Rotate Environment
NGINX_INIT="/etc/init.d/nginx"
EXECUSER="root"
PROCWORD="nginx: master process"
PROCFLG=`${PGREPPATH} -f -u ${EXECUSER} "${PROCWORD}" >/dev/null && ${ECHO} "FOUND" || ${ECHO} "NOTFOUND"`
LOGDATE=`date -d "1 hours ago" +"%Y%m%d_%H"`
LOGDIR="/var/log/nginx/"
LOGOLDDIR="${LOGDIR}/old"
LOGFILES=`ls ${LOGDIR}/*.log | awk -F/ '{print $6}'`

# Nginx Log Delete Environment
GEN=30
DELETEDAY=`date +%Y%m%d --date "${GEN} day ago"`
DELETELOGFILES=`ls ${LOGOLDDIR}/*.log.${DELETEDAY}_*.gz | awk -F/ '{print $7}'`

# Rotate nginx logs

if [ ! -e ${LOGOLDDIR} ]; then
  ${ECHO} "${LOGOLDDIR} doesn't exist. making directory ..."
  ${MKDIR} ${LOGOLDDIR} &
  ${ECHO} "done."
  else
  ${ECHO} "${LOGOLDDIR} already exist."
fi

for logname in ${LOGFILES}
do
  if [ -f ${LOGDIR}/${logname} ]; then
    ${ECHO} "now moving ${logname}.${LOGDATE}..."
    ${MV} ${LOGDIR}/${logname} ${LOGOLDDIR}/${logname}.${LOGDATE} &
    ${ECHO} "done."
  else
    ${ECHO} "${logname} doesn't exist"
  fi
done

# Nginx Reload

if [ "x${PROCFLG}" == "xFOUND"  ]; then
  ${ECHO} "now reloading nginx..."
  #${NGINX_INIT} reload
  [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
else
  ${ECHO} "nginx process not found."
fi

# Gzip nginx old logs

LOGOLDFILES=`ls ${LOGOLDDIR}/*.log.${LOGDATE} | awk -F/ '{print $7}'`
echo  ${LOGOLDFILES}

for gzfile in ${LOGOLDFILES}
do
  if [ -f ${LOGOLDDIR}/${gzfile} ]; then
    ${ECHO} "now gzip ${gzfile}..."
    ${GZIP} ${LOGOLDDIR}/${gzfile} &
    ${ECHO} "done."
  else
    ${ECHO} "${gzfile} doesn't exist"
  fi
done

# Delete nginx logs 30days ago

echo $DELETELOGFILES

for deletelogname in $DELETELOGFILES
do
  if [ -f ${LOGOLDDIR}/${deletelogname} ]; then
    ${ECHO} "now deleting ${deletelogname}"
    ${RM} -f ${LOGOLDDIR}/${deletelogname}
   ${ECHO} "done."
  else
    ${ECHO} "${deletelogname} doesn't exist"
  fi
done

