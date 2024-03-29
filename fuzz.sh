#!/bin/bash

cd $(dirname "$BASH_SOURCE")

# check if dependencies are built
if [[ ! -f ./AFLplusplus/afl-fuzz || ! -f ./WebKit/FuzzBuild/Debug/bin/jsc ]]; then
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

# do not send core dumps to external utility (also accept if there are core dumps)
if [[ "$(cat /proc/sys/kernel/core_pattern)" != "core" ]]; then
    # check if file is writable
    if sudo test -w /proc/sys/kernel/core_pattern; then
        sudo sysctl -w 'kernel.core_pattern=core' > /dev/null
    else
        echo -e "Please set your host's kernel core pattern to 'core' by running\n\n    sudo sysctl -w 'kernel.core_pattern=core'" >&2
        exit 1
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

# activate qemu strace
#export QEMU_STRACE=1

# increase AFL forkserver init timeout
#export AFL_FORKSRV_INIT_TMOUT=9999999999999999

# increase AFL coverage map size
#export AFL_MAP_SIZE=10000000

# limit qemu instrumentation range
#export AFL_QEMU_INST_RANGES=0x1-0x1

# set afl tmp dir so system tmp dir (which is mounted as tmpfs in ram)
export AFL_TMPDIR="/tmp"

# infinite fuzzing loop
while true; do

    if ! [[ -d fuzzilli_results/corpus ]] || diff -q fuzzilli_results/corpus target_scripts | grep -q "Only in fuzzilli_results/corpus: " | grep -q ".js"; then
        # generate interesting js-scripts
        cd fuzzilli
        if [[ -d ../fuzzilli_results/corpus ]]; then
            RESUME="--resume"
        fi
        swift run FuzzilliCli --numIterations=20 --exportStatistics --storagePath=../fuzzilli_results ${RESUME} --logLevel=verbose --profile=jsc ../jsc
        cd ..
    fi

    # find interesting sample to fuzz
    mapfile -t JS_FILES < <( find fuzzilli_results/corpus -type f -name "*.js" )
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

    # if script does not have dynamic input, don't bother fuzzing it
    if [[ ${AFL_INPUT_SIZE} -eq 0 ]]; then
        echo "Target script does not have dynamic input"
        continue
    fi

    # write test case of desired size
    dd if=/dev/urandom of=afl_input/afl_input_seed bs=1 count=${AFL_INPUT_SIZE} > /dev/null

    # remove current input if exists
    if [[ -f /${AFL_TMPDIR}/.cur_input ]]; then
        rm /${AFL_TMPDIR}/.cur_input
    fi

    # start to fuzz
    ./AFLplusplus/afl-fuzz -i afl_input -o afl_results -t 9999999999999999 -m none -d -V 10000 -Q ./jsc --useConcurrentJIT=false --useConcurrentGC=false  --thresholdForJITSoon=10 --thresholdForJITAfterWarmUp=10 --thresholdForOptimizeAfterWarmUp=100 --thresholdForOptimizeAfterLongWarmUp=100 --thresholdForOptimizeSoon=100 --thresholdForFTLOptimizeAfterWarmUp=1000 target_scripts/${JS_FILENAME}

    # save results
    cp -r afl_results results/${JS_FILENAME}

    # clear old results
    rm -r afl_results

    # enable aborting between runs (otherwise [CTRL + C] only aborts AFL)
    echo "If you want to abort, please press [CTRL + C] now."
    sleep 3

done
