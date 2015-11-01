#!/bin/bash

# Utility to configure cpufreq based on whether or not something is currently playing.

lockfile-create -q -r 0 --use-pid /var/run/cpufreq.pid

if [ $? -ne 0 ]; then
  # already running
  exit 0
fi

PROCESSORS=$(cat /proc/cpuinfo |grep "^processor"|cut -d : -f 2|cut -b 2-| tr '\n' ' ')

CHECK=screensaver

while true ; do
    lockfile-touch --oneshot /var/run/cpufreq.pid

    if [ $CHECK == "playing" ]; then
      # Check if a video is playing
	  result=$(curl -s -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "Player.GetActivePlayers", "id": 1}' http://localhost:8080/jsonrpc)
    elif [ $CHECK == "screensaver" ]; then
      # Check if screensaver is active
	  result=$(curl -s -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "XBMC.GetInfoBooleans", "params": { "booleans": ["System.ScreenSaverActive "] }, "id": 1}' http://localhost:8080/jsonrpc)
    else
	  echo "$(date): invalid check option: $CHECK"
	  exit 1
    fi


	if [ $? -ne 0 ] ; then
	  echo "$(date): xbmc not running"
	  exit 1
	fi

    if [ $CHECK == "playing" ]; then
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
    elif [ $CHECK == "screensaver" ]; then
  	  screensaver=$(echo $result | jq '.result["System.ScreenSaverActive "]')
	  if [ $? -ne 0 ] ; then
	    echo "$(date): xbmc response was not json: $result"
	    exit 1
	  fi

	  if [ $screensaver == "true" ] ; then
	    wanted=powersave
	  else
	    wanted=performance
	  fi
    else
	  echo "$(date): invalid check option: $CHECK"
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

