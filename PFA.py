#!/usr/bin/python3

import os
import subprocess
import argparse


# Function to get the absolute path of a file
def find_file_path(file):
    return os.path.realpath(file)


# Function to search for .py files in a given directory
def find_python_files(directory):
    """Searches for all .py files in a given directory"""
    py_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".py"):
                py_files.append(os.path.join(root, file))
    return py_files


# Code quality checker
def CodeQualityChecks(python_files, output_file):
    if python_files:
        with open(output_file, "w") as out_file:
            for file in python_files:
                # Find the full path of the file
                file_path = find_file_path(file)
                if not file_path:
                    print("File " + file + " not found.")
                    continue

                # Formatting the code
                #codeFormat = subprocess.run(
                #    ["ruff", "format", file_path],
                #    stdout=subprocess.PIPE,
                #    stderr=subprocess.PIPE,
                #    text=True,
                #)
                os.system("black " + file_path)
                #os.system("ruff format " + file_path)

                # Linting the code
                codelinting = subprocess.run(
                    ["ruff", "check", "--fix", file_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                # git diff of quality checked code online and offline
                command = "pushd /home/bkristinsson/cmssw && git diff && popd"
                gitdiff_Receipt = subprocess.run(
                    command,
                    shell=True,
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )

                # Write results to the output file
                out_file.write("Changes for file: " + file_path + "\n")
                out_file.write(gitdiff_Receipt.stdout)
                out_file.write("\n")


# Main function to parse arguments and call other functions
def main():
    parser = argparse.ArgumentParser(
        description="Linting and formatting Python files in directories or file paths."
    )
    parser.add_argument(
        "paths", nargs="+", help="List of directories or file paths to process"
    )
    # for the outputfile given
    parser.add_argument(
        "--outputfile",
        required=True,
        help="Path to the output file.",
    )
    args = parser.parse_args()

    all_python_files = []
    for path in args.paths:
        if os.path.isdir(path):
            all_python_files.extend(find_python_files(path))
        elif os.path.isfile(path):
            all_python_files.append(path)
        else:
            print("Error: " + path + " is not a valid file or directory.")
            return

    CodeQualityChecks(all_python_files, args.outputfile)


# Entry point of the script !always at the end.
if __name__ == "__main__":
    main()
