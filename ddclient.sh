#!/bin/bash

# TMP=/dev/shm/ip.tmp
TMP=/tmp/ip.tmp
LOG=/var/log/ip.log
USER=
PASS=

# IP=$(curl -L --max-time 10 -s http://myip.dnsdynamic.org)
IP=$(curl -L --max-time 10 -s http://icanhazip.com/)

if [ "$IP" == "" ] ; then
   exit 1
fi
if [ ! -f  $TMP ] ; then
   echo "" > $TMP
fi
OLDIP=$(cat $TMP)
if [ "$IP" == "$OLDIP" ] ; then
   exit 0
fi

# dnsdynamic.org
# DN=dfrt.dnsdynamic.net
# ANSWER=$(curl --max-time 5 -s --user $USER:$PASS  "https://www.dnsdynamic.org/api/?hostname=$DN&myip=$IP")

# noip.org
DN=dfrvoip.noip.me
UA="Simple No-IP Update/0.1 thg@paulseward.com"
ANSWER=$(curl -A "$UA" --max-time 5 -s --user $USER:$PASS  "http://dynupdate.no-ip.com/nic/update?hostname=$DN&myip=$IP")

if [[ $ANSWER =~ Error ]] ; then
  echo -e "$(date --rfc-3339=ns)\tTemporary error" >> $LOG
else
  echo -e "$(date --rfc-3339=ns)\t$OLDIP\t$IP\t$ANSWER" >> $LOG
  echo $IP > $TMP
fi

