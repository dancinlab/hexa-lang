#!/bin/bash
# minimal launchd shim — forwards to the hexa driver.
# Replaces the removed nexus/harness entry (nexus shared decommission).
exec "$HOME/.hx/bin/hexa" "$@"
