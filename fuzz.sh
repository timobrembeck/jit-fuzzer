#!/bin/bash

cd $(dirname "$BASH_SOURCE")

# check if dependencies are built
if [[ ! -f ./AFLplusplus/afl-fuzz || ! -f ./WebKit/WebKitBuild/Debug/bin/jsc ]]; then
    echo -e "Please build the dependencies by executing\n\n  $(whoami)@$(hostname):$(dirs +0)\$ make\n\nand restart this script." >&2
    exit 1
fi

# do not send core dumps to external utility
if [[ "$(cat /proc/sys/kernel/core_pattern)" != "core" ]]; then
    echo core | sudo tee /proc/sys/kernel/core_pattern
fi

# optimize cpu scaling
if [[ "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)" != "performance" ]]; then
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi

# activate debug mode
#export AFL_DEBUG=1

# activate child output
#export AFL_DEBUG_CHILD_OUTPUT=1

# set afl tmp dir so system tmp dir (which is mounted as tmpfs in ram)
export AFL_TMPDIR="/tmp"

# remove current input if exists
if [[ -f /${AFL_TMPDIR}/.cur_input ]]; then
    rm /${AFL_TMPDIR}/.cur_input
fi

# set afl entrypoint
if [[ -f .afl_entrypoint ]]; then
    export AFL_ENTRYPOINT=$(cat .afl_entrypoint)
fi

# start to fuzz
./AFLplusplus/afl-fuzz -i in -o out -t 9999999999999999 -m none -d -Q ./jsc fuzz.js
