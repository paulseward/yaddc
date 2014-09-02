yaddc.sh
========

"Yet Another Dynamic DNS Client"

A simple, but flexible no-ip.com compatible dynamic dns client, written in bash.

Designed to be run from a cronjob

Requirements
------------
Needs:
* bash 3.0 or later (as it makes use of the regex support in bash 3)
* curl
* gnu tail/head (makes use of "-n -1" to return all but the last line, which isn't available in OSX for example)

ToDo
----
* Support "-f <config_file>" to make calling syntax a bit cleaner
* Make the error handling more consistent between the two curl calls
* Support for redirecting the -v output to the logfile?


