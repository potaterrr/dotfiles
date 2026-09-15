#!/usr/bin/env bash

COUNT=$(dunstctl count history 2>/dev/null || echo "0")

if [ -z "$COUNT" ]; then COUNT=0; fi

if [ "$COUNT" -gt 0 ]; then
    # Dynamic glowing bell when notifications are pending
    echo "{\"text\": \" $COUNT\", \"class\": \"unread\"}"
else
    # Simple, rock-solid empty bell indicator (Universal Nerd Font character)
    echo "{\"text\": \"\", \"class\": \"empty\"}"
fi
