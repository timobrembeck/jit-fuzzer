#!/bin/bash

cd $(dirname "$BASH_SOURCE")

# check if dependencies are built
if [[ ! -f ./AFLplusplus/afl-fuzz || ! -f ./WebKit/AFLBuild/Debug/bin/jsc || ! -f ./WebKit/FuzzBuild/Debug/bin/jsc ]]; then
    echo -e "Please build the dependencies by executing\n\n    $(whoami)@$(hostname):$(dirs +0)\$ make\n\nand restart this script." >&2
    exit 1
fi

# optimize cpu scaling
if [[ "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)" != "performance" ]]; then
    # check if file is writable
    if sudo test -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; then
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    else
        echo "Please make sure your CPU frequency scaling is set to performance." >&2
    fi
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

# create directory for final output
if [[ ! -d results ]]; then
    mkdir results
fi

# force english locale to make output of diff command comparable
export LANG=en_US.utf8

# activate debug mode
#export AFL_DEBUG=1

# activate child output
#export AFL_DEBUG_CHILD_OUTPUT=1

# set afl tmp dir so system tmp dir (which is mounted as tmpfs in ram)
export AFL_TMPDIR="/tmp"

# infinite fuzzing loop
while true; do

    # check if fuzzilli results exist and if they contain interesting samples which are not yet in target scripts
    if [[ ! -d fuzzilli_results/interesting ]] || ! diff -q fuzzilli_results/interesting target_scripts | grep -q "Only in fuzzilli_results/interesting:"; then
        # do not send core dumps to external utility (also accept if there are core dumps)
        if [[ "$(cat /proc/sys/kernel/core_pattern)" != "|/bin/false" ]] && [[ "$(cat /proc/sys/kernel/core_pattern)" != "core" ]]; then
            # check if file is writable
            if sudo test -w /proc/sys/kernel/core_pattern; then
                sudo sysctl -w 'kernel.core_pattern=|/bin/false' > /dev/null
            else
                echo -e "Please set your host's kernel core pattern to 'core' by running\n\n    sudo sysctl -w 'kernel.core_pattern=core'" >&2
                exit 1
            fi
        fi
        # generate interesting js-scripts
        cd fuzzilli
        IMPORT_STATE=$(if [[ -f ../fuzzilli_results/state.json ]]; then printf "--importState=../fuzzilli_results/state.json"; fi)
        swift run FuzzilliCli --numIterations=20 --exportState --exportStatistics --storagePath=../fuzzilli_results ${IMPORT_STATE} --logLevel=verbose --profile=jsc ../jsc_fuzzilli
        cd ..
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
    AFL_INPUT_SIZE=$(python3 -c "import json; file = open('.afl_input_sizes.json'); data = json.load(file); print(data['target_scripts/${JS_FILENAME}'])")

    # write test case of desired size
    dd if=/dev/urandom of=afl_input/afl_input_seed bs=1 count=${AFL_INPUT_SIZE} > /dev/null

    # do not send core dumps to external utility
    if [[ "$(cat /proc/sys/kernel/core_pattern)" != "core" ]]; then
        # check if file is writable
        if sudo test -w /proc/sys/kernel/core_pattern; then
            sudo sysctl -w 'kernel.core_pattern=core' > /dev/null
        else
            echo -e "Please set your host's kernel core pattern to 'core' by running\n\n    sudo sysctl -w 'kernel.core_pattern=core'" >&2
            exit 1
        fi
    fi

    # remove current input if exists
    if [[ -f /${AFL_TMPDIR}/.cur_input ]]; then
        rm /${AFL_TMPDIR}/.cur_input
    fi

    # start to fuzz
    ./AFLplusplus/afl-fuzz -i afl_input -o afl_results -t 9999999999999999 -m none -d -V 10000 -Q ./jsc_afl target_scripts/${JS_FILENAME}

    # save results if they are interesting
    if [[ "$(ls -A afl_results/crashes)" ]] || [[ "$(ls -A afl_results/hangs)" ]]; then
        cp -r afl_results results/${JS_FILENAME}
    fi

    # clear old results
    rm -r afl_results

    # enable aborting between runs (otherwise [CTRL + C] only aborts AFL)
    echo "If you want to abort, please press [CTRL + C] now."
    sleep 3

done