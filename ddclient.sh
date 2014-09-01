#!/bin/bash

UA="Simple No-IP Update/0.2 thg@paulseward.com"

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
    echo -e "$(date --rfc-3339=ns)\tUnable to retrieve IP address from $IP_URL" >> $LOG
    exit 1
  fi
fi

if [[ $IP_RV =~ ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) ]]
then
  IP=${BASH_REMATCH[1]}
else
  verbose "Curl returned: $IP_RV"
  verbose "Failed to retrieve IP, exiting"
  echo -e "$(date --rfc-3339=ns)\tUnable to retrieve IP address from $IP_URL" >> $LOG
  exit 1
fi

# Write it to the $TMP file if the $TMP file is missing
if [ ! -f  $TMP ] ; then
   echo "" > $TMP
fi

verbose "Current IP: $IP"

# Grab the last known IP
OLDIP=$(cat $TMP)
verbose "Old IP: $OLDIP"
if [ "$IP" == "$OLDIP" ] ; then
   verbose "No change, exiting"
   exit 0
fi

# If we get here, our IP has changed

# Try to update it
UPDATE_URL="$DNS_URL?hostname=$DOMAIN&myip=$IP"

verbose "Attempting to update $DOMAIN to point to $IP"
verbose "Using: $UPDATE_URL"
ANSWER=$(curl -A "$UA" --max-time 5 -s --user $USERNAME:$PASSWORD  "$UPDATE_URL")

if [[ $ANSWER =~ Error ]] ; then
  verbose "Error encountered: $ANSWER"
  echo -e "$(date --rfc-3339=ns)\tTemporary error" >> $LOG
else
  verbose "Update successful: $ANSWER"
  echo -e "$(date --rfc-3339=ns)\t$OLDIP\t$IP\t$ANSWER" >> $LOG
  echo $IP > $TMP
fi

