[![Docker](https://img.shields.io/badge/DockerHub-timoludwig%2Fjit--fuzzer-blue?logo=docker)](https://hub.docker.com/repository/docker/timoludwig/jit-fuzzer)
[![License](https://img.shields.io/badge/License-GPL%203.0-green.svg)](https://opensource.org/licenses/GPL-3.0)
<!--[![Docker Image Size](https://img.shields.io/docker/image-size/timoludwig/jit-fuzzer/latest)](https://hub.docker.com/repository/docker/timoludwig/jit-fuzzer)-->

# jit-fuzzer

A fuzzing setup for JS JIT compilers using a combination of Fuzzilli and AFLplusplus, implemented for the JavaScriptCore (WebKit) engine.

## Quickstart

You can use the pre-built docker image hosted on [Docker Hub](https://hub.docker.com/repository/docker/timoludwig/jit-fuzzer):

```
docker pull timoludwig/jit-fuzzer
docker run --name jit-fuzzer timoludwig/jit-fuzzer
```

## Detailed instructions

Clone the repository including its submodules:

| Protocol | Command                                                                                 |
| -------- | --------------------------------------------------------------------------------------- |
| HTTPS    | `git clone --recurse-submodules --jobs 3 https://github.com/timoludwig/jit-fuzzer.git`  |
| SSH      | `git clone --recurse-submodules --jobs 3 git@github.com:timoludwig/jit-fuzzer.git`      |

Pull new commits including submodules:

```
git pull
git submodule update --jobs 3
```

If you want to modify and/or build the project yourself, you have the choice between Docker and a native Linux installation:

<table>
    <thead>
        <tr>
            <th></th>
            <th>Docker</th>
            <th>Native Linux</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Compile patched versions of Fuzzilli, AFLplusplus and WebKit (this may take a while, even on modern hardware):</td>
            <td>
                <div style="background: #ffffff; overflow:auto;width:auto;border:solid gray;border-width:.1em .1em .1em .8em;padding:.2em .6em;">
<pre style="margin: 0; line-height: 125%">
docker build -t jit-fuzzer .
</pre>
                </div>
            </td>
            <td>
                <div style="background: #ffffff; overflow:auto;width:auto;border:solid gray;border-width:.1em .1em .1em .8em;padding:.2em .6em;">
<pre style="margin: 0; line-height: 125%">
make
</pre>
                </div>
            </td>
        </tr>
        <tr>
            <td>Generate interesting js samples with Fuzzilli and fuzz their JIT-compiled code in AFL:</td>
            <td>
                First run (create container from image):
                <div style="background: #ffffff; overflow:auto;width:auto;border:solid gray;border-width:.1em .1em .1em .8em;padding:.2em .6em;">
<pre style="margin: 0; line-height: 125%">
docker run --name jit-fuzzer jit-fuzzer
</pre>
                </div>
                Subsequent runs (start of existing container):
                <div style="background: #ffffff; overflow:auto;width:auto;border:solid gray;border-width:.1em .1em .1em .8em;padding:.2em .6em;">
<pre style="margin: 0; line-height: 125%">
docker start jit-fuzzer
docker logs -f jit-fuzzer
</pre>
                </div>
            </td>
            <td>
                <div style="background: #ffffff; overflow:auto;width:auto;border:solid gray;border-width:.1em .1em .1em .8em;padding:.2em .6em;">
<pre style="margin: 0; line-height: 125%">
./fuzz.sh
</pre>
                </div>
            </td>
        </tr>
    </tbody>
</table>

## How does it work?
[![Control-flow graph](https://github.com/timoludwig/jit-fuzzer/raw/assets/jit-fuzzer.svg)](https://github.com/timoludwig/jit-fuzzer/blob/assets/jit-fuzzer.svg)
