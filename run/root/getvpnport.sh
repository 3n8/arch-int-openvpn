#!/bin/bash

# statically assigned url for pia api (taken from pia script)
pia_api_host="209.222.18.222"
pia_api_port="2000"
pia_api_url="http://${pia_api_host}:${pia_api_port}"

# remove previous run output file
rm -f /home/nobody/vpn_incoming_port.txt

# check we are provider pia (note this env var is passed through to up script via openvpn --sentenv option)
if [[ "${VPN_PROV}" == "pia" ]]; then

	if [[ "${STRICT_PORT_FORWARD}" == "no" ]]; then

		if [[ "${DEBUG}" == "true" ]]; then
			echo "[debug] Port forwarding disabled, skipping incoming port detection"
		fi

		# create empty incoming port file (read by downloader script)
		touch /home/nobody/vpn_incoming_port.txt

	else

		echo "[info] Strict port forwarding enabled, attempting to configure an incoming port..."
		
		# remove temp file from previous run
		rm -f /tmp/VPN_INCOMING_PORT

		# create pia client id (randomly generated)
		client_id=$(head -n 100 /dev/urandom | sha256sum | tr -d " -")

		# get an assigned incoming port from pia's api using curl
		curly.sh -rc 12 -rw 10 -of /tmp/VPN_INCOMING_PORT -url "${pia_api_url}/?client_id=${client_id}"
		exit_code=$?

		if [[ "${exit_code}" != 0 ]]; then

			echo "[warn] Unable to assign incoming port, possible reasons for this:-"
			echo "[info] PIA API currently down (script will auto retry)"
			echo "[info] or"
			echo "[info] PIA endpoint doesn't support port forwarding, a list of endpoints that do support port forwarding is as follows:-"
			echo "[info] - ca-toronto.privateinternetaccess.com (CA Toronto)"
			echo "[info] - ca.privateinternetaccess.com (CA Montreal)"
			echo "[info] - nl.privateinternetaccess.com (Netherlands)"
			echo "[info] - nl.privateinternetaccess.com (Switzerland)"
			echo "[info] - sweden.privateinternetaccess.com (Sweden)"
			echo "[info] - sweden.privateinternetaccess.com (France)"
			echo "[info] - ro.privateinternetaccess.com (Romania)"
			echo "[info] - israel.privateinternetaccess.com (Israel)"
			echo "[info] Terminating OpenVPN process to force retry for incoming port..."

			kill -2 $(cat /root/openvpn.pid)
			exit 1

		else

			VPN_INCOMING_PORT=$(cat /tmp/VPN_INCOMING_PORT | jq -r '.port')

			if [[ "${VPN_INCOMING_PORT}" =~ ^-?[0-9]+$ ]]; then

				if [[ "${DEBUG}" == "true" ]]; then
					echo "[debug] Successfully assigned incoming port ${VPN_INCOMING_PORT}"
				fi

				# write port number to text file (read by downloader script)
				echo "${VPN_INCOMING_PORT}" > /home/nobody/vpn_incoming_port.txt

			else

				echo "[warn] PIA incoming port malformed"
				echo "[info] Terminating OpenVPN process to force retry for incoming port..."

				kill -2 $(cat /root/openvpn.pid)
				exit 1

			fi

		fi

	fi

else

	if [[ "${DEBUG}" == "true" ]]; then
		echo "[debug] VPN provider ${VPN_PROV} is != pia, skipping incoming port detection"
	fi

fi
