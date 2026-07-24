#!/usr/bin/env bash
temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
[[ -n "$temp" ]] && echo "${temp}°" || echo "---"
