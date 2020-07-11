# jit-fuzzer
A fuzzing setup for JS JIT compilers, implemented for the JavaScriptCore (webkit) engine.

## Cloning
Clone the repository including its submodules
```
git clone --recurse-submodules --jobs 3 https://github.com/timoludwig/jit-fuzzer.git
```

## Pulling
Pull new commits including submodules
```
cd jit-fuzzer
git pull
git submodule update --jobs 3
```

## Building
Compile patched versions of AFLplusplus and WebKit
```
cd jit-fuzzer
make
```

## Fuzzing
Start AFL 
```
./fuzz.sh
```
