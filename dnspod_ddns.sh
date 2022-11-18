#! /bin/bash

# CONF START
API_ID=12345
API_Token=abcdefghijklmnopq2333333
domain=example.com
host=home
CHECKURL="https://myip4.ipip.net"
# OUT="pppoe"
# CONF END

printf "[$(date +"%F %T %Z")] "
if (echo $CHECKURL | grep -q "://"); then
	IPREX='([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
	URLIP=$(curl -4 -k $(if [ -n "$OUT" ]; then echo "--interface $OUT"; fi) -s $CHECKURL | grep -Eo "$IPREX" | tail -n1)
	if (echo $URLIP | grep -qEvo "$IPREX"); then
		URLIP="Failed to query IP."
	fi
	# echo "[URL IP]: $URLIP"
	dnscmd="nslookup"
	type nslookup >/dev/null 2>&1 || dnscmd="ping -c1"
	DNSTEST=$($dnscmd $host.$domain)
	if [ "$?" != 0 ] && [ "$dnscmd" == "nslookup" ] || (echo $DNSTEST | grep -qEvo "$IPREX"); then
		DNSIP="Failed to reach DNS."
	else
		DNSIP=$(echo $DNSTEST | grep -Eo "$IPREX" | tail -n1)
	fi
	# echo "[DNS IP]: $DNSIP"
	if [ "$DNSIP" == "$URLIP" ]; then
		printf "SKIPPING: IP not changed\n"
		exit
	fi
fi

token="login_token=${API_ID},${API_Token}&format=json&lang=en&error_on_empty=yes&domain=${domain}&sub_domain=${host}"
Record="$(curl -4 -k $(if [ -n "$OUT" ]; then echo "--interface $OUT"; fi) -s -X POST https://dnsapi.cn/Record.List -d "${token}")"
iferr="$(echo ${Record#*code} | cut -d'"' -f3)"
if [ "$iferr" == "1" ]; then
	record_ip=$(echo ${Record#*value} | cut -d'"' -f3)
	# echo "[API IP]: $record_ip"
	if [ "$record_ip" == "$URLIP" ]; then
		printf "SKIPPING: already updated\n"
		exit
	fi
	record_id=$(echo ${Record#*\"records\"\:\[\{\"id\"} | cut -d'"' -f2)
	record_line_id=$(echo ${Record#*line_id} | cut -d'"' -f3)
	# echo Start DDNS update...
	ddns="$(curl -4 -k $(if [ -n "$OUT" ]; then echo "--interface $OUT"; fi) -s -X POST https://dnsapi.cn/Record.Ddns -d "${token}&record_id=${record_id}&record_line_id=${record_line_id}")"
	ddns_result="$(echo ${ddns#*message\"} | cut -d'"' -f2)"
	printf "$ddns_result: $record_ip -> "
	echo $ddns | grep -Eo "$IPREX" | tail -n1
else
	printf "ERROR: "
	echo $(echo ${Record#*message\"}) | cut -d'"' -f2
fi
