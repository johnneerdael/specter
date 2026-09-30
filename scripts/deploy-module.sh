#!/bin/sh
# Never replace a live root module using adb rm/unzip.
echo "Direct deployment is disabled. Back up first, then install a validated ZIP through your root manager." >&2
exit 1
