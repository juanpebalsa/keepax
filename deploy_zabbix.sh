#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix
PREFIX_DIR="${ZABBIX_DIR}/scripts/agentd/keepax"

CACHE_DIR="${1:-${PREFIX_DIR}/tmp}"
CACHE_TTL="${2:-5}"

mkdir -p "${PREFIX_DIR}"

SCRIPT_CONFIG="${PREFIX_DIR}/keepax.conf"
if [[ -f "${SCRIPT_CONFIG}" ]]; then
    SCRIPT_CONFIG="${SCRIPT_CONFIG}.new"
fi

cp -rpv "${SOURCE_DIR}/keepax/keepax.sh"             "${PREFIX_DIR}/"
cp -rpv "${SOURCE_DIR}/keepax/keepax.conf.example"   "${SCRIPT_CONFIG}"
cp -rpv "${SOURCE_DIR}/keepax/zabbix_agentd.conf"    "${ZABBIX_DIR}/zabbix_agentd.d/keepax.conf"

regex_array[0]="s|CACHE_DIR=.*|CACHE_DIR=\"${CACHE_DIR}\"|g"
regex_array[1]="s|CACHE_TTL=.*|CACHE_TTL=\"${CACHE_TTL}\"|g"
for index in ${!regex_array[*]}; do
    sed -i "${regex_array[${index}]}" ${SCRIPT_CONFIG}
done
