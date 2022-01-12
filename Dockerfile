########################
# Fuzzilli build stage #
########################

FROM swift:focal as fuzzilli
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=bash
WORKDIR /jit-fuzzer
COPY fuzzilli fuzzilli
COPY patches/fuzzilli patches/fuzzilli
COPY Makefile .
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y apt-utils make
RUN make fuzzilli

###################
# AFL build stage #
###################

FROM ubuntu:focal as afl
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=bash
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y \
    apt-utils \
    automake \
    bison \
    build-essential \
    clang \
    flex \
    gcc-9-plugin-dev \
    git \
    llvm \
    libglib2.0-dev \
    libpixman-1-dev \
    libtool-bin \
    ninja-build \
    python3-dev \
    python3-setuptools \
    wget
WORKDIR /jit-fuzzer
COPY .git/modules/AFLplusplus .git/modules/AFLplusplus
COPY AFLplusplus AFLplusplus
COPY patches/AFLplusplus patches/AFLplusplus
COPY Makefile .
RUN make afl

######################
# WebKit build stage #
######################

FROM ubuntu:focal as jsc
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=bash
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y \
    apt-transport-https \
    apt-utils \
    bison \
    build-essential \
    ca-certificates \
    clang-12 \
    flex \
    git-core \
    git-svn \
    gnupg \
    llvm \
    libicu-dev \
    libxml-libxml-perl \
    ninja-build \
    python \
    python3-dev \
    gperf \
    ruby \
    software-properties-common \
    subversion \
    wget
# Install recent version of cmake
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
RUN apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
RUN apt-get install -y cmake
WORKDIR /usr/include/fuzzer
RUN wget -nv https://raw.githubusercontent.com/llvm/llvm-project/main/compiler-rt/include/fuzzer/FuzzedDataProvider.h
WORKDIR /jit-fuzzer
COPY WebKit WebKit
COPY patches/WebKit patches/WebKit
COPY fuzzilli/Targets/JavaScriptCore fuzzilli/Targets/JavaScriptCore
COPY Makefile .
RUN make jsc

#################
# Fuzzing stage #
#################

FROM swift:focal
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=bash

# Install sudo
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y \
    apt-utils \
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
COPY --chown=docker:docker --from=jsc jit-fuzzer/jsc jit-fuzzer/.afl_entrypoint ./

# Relinquish root privileges
USER docker

# Start fuzzing
CMD ["/bin/bash", "-x", "fuzz.sh"]
