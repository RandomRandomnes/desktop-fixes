#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Phoenix (2026-10-09): don't look anything up while the login keyring is LOCKED. With automatic sign-in the keyring
# stays locked (no password at login), and the lookup made gnome-keyring show an "Unlock Login Keyring" prompt at every
# start. The lock screen unlocks it (Settings › Privacy: unlock the keyring with the screen) and the data loads then.
# Only when the keyring answers "locked" for sure; without that collection the lookup runs as before.
locked_state=$(busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login \
    org.freedesktop.Secret.Collection Locked 2>/dev/null)
if [[ "${locked_state}" == "b true" ]]; then
    echo 'locked'
    exit 2
fi

data=$(secret-tool lookup 'application' 'illogical-impulse')
if [[ -z "$data" ]]; then
    if "${SCRIPT_DIR}/is_unlocked.sh"; then
        echo 'not found'
        exit 1
    else 
        echo 'locked'
        exit 2
    fi
fi
echo "$data"
