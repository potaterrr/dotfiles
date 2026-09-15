#!/usr/bin/env bash

# Count how many historical hidden notifications are waiting in the queue
COUNT=$(makoctl list | grep -c '"id":')

if [ "$COUNT" -gt 0 ]; then
    # Dynamic glowing bell when notifications are pending
    echo "{\"text\": \" $COUNT\", \"class\": \"unread\"}"
else
    # Quiet bell if no history is logged
    echo "{\"text\": \"\", \"class\": \"empty\"}"
fi
