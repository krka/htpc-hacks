#!/bin/bash

# Utility to configure cpufreq based on whether or not something is currently playing.

lockfile-create -q -r 0 --use-pid /var/run/cpufreq.pid

if [ $? -ne 0 ]; then
  # already running
  exit 0
fi

PROCESSORS=$(cat /proc/cpuinfo |grep "^processor"|cut -d : -f 2|cut -b 2-| tr '\n' ' ')

while true ; do
    lockfile-touch --oneshot /var/run/cpufreq.pid

	result=$(curl -s -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "Player.GetActivePlayers", "id": 1}' http://localhost:8080/jsonrpc)

	if [ $? -ne 0 ] ; then
	  echo "$(date): xbmc not running"
	  exit 1
	fi

	playing=$(echo $result | jq '.result | length')

	if [ $? -ne 0 ] ; then
	  echo "$(date): xbmc response was not json: $result"
	  exit 1
	fi

	if [ $playing -ge 1 ] ; then
	  wanted=performance
	else
	  wanted=powersave
	fi

    modified=0
    for p in $PROCESSORS; do
  	  current=$(cpufreq-info -c $p | grep "The governor"|cut -f 2 -d '"')
      if [ $? -ne 0 ]; then
        echo "$(date): could not detect current governor, aborting."
        exit 1
      fi
      if [ $current != $wanted ] ; then
		cpufreq-set -c $p -g $wanted
        modified=1
      fi
    done

    if [ $modified -ne 0 ]; then
      echo "$(date): Changing from $current to $wanted"
    fi

    sleep 5
done

