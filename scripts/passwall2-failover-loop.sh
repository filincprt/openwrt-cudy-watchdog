#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin

while :; do
    /usr/bin/passwall2-failover 2>&1 | while IFS= read -r line; do
        logger -t passwall2-watchdog "$line"
    done
    sleep 5
done
