#!/usr/bin/env ksh
PATH=/usr/local/bin:${PATH}
IFS_DEFAULT="${IFS}"

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="1.0.0"
APP_WEB="http://www.sergiotocalini.com.ar/"
PID_FILE="/var/run/keepalived.pid"
TIMESTAMP=`date '+%s'`
CACHE_DIR=${APP_DIR}/tmp
CACHE_TTL=10                                      # IN MINUTES
#
#################################################################################

#################################################################################
#
#  Load Oracle Environment
# -------------------------
#
[ -f ${APP_DIR}/${APP_NAME%.*}.conf ] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Query arguments."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -p            Specify the auth_pass to connect to the databases."
    echo "  -s ARG(str)   Query to PostgreSQL."
    echo "  -u            Specify the auth_user to connect to the databases (default=postgres)."
    echo "  -v            Show the script version."
    echo "  -U            Specify a unix user to execute the sentences (default=postgres)."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

zabbix_not_support() {
    echo "ZBX_NOTSUPPORTED"
    exit 1
}
#
#################################################################################

#################################################################################
while getopts "s::a:sj:uphvt:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=(${OPTARG})
	    IFS="${IFS_DEFAULT}"
            ;;
	a)
	    param=${OPTARG//p=}
	    [[ -n ${param} ]] && SQL_ARGS[${#SQL_ARGS[*]}]=${param}
	    ;;
	v)
	    version
	    ;;
        \?)
            exit 1
            ;;
    esac
done

refresh_cache() {
    [[ -d ${CACHE_DIR} ]] || mkdir -p ${CACHE_DIR}
    file="${CACHEDIR}/data.json"
    [[ -f "${file}" ]] || touch "${file}"
    if [[ $(( `stat -c '%Y' "${file}" 2>/dev/null`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	[[ -f "${PID_FILE}" ]] || zabbix_not_support
	sudo kill -USR1 $(cat "${PID_FILE}")
	sudo kill -USR2 $(cat "${PID_FILE}")
	sudo cp /tmp/keepalived.{data,stats} "${CACHEDIR}"
	[[ -f "${CACHEDIR}/keepalived.{data,stats}" ]] || zabbix_not_support 
	content_data=`cat ${CACHEDIR}/keepalived.data`
	content_stats=`cat ${CACHEDIR}/keepalived.stats`
	while read line; do
	    
	done < <(echo "${content_data}" | grep "VRRP Instance" | awk -F'=' '{print $2}')
    fi
    echo "${file}"
}

refresh_cache
if [[ "${SECTION}" =~ (vrrp_instances) ]]; then
    rcode="${?}"
else
    zabbix_not_support
fi

if [[ ${JSON} -eq 1 ]]; then
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
       if [[ ${line} != '' ]]; then
            IFS="|" values=(${line})
            output='{ '
            for val_index in ${!values[*]}; do
               output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
               if (( ${val_index}+1 < ${#values[*]} )); then
                     output="${output}, "
	       fi
            done
            output+=' }'
	    if (( ${count} < `echo ${rval}|wc -l` )); then
	       output="${output},"
            fi
            echo "      ${output}"
	fi
        let "count=count+1"
    done <<< ${rval}
    echo '   ]'
    echo '}'
else
    echo "${rval:-0}"
fi

exit ${rcode}
