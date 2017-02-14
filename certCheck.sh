#!/bin/bash

# config
recipients="user1@example.com, user2@example.com"
sender="cert.reporter@example.com"
server="mail.example.com"
user=$sender
password="password"
file="domains.txt"
# end of config

dry=0
verbose=0
while getopts ":dv" opt; do
	case $opt in
		d)
			dry=1
		;;
		v)
			verbose=1
		;;
	esac
done

if (($dry == 1)); then
	while IFS= read -r domain
	do
		toend=$(echo "scale=2; (`date --date="$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f 2)" +%s` - `date +%s`) / (24*3600)" | bc -l)
		problem=$(echo $toend '<=' 30 | bc -l)
		expired=$(echo $toend '<=' 0 | bc -l)

		if (($problem == 1)); then
			if (($expired == 1)); then
				printf '\n'
				tput setaf 1
				printf 'CERTIFICATE IS EXPIRED!\n'
				printf '======================== '$domain' ========================\n'
				printf 'The cert for '$domain' expired '$(echo $toend '*' -1 | bc -l)' days ago.\n'
				printf '=============================================================\n\n'
				tput sgr0
			else
				printf '\n'
				tput setaf 3
				printf 'EXPIRATION ALERT!\n'
				printf '======================== '$domain' ========================\n'
				printf 'The cert for '$domain' will expire in '$toend' days.\n'
				printf '=============================================================\n\n'
				tput sgr0
			fi
		elif (($verbose == 1)); then
			printf '\n'
			printf '======================== '$domain' ========================\n'
			printf 'The cert for '$domain' will expire in '$toend' days.\n'
			printf '=============================================================\n\n'
		fi

	done <"$file"

else
	output=""
	send=0
	while IFS= read -r domain
	do
		toend=$(echo "scale=2; (`date --date="$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f 2)" +%s` - `date +%s`) / (24*3600)" | bc -l)		problem=$(echo $toend '<=' 30 | bc -l)
		problem=$(echo $toend '<=' 30 | bc -l)
		expired=$(echo $toend '<=' 0 | bc -l)

		if (($problem == 1)); then
			send=1
			if (($expired == 1)); then
				output=$output'\n'
				output=$output'CERTIFICATE IS EXPIRED!\n'
				output=$output'======================== '$domain' ========================\n'
				output=$output'The cert for '$domain' expired '$(echo $toend '*' -1 | bc -l)' days ago.\n'
				output=$output'=============================================================\n\n'
			else
				output=$output'\n'
				output=$output'EXPIRATION ALERT!\n'
				output=$output'======================== '$domain' ========================\n'
				output=$output'The cert for '$domain' will expire in '$toend' days.\n'
				output=$output'=============================================================\n\n'
			fi
		elif (($verbose == 1)); then
			output=$output'\n'
			output=$output'======================== '$domain' ========================\n'
			output=$output'The cert for '$domain' will expire in '$toend' days.\n'
			output=$output'=============================================================\n\n'
		fi
	done <"$file"

	if(($verbose == 1)); then
		swaks --to "$recipients" --from "$sender" --header "Subject:Cert LifeCycle Verbose Report" --body "$output" --server "$server" --auth LOGIN --auth-user "$user" --auth-password "$password" -tls
		send=0
	fi

	if (($send == 1)); then
		swaks --to "$recipients" --from "$sender" --header "Subject:EXPIRATION ALERT - Cert LifeCycle Report" --body "$output" --server "$server" --auth LOGIN --auth-user "$user" --auth-password "$password" -tls
	fi

fi