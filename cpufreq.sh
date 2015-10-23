#!/bin/bash

# Utility to configure cpufreq based on whether or not something is currently playing.

playing=$(curl -s -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "Player.GetActivePlayers", "id": 1}' http://localhost:8080/jsonrpc | jq '.result | length')

function set_gov {
  wanted=$1
  for cpu in 0 1 ; do
    cpufreq-info -c $cpu | grep "may decide" | grep -q $wanted
    if [ $? -eq 1 ] ; then
      cpufreq-set -c $cpu -g $wanted
      echo Changed cpu $cpu to $wanted
    else
      echo Nothing to do, already using $wanted
    fi
  done
}

if [ -z $playing ] ; then
  wanted=powersave
  echo Not playing anything, setting $wanted
  set_gov $wanted
  exit
fi

if [ $playing -ge 1 ] ; then
  wanted=performance
  echo Playing something, setting $wanted
  set_gov $wanted
  exit
fi

wanted=powersave
echo Not playing anything, setting $wanted
set_gov $wanted

