.PHONY: all jsc afl

all: jsc afl

jsc:
	# Patch JavaScriptCore
	patch webkit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Compile WebKit
	WEBKIT_OUTPUTDIR=WebKitBuild ./webkit/Tools/Scripts/build-jsc --jsc-only --debug --cmakeargs="-DENABLE_STATIC_JSC=ON -DCMAKE_BUILD_TYPE=DEBUG -DCMAKE_C_COMPILER='/usr/bin/clang' -DCMAKE_CXX_COMPILER='/usr/bin/clang++' -DCMAKE_CXX_FLAGS='-g -O0 -lrt -no-pie -no-pthread' -DCMAKE_CXX_FLAGS_DEBUG='-g -O0 -no-pie -no-pthread' -DCMAKE_C_FLAGS='-g -O0 -no-pie -no-pthread' -DCMAKE_C_FLAGS_DEBUG='-g -O0 -no-pie -no-pthread'"
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R webkit/Source/JavaScriptCore/jsc.cpp patches/WebKit/jsc.diff
	# Create symbolic link to JavaScriptCore executable (if not exists already)
	if [ ! -f jsc ]; then \
		ln -s webkit/WebKitBuild/Debug/bin/jsc; \
	fi

afl:
	# Patch AFLplusplus
	patch AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff
	# Compile AFLplusplus including support for qemu
	cd AFLplusplus && make binary-only
	# Undo patch to make sure submodule repository can be pulled without conflicts
	patch -R AFLplusplus/qemu_mode/build_qemu_support.sh patches/AFLplusplus/build_qemu_support.diff

clean:
	# Reset all local changes of the submodules (e.g. applied patches)
	git submodule foreach 'git reset --hard origin/master'
	# Remove WebKit build files
	@if [ -d webkit/WebKitBuild ]; then \
		rm -rfv webkit/WebKitBuild; \
	fi
	# Remove symbolic link to jsc executable
	@if [ -f jsc ]; then \
		rm -v jsc; \
	fi
	# Remove AFLplusplus build files
	cd AFLplusplus && make clean
