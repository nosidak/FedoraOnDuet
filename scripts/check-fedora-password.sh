#!/usr/bin/env bash
# Run inside the Fedora rootfs; test the real dictionary, not just RPM metadata.
set -euo pipefail
printf '%s\n' 'Unrelated-Cobalt-Mango-739!' | pwscore >/dev/null
if printf '%s\n' 'password' | pwscore >/dev/null 2>&1; then
    echo 'Password quality checks accepted a weak password' >&2
    exit 1
fi
