SHELL := /bin/bash

.PHONY: all fuzzilli afl jsc jsc_fuzzilli jsc_afl clean

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
	# Compile fuzzilli
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

jsc_fuzzilli:
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
	# Build WebKit for Fuzzilli
	cd WebKit && ../fuzzilli/Targets/JavaScriptCore/fuzzbuild.sh
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R WebKit/Source/JavaScriptCore/jsc.cpp fuzzilli/Targets/JavaScriptCore/Patches/webkit.patch
	# Create symbolic link to JavaScriptCore executable (if not exists already)
	@if [[ ! -f jsc_fuzzilli ]]; then \
		ln -s WebKit/FuzzBuild/Debug/bin/jsc jsc_fuzzilli; \
	fi

jsc_afl:
	# Check if submodule is initialized already
	@if [[ ! -f WebKit/Makefile ]]; then \
		if [[ -d .git ]]; then \
			git submodule update WebKit; \
		else \
			echo -e "Please run\n\n    git submodule update\n\nbefore building the docker image." >&2; \
			exit 1; \
		fi; \
	fi
	# Patch JavaScriptCore for AFL
	patch WebKit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Compile WebKit for AFL
	WEBKIT_OUTPUTDIR=WebKitBuild ./WebKit/Tools/Scripts/build-jsc --jsc-only --debug --cmakeargs="-DENABLE_STATIC_JSC=ON -DCMAKE_BUILD_TYPE=DEBUG -DCMAKE_C_COMPILER='/usr/bin/clang' -DCMAKE_CXX_COMPILER='/usr/bin/clang++' -DCMAKE_CXX_FLAGS='-g -O0 -lrt -no-pie -no-pthread' -DCMAKE_CXX_FLAGS_DEBUG='-g -O0 -no-pie -no-pthread' -DCMAKE_C_FLAGS='-g -O0 -no-pie -no-pthread' -DCMAKE_C_FLAGS_DEBUG='-g -O0 -no-pie -no-pthread'"
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R WebKit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Create symbolic link to JavaScriptCore executable (if not exists already)
	@if [[ ! -f jsc_afl ]]; then \
		ln -s WebKit/WebKitBuild/Debug/bin/jsc jsc_afl; \
	fi
	# Store address of forkserver function to .afl_entrypoint
	@echo -n "0x" > .afl_entrypoint
	@nm jsc_afl | grep functionGetAFLInput | cut -d' ' -f1 >> .afl_entrypoint

jsc: jsc_fuzzilli jsc_afl

clean:
	# Reset all local changes of the submodules (e.g. applied patches)
	git submodule foreach 'git reset --hard'
	# Remove WebKit build files
	@if [[ -d WebKit/WebKitBuild ]]; then \
		rm -rfv WebKit/WebKitBuild; \
	fi
	@if [[ -d WebKit/FuzzBuild ]]; then \
		rm -rfv WebKit/FuzzBuild; \
	fi
	# Remove symbolic link to jsc executable
	@if [[ -f jsc ]]; then \
		rm -v jsc; \
	fi
	# Remove AFLplusplus build files
	cd AFLplusplus && make clean
