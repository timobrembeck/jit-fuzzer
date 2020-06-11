print("[JS] getAFLInputArray()");
afl_input_types = ['bool', 'integer', 'double', 'string']
let afl_input_array = getAFLInputArray(afl_input_types);
print('[JS] AFL input array: ' + afl_input_array);
