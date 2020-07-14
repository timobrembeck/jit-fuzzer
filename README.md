# jit-fuzzer
A fuzzing setup for JS JIT compilers, implemented for the JavaScriptCore (webkit) engine.

## Cloning
Clone the repository including its submodules:
```
git clone --recurse-submodules --jobs 3 https://github.com/timoludwig/jit-fuzzer.git
```

## Pulling
Pull new commits including submodules:
```
cd jit-fuzzer
git pull
git submodule update --jobs 3
```

## Building
Compile patched versions of Fuzzilli, AFLplusplus and WebKit (this may take a while, even on modern hardware):

### Docker
```
cd jit-fuzzer
docker build -t jit-fuzzer .
```

### Native
```
cd jit-fuzzer
make
```

## Fuzzing
Generate interesting js samples with Fuzzilli and fuzz their JIT-compiled code in AFL:

### Docker
First run (create container from image):
```
docker run --name jit-fuzzer jit-fuzzer
```

Start of existing container:
```
docker start jit-fuzzer
docker logs -f jit-fuzzer
```

### Native
```
./fuzz.sh
```

## How does it work?
[![Control-flow graph](https://github.com/timoludwig/jit-fuzzer/raw/assets/jit-fuzzer.svg)](https://github.com/timoludwig/jit-fuzzer/blob/assets/jit-fuzzer.svg)
