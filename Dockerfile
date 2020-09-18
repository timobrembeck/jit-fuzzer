########################
# Fuzzilli build stage #
########################

FROM swift:bionic as fuzzilli
WORKDIR /jit-fuzzer
COPY fuzzilli fuzzilli
COPY patches/fuzzilli patches/fuzzilli
COPY Makefile .
RUN make fuzzilli

###################
# AFL build stage #
###################

FROM ubuntu:18.04 as afl
RUN apt-get update && apt-get install -y \
    automake \
    bison \
    build-essential \
    clang \
    flex \
    llvm \
    libglib2.0-dev \
    libpixman-1-dev \
    libtool-bin \
    python3-dev \
    python3-setuptools \
    wget
WORKDIR /jit-fuzzer
COPY AFLplusplus AFLplusplus
COPY patches/AFLplusplus patches/AFLplusplus
COPY Makefile .
RUN make afl

######################
# WebKit build stage #
######################

FROM ubuntu:18.04 as jsc
RUN apt-get update && apt-get install -y \
    bison \
    build-essential \
    clang \
    cmake \
    flex \
    git-core \
    git-svn \
    llvm \
    libicu-dev \
    libxml-libxml-perl \
    ninja-build \
    python \
    gperf \
    ruby \
    subversion \
    wget
WORKDIR /usr/include/fuzzer
RUN wget -nv https://raw.githubusercontent.com/llvm/llvm-project/master/compiler-rt/include/fuzzer/FuzzedDataProvider.h
WORKDIR /jit-fuzzer
COPY WebKit WebKit
COPY patches/WebKit patches/WebKit
COPY fuzzilli/Targets/JavaScriptCore fuzzilli/Targets/JavaScriptCore
COPY Makefile .
RUN make jsc

#################
# Fuzzing stage #
#################

FROM swift:bionic

# Install sudo
RUN apt-get update && apt-get install -y \
    python3 \
    python3-dev \
    sudo

# Add docker user (which passwordless sudo capabilities)
RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo
RUN echo "docker ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers

# Set working directory
WORKDIR /jit-fuzzer
RUN chown docker:docker .

# Copy files and set docker user as the owner
COPY --chown=docker:docker fuzz.sh js_converter.py ./
COPY --chown=docker:docker --from=fuzzilli jit-fuzzer/fuzzilli fuzzilli
COPY --chown=docker:docker --from=afl jit-fuzzer/AFLplusplus AFLplusplus
COPY --chown=docker:docker --from=jsc jit-fuzzer/WebKit WebKit
COPY --chown=docker:docker --from=jsc jit-fuzzer/jsc_fuzzilli jit-fuzzer/jsc_afl jit-fuzzer/.afl_entrypoint ./

# Relinquish root privileges
USER docker

# Start fuzzing
CMD ["/bin/bash", "-x", "fuzz.sh"]
