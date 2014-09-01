#!/bin/bash

UA="Simple No-IP Update/0.2 thg@paulseward.com"

log ()
{
  echo -e "$(date --rfc-3339=ns)\t$1" >> $LOG
}

verbose ()
{
if [[ -z $VERBOSE ]]
then
  echo $1;
fi
}

usage ()
{
cat << EOF
usage: $0 options

This script is a lightweight no-ip.org compatible Dynamic DNS client, designed to be
run by cron.

OPTIONS:
	-h	Show this message
	-u	Username (required)
	-p	Password (required)
	-n	Domain name to update (required)
	-i	URL to get IP from (must return just the IP) defaults to http://icanhazip.com
	-d	URL to push DDNS updates to defaults to http://dynupdate.no-ip.com/nic/update
	-l	Logfile to write to, default is /var/log/ip.log
	-v	Verbose

User Agent: $UA
Fork from https://github.com/paulseward/ddclient-simple

EOF
}

USERNAME=
PASSWORD=
DOMAIN=
IP_URL=http://icanhazip.com
DNS_URL=http://dynupdate.no-ip.com/nic/update
LOG=/var/log/ip.log
TMP=/tmp/ip.tmp

while getopts “hu:p:n:i:d:l:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         u)
             USERNAME=$OPTARG
             ;;
         p)
             PASSWORD=$OPTARG
             ;;
         n)
             DOMAIN=$OPTARG
             ;;
         i)
             IP_URL=$OPTARG
             ;;
         d)
             DNS_URL=$OPTARG
             ;;
         l)
             LOG=$OPTARG
             ;;
         v)
             verbose=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

# Bail if we're incomplete
if [[ -z $USERNAME ]] || [[ -z $PASSWORD ]] || [[ -z $DOMAIN ]]
then
     usage
     exit 1
fi

# Grab the IP
verbose "Attempting to retrieve IP from $IP_URL"
IP_RV=$(curl -w "http_code:%{http_code}" -L --max-time 10 -s $IP_URL)

# Check the http return_code to make sure we actually got something
if [[ $IP_RV =~ http_code:(.*)$ ]]
then
  if [[ ${BASH_REMATCH[1]} != 200 ]]
  then
    verbose "curl returned: $IP_RV"
    verbose "Failed to retrieve IP, exiting"
    log "Error: Unable to retrieve IP address from $IP_URL"
    exit 1
  fi
else
  verbose "curl failed to return an http_code: $IP_RV"
  log "Error: Unable to retrieve IP address from $IP_RV"
  exit 1
fi

if [[ $IP_RV =~ ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) ]]
then
  IP=${BASH_REMATCH[1]}
else
  verbose "Curl returned: $IP_RV"
  verbose "Failed to retrieve IP, exiting"
  log "Error: Unable to retrieve IP address from $IP_URL"
  exit 1
fi

# Recreate the $TMP file if it's missing
if [ ! -f  $TMP ] ; then
   echo "unknown" > $TMP
fi

verbose "Current IP: $IP"

# Grab the last known IP
OLDIP=$(cat $TMP)

verbose "Old IP: $OLDIP"
if [ "$IP" == "$OLDIP" ] ; then
   verbose "No change, exiting"
   exit 0
fi

# Try to update to the new IP
UPDATE_URL="$DNS_URL?hostname=$DOMAIN&myip=$IP"

verbose "Attempting to update $DOMAIN to point to $IP"
verbose "Using: $UPDATE_URL"
DNS_RV=$(curl -w '\n%{http_code}' -A "$UA" --max-time 5 -s --user $USERNAME:$PASSWORD  "$UPDATE_URL")

# Parse the results.  "head -n -1" returns everything apart from the last line of the curl output
RESULT=$(echo "$DNS_RV" | head -n -1)
RETCODE=$(echo "$DNS_RV" | tail -n1)

if [[ $RETCODE != 200 ]]
then
  verbose "Failed to update IP, exiting"
  log "Error: Unable to contact update server via $UPDATE_URL : $DNS_RV"
  exit 1
else
  # Update was successful
  verbose "Update successful: $DNS_RV"
  log "$OLDIP\t$IP\t$RESULT"
  echo $IP > $TMP
fi

exit 0

