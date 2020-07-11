SHELL := /bin/bash

.PHONY: all submodules fuzzilli afl jsc jsc_fuzzilli jsc_afl clean

all: fuzzilli afl jsc

submodules:
	# Check if submodules are initialized already
	@if [[ ! -f WebKit/Source/JavaScriptCore/jsc.cpp ]]; then \
		git submodule update --init --rebase --remote --jobs 2; \
	fi

fuzzilli: submodules
	# Compile fuzzilli
	cd fuzzilli && swift build

afl: submodules
	# Compile AFLplusplus
	cd AFLplusplus && make all
	# Patch QEMU for AFLplusplus
	patch AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff
	# Build qemu support
	cd AFLplusplus/qemu_mode && sh ./build_qemu_support.sh
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff

jsc_fuzzilli: submodules
	# Check if jsc_afl was already compiled for AFL and copy build files if so
	@if [[ -d WebKit/WebKitBuild && ! -d WebKit/FuzzBuild ]]; then \
		cp -r WebKit/WebKitBuild WebKit/FuzzBuild; \
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

jsc_afl: submodules
	# Check if jsc was already compiled for Fuzzilli and copy build files if so
	@if [[ -d WebKit/FuzzBuild && ! -d WebKit/WebKitBuild ]]; then \
		cp -r WebKit/FuzzBuild WebKit/WebKitBuild; \
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
