#!/usr/bin/python3

"""
This module converts interesting sample js files (e.g. from Fuzzili) into a format which is fuzzably by this AFL setup.
It replaces static variable assignments with the dynamic array "afl_input". It expects numbers in variable names only after the letter "v".
The main js-function gets executed multiple times to force jitting with static values, then the jittes code gets executed with the afl input.
"""

import argparse
import json
import os
import re
import sys
import functools


# A list of input types, e.g. "integer", "double", "string"
afl_input_types = []


def main(args: argparse.Namespace) -> None:
    """
    This is the main method. It iterates over all given files, converts them and stores them back to output files.

    :param args: The command line arguments parsed by argparse
    :type args: argparse.Namespace
    """
    for filename in args.filenames:
        converted_file = convert_file(filename)
        output_filename = write_output_file(
            filename,
            content=converted_file,
            in_place=args.in_place,
            out_dir=args.out_dir[0],
        )
        store_afl_input_size(output_filename)


def convert_file(filename: str) -> str:
    """
    This function converts a javascript file and replaces static values with dynamic array elements.

    :param filename: The file name of the file which should be converted
    :type filename: str

    :return: Converted file
    :rtype: str
    """
    global afl_input_types
    afl_input_types = []
    converted_file = ""
    with open(filename, "r") as filehandler:
        file = filehandler.read()
    # get all loop counter variables (which will most likely cause indefinite loops when chosen completely random)
    loop_variables = re.findall(r"while \((v\d+) ", file)
    # iterate each line in file
    for line in file.splitlines():
        # break if end of main function is reached
        if line == "noDFG(main);":
            break
        # skip comments and loops
        if not line.lstrip().startswith(("//", "for")) and not any(
            variable in line for variable in loop_variables
        ):
            # replace string variables
            line = re.sub(r'"(|\\"|[^"])*"', string_replacement_wrapper, line)
            # replace double variables
            line = re.sub(r"-?\d+\.\d+(e(\+|-)\d+)?", double_replacement_wrapper, line)
            # replace integer variables
            line = re.sub(r"( | \[|,|:|~)-?\d+", integer_replacement_wrapper, line)
        converted_file += line + "\n"
    converted_file += "let afl_input_types = " + str(afl_input_types) + "\n"
    converted_file += "let afl_input = " + str(get_default_afl_input()) + "\n"
    # force jitting
    converted_file += "for (var i = 0; i < 10000; ++i) main()\n"
    # get random afl input
    converted_file += "afl_input = getAFLInputArray(afl_input_types);\n"
    # invoke jitted function main() with new input
    converted_file += "main();\n"
    print(f"[js-converter] Successfully converted file {filename}")
    return converted_file


def string_replacement_wrapper(_) -> str:
    """
    This function is a wrapper for replacements of string variables.

    :param _: Unused regex match parameter
    :type _: _sre.SRE_Match (python3.6 and before) or re.Match (python3.7 onwards)

    :return: A replacement string
    :rtype: str
    """
    return replacement("string")


def double_replacement_wrapper(_) -> str:
    """
    This function is a wrapper for replacements of double variables.

    :param _: Unused regex match parameter
    :type _: _sre.SRE_Match (python3.6 and before) or re.Match (python3.7 onwards)

    :return: A replacement string
    :rtype: str
    """
    return replacement("double")


def integer_replacement_wrapper(match) -> str:
    """
    This function is a wrapper for replacements of integer variables.

    :param match: Regex match parameter to catch the prefix of the integer
    :type match: _sre.SRE_Match (python3.6 and before) or re.Match (python3.7 onwards)

    :return: A replacement string
    :rtype: str
    """
    return match.groups()[0] + replacement("integer")


def replacement(variable_type: str) -> str:
    """
    This function Replaces a hard-coded variable with an assignment of afl_input[].

    :param variable_type: The type of the variable
    :type variable_type: str

    :return: A replacement string
    :rtype: str
    """
    global afl_input_types
    afl_input_types.append(variable_type)
    return f"afl_input[{len(afl_input_types) - 1}] /* {variable_type} */"


def get_default_afl_input() -> list:
    """
    This function returns a static list of hard-coded example values for given input types.

    :return: A list of hardcoded input variables
    :rtype: list
    """
    default_input_values = {"string": "string", "integer": 1337, "double": 13.37}
    return list(map(lambda x: default_input_values[x], afl_input_types))


def write_output_file(filename: str, content: str, in_place: bool, out_dir: str) -> str:
    """
    This function stores the converted content of a js file into an output file.

    :param filename: The file name of the original file
    :type filename: str

    :param content: The content of the converted file
    :type content: str

    :param in_place: Whether the output should be directly written to the input file
    :type in_place: bool

    :param out_dir: The output directory
    :type out_dir: str
    """
    if not in_place:
        in_dir, filename = os.path.split(filename)
        if in_dir == out_dir:
            filename = filename[:-3] + "_converted.js"
        filename = out_dir + filename
    with open(filename, "w") as output_file:
        output_file.write(content)
    print(f"[js-converter] Successfully wrote output to file {filename}")
    return filename


def store_afl_input_size(filename: str) -> None:
    """
    This function converts a javascript file and replaces static values with dynamic array elements.

    :param filename: The file name of the file which should be converted
    :type filename: str
    """
    with open(".afl_input_sizes.json", "w+") as afl_input_sizes_json:
        try:
            afl_input_sizes = json.load(afl_input_sizes_json)
        except json.decoder.JSONDecodeError:
            afl_input_sizes = {}
        afl_input_sizes[filename] = get_afl_input_size()
        json.dump(afl_input_sizes, afl_input_sizes_json, indent=4, sort_keys=True)


def get_afl_input_size() -> int:
    """
    This function calculates the size in bytes of the afl input list.

    :return: Size of afl_input in bytes
    :rtype: int
    """
    ALF_INPUT_SIZES = {"string": 10, "integer": 2, "double": 8}
    return functools.reduce((lambda x, y: x + ALF_INPUT_SIZES[y]), afl_input_types, 0)


def parse_args() -> argparse.Namespace:
    """
    This function initializes all command line arguments of this script and parses them into a more flexible object.

    :return: A Namespace object of all given arguments
    :rtype: argparse.Namespace
    """
    parser = argparse.ArgumentParser(
        description="Convert interesting js files (e.g. from Fuzzili) into format fuzzable by this AFL setup."
    )
    parser.add_argument(
        "filenames",
        metavar="FILE",
        type=str,
        nargs="+",
        help="the file name(s) of interesting sample js files",
    )
    output_file_group = parser.add_mutually_exclusive_group(required=True)
    output_file_group.add_argument(
        "-i",
        "--in-place",
        action="store_true",
        help="whether the output should be directly written to the input file",
    )
    output_file_group.add_argument(
        "-o",
        "--out-dir",
        metavar="OUT_DIR",
        type=validate_out_dir,
        nargs=1,
        help="an output directory",
    )
    return parser.parse_args()


def validate_filename(filename: str) -> str:
    """
    This function validates whether a given filename exists and is a valid JavaScipt file.

    :raises argparse.ArgumentTypeError: Error if argument filename is not valid

    :return: The unchanged filename
    :rtype: str
    """
    if not os.path.isfile(filename):
        raise argparse.ArgumentTypeError(f'"{filename}" is not a valid file.')
    _, file_extension = os.path.splitext(filename)
    if file_extension != ".js":
        raise argparse.ArgumentTypeError(
            f'"{filename}" is not a valid JavaScript file.'
        )
    return filename


def validate_out_dir(out_dir: str) -> str:
    """
    This function validates whether the out_dir is a valid directory and appends a trailing slash if necessary.

    :raises argparse.ArgumentTypeError: Error if argument out_dir is not valid

    :return: The out directory with trailing slash
    :rtype: str
    """
    if not os.path.isdir(out_dir):
        raise argparse.ArgumentTypeError(f'"{out_dir}" is not a valid directory.')
    return our_dir if out_dir.endswith("/") else out_dir + "/"


if __name__ == "__main__":
    main(parse_args())
    sys.exit(0)
