[![Docker](https://img.shields.io/badge/DockerHub-timoludwig%2Fjit--fuzzer-blue?logo=docker)](https://hub.docker.com/r/timoludwig/jit-fuzzer)
[![License](https://img.shields.io/badge/License-GPL%203.0-green.svg)](https://opensource.org/licenses/GPL-3.0)

## :warning: This project is no longer maintained

For current research on this topic, see for example:
- Bernhard, L., Scharnowski, T., Schloegel, M., Blazytko, T., &amp; Holz, T. (2022). __JIT-Picking: Differential Fuzzing of JavaScript Engines.__ _Proceedings of the 2022 ACM SIGSAC Conference on Computer and Communications Security._ https://doi.org/10.1145/3548606.3560624 
- Groß, S., Koch, S., Bernhard, L., Holz, T., &amp; Johns, M. (2023). __Fuzzilli: Fuzzing for JavaScript Jit Compiler vulnerabilities.__ _Proceedings 2023 Network and Distributed System Security Symposium._ https://doi.org/10.14722/ndss.2023.24290

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
<pre style="margin: 0; line-height: 125%">
docker build -t jit-fuzzer .
</pre>
            </td>
            <td>
<pre style="margin: 0; line-height: 125%">
make
</pre>
            </td>
        </tr>
        <tr>
            <td>Generate interesting js samples with Fuzzilli and fuzz their JIT-compiled code in AFL:</td>
            <td>
                First run (create container from image):
<pre style="margin: 0; line-height: 125%">
docker run --name jit-fuzzer jit-fuzzer
</pre>
                Subsequent runs (start of existing container):
<pre style="margin: 0; line-height: 125%">
docker start jit-fuzzer
docker logs -f jit-fuzzer
</pre>
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
