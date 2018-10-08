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

refresh_cache() {
    [[ -d ${CACHE_DIR} ]] || mkdir -p ${CACHE_DIR}
    file="${CACHE_DIR}/data"
    if [[ ! -f "${file}" ]]; then 
        touch -d "$(( ${CACHE_TTL}+1 )) minutes ago" "${file}"
    fi

    if [[ $(( `stat -c '%Y' "${file}" 2>/dev/null`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	[[ -f "${PID_FILE}" ]] || return 1
	sudo kill -USR1 $(cat "${PID_FILE}")
	sudo kill -USR2 $(cat "${PID_FILE}")
	[[ -f "/tmp/keepalived.data" && -f "/tmp/keepalived.stats" ]] || return 1 
	echo "### START DATA ###" > "${file}.tmp"
        sudo cat "/tmp/keepalived.data" >> "${file}.tmp"
        echo "### END DATA ###" >> "${file}.tmp"
        echo "### START STATS ###" >> "${file}.tmp"
	sudo cat "/tmp/keepalived.stats" >> "${file}.tmp"
        echo "### END STATS ###" >> "${file}.tmp"
        sudo mv "${file}.tmp" "${file}"
    fi
    echo "${file}"
}

vrrp_list() {
    file=$( refresh_cache )
    [[ ${?} == 0 ]] || return 1

    rval=`egrep "VRRP Instance = " ${file} | awk -F'=' '{print $2}' | awk '{$1=$1};1' | sort | uniq`
    echo "${rval:-0}"
}

vrrp_data() {
    instance="${1}"
    attr="${2}"

    file=$( refresh_cache )
    [[ ${?} == 0 ]] || return 1

    data=`sed '/### START DATA ###/,/### END DATA ###/{//!b};d' ${file}`
    rval=`echo "${data}" | sed "/VRRP Instance = ${instance}/,/VRRP Instance = */{//!b};d" | \
	  grep "${attr}" | awk -F'=' '{print $2}' | awk '{$1=$1};1'`

    if [[ "${attr}" == "Last transition" ]]; then
        rval=`echo "${rval}" | sed -e 's/(.*)//'`
    fi
    echo "${rval:-0}"
}

vrrp_stats() {
    instance="${1}"
    attr="${2}"

    file=$( refresh_cache )
    [[ ${?} == 0 ]] || return 1

    data=`sed '/### START STATS ###/,/### END STATS ###/{//!b};d' ${file}`
    rval=`echo "${data}" | sed "/VRRP Instance: ${instance}/,/VRRP Instance: */{//!b};d" | \
	  grep "${attr}" | awk -F':' '{print $2}' | awk '{$1=$1};1'`

    echo "${rval:-0}"

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
            IFS=":" JSON_ATTR=( ${OPTARG} )
	    IFS="${IFS_DEFAULT}"
            ;;
	a)
	    param="${OPTARG//p=}"
	    [[ -n ${param} ]] && ARGS[${#ARGS[*]}]="${param}"
	    ;;
	v)
	    version
	    ;;
        \?)
            exit 1
            ;;
    esac
done

if [[ "${SECTION}" =~ (vrrp) ]]; then
    if [[ ${ARGS} == 'list' ]]; then
       rval=$( vrrp_list "${ARGS[@]:1}" )
    elif [[ ${ARGS} == 'data' ]]; then
       rval=$( vrrp_data "${ARGS[@]:1}" )
    elif [[ ${ARGS} == 'stats' ]]; then
       rval=$( vrrp_stats "${ARGS[@]:1}" )
    fi 
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
    done < <(echo "${rval}")
    echo '   ]'
    echo '}'
else
    echo "${rval:-0}"
fi

exit ${rcode}
