#!/bin/bash

cd $(dirname "$BASH_SOURCE")

# check if dependencies are built
if [[ ! -f ./AFLplusplus/afl-fuzz || ! -f ./WebKit/WebKitBuild/Debug/bin/jsc || ! -f ./WebKit/FuzzBuild/Debug/bin/jsc ]]; then
    echo -e "Please build the dependencies by executing\n\n  $(whoami)@$(hostname):$(dirs +0)\$ make\n\nand restart this script." >&2
    exit 1
fi

# optimize cpu scaling
if [[ "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)" != "performance" ]]; then
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi

# check if fuzzilli results and enough interesting samples exist
if [[ ! -d fuzzilli_results/interesting ]] || [[ $(ls -1 fuzzilli_results/interesting | wc -l) < 100 ]]; then
    # do not send core dumps to external utility
    if [[ "$(cat /proc/sys/kernel/core_pattern)" != "|/bin/false" ]]; then
        sudo sysctl -w 'kernel.core_pattern=|/bin/false' > /dev/null
    fi
    # generate interesting js-scripts
    cd fuzzilli
    IMPORT_STATE=$(if [[ -f ../fuzzilli_results/state.json ]]; then printf "--importState=../fuzzilli_results/state.json"; fi)
    swift run FuzzilliCli --numIterations=20 --exportState --exportStatistics --storagePath=../fuzzilli_results ${IMPORT_STATE} --logLevel=verbose --profile=jsc ../jsc_fuzzilli
    cd ..
fi

# do not send core dumps to external utility
if [[ "$(cat /proc/sys/kernel/core_pattern)" != "core" ]]; then
    sudo sysctl -w 'kernel.core_pattern=core' > /dev/null
fi

# activate debug mode
export AFL_DEBUG=1

# activate child output
export AFL_DEBUG_CHILD_OUTPUT=1

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

# create target directory
if [[ ! -d target_scripts ]]; then
    mkdir target_scripts
fi

# create afl input directory
if [[ ! -d afl_input ]]; then
    mkdir afl_input
fi

# find interesting sample to fuzz
mapfile -t JS_FILES < <( find fuzzilli_results/interesting -type f -name "*.js" )

# iterate array
for JS_FILE in "${JS_FILES[@]}"; do
    # pick first file which was not yet fuzzed
    JS_FILENAME=$(basename ${JS_FILE})
	if [[ ! -f target_scripts/${JS_FILENAME} ]]; then
        break
	fi
done

# convert js file
./js_converter.py ${JS_FILE} -o target_scripts

# get desired afl input size
AFL_INPUT_SIZE=$(python -c "import json; file = open('.afl_input_sizes.json'); data = json.load(file); print(data['target_scripts/${JS_FILENAME}'])")

# write test case of desired size
dd if=/dev/urandom of=afl_input/afl_input_seed bs=1 count=${AFL_INPUT_SIZE} > /dev/null

# start to fuzz
./AFLplusplus/afl-fuzz -i afl_input -o afl_results -t 9999999999999999 -m none -d -Q ./jsc_afl target_scripts/${JS_FILENAME}
