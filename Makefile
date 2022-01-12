SHELL := /bin/bash

.PHONY: all fuzzilli afl jsc clean

all: fuzzilli afl jsc

fuzzilli:
	# Check if submodule is initialized already
	@if [[ ! -f fuzzilli/Package.swift ]]; then \
		if [[ -d .git ]]; then \
			git submodule update fuzzilli; \
		else \
			echo -e "Please run\n\n    git submodule update\n\nbefore building the docker image." >&2; \
			exit 1; \
		fi; \
	fi
	# Patch Fuzzilli (don't undo because swift run would compile unpatched state again)
	patch -N fuzzilli/Sources/Fuzzilli/Fuzzer.swift patches/fuzzilli/Fuzzer.diff || true
	# Compile Fuzzilli
	cd fuzzilli && swift build

afl:
	# Check if submodule is initialized already
	@if [[ ! -f AFLplusplus/Makefile ]]; then \
		if [[ -d .git ]]; then \
			git submodule update AFLplusplus; \
		else \
			echo -e "Please run\n\n    git submodule update\n\nbefore building the docker image." >&2; \
			exit 1; \
		fi; \
	fi
	# Compile AFLplusplus
	cd AFLplusplus && make all
	# Patch QEMU for AFLplusplus
	patch AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff
	# Build qemu support
	cd AFLplusplus/qemu_mode && sh ./build_qemu_support.sh
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff

jsc:
	# Check if submodule is initialized already
	@if [[ ! -f WebKit/Makefile ]]; then \
		if [[ -d .git ]]; then \
			git submodule update WebKit; \
		else \
			echo -e "Please run\n\n    git submodule update\n\nbefore building the docker image." >&2; \
			exit 1; \
		fi; \
	fi
	# Patch JavaScriptCore for Fuzzilli
	patch WebKit/Source/JavaScriptCore/jsc.cpp fuzzilli/Targets/JavaScriptCore/Patches/webkit.patch
	# Patch JavaScriptCore for AFL
	patch WebKit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Build WebKit
	cd WebKit && ../fuzzilli/Targets/JavaScriptCore/fuzzbuild.sh
	# Undo AFL patch to make sure submodule repository can be pulled without conflicts
	patch -R WebKit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Undo fuzzilli patch to make sure submodule repository can be pulled without conflicts
	patch -R WebKit/Source/JavaScriptCore/jsc.cpp fuzzilli/Targets/JavaScriptCore/Patches/webkit.patch
	# Create symbolic link to JavaScriptCore executable (if not exists already)
	@if [[ ! -L jsc ]]; then \
		ln -s WebKit/FuzzBuild/Debug/bin/jsc jsc; \
	fi
	# Store address of forkserver function to .afl_entrypoint
	@echo -n "0x" > .afl_entrypoint
	@nm jsc | grep functionGetAFLInput | cut -d' ' -f1 >> .afl_entrypoint

clean:
	# Reset all local changes of the submodules (e.g. applied patches)
	git submodule foreach 'git reset --hard'
	# Remove WebKit build files
	@if [[ -d WebKit/FuzzBuild ]]; then \
		rm -rfv WebKit/FuzzBuild; \
	fi
	# Remove symbolic link to jsc executable
	@if [[ -L jsc ]]; then \
                rm -v jsc; \
        fi
	# Remove AFLplusplus build files
	cd AFLplusplus && make deepclean
