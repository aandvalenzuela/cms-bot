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


# Function to lint Python files and write results to a receipt file
def lint_files(python_files):
    if python_files:
        with open("Linting_receipt.txt", "w") as receipt_file:
            for file in python_files:
                if os.path.basename(file) == "PFA.py":
                    continue
                receipt_file.write(f"\nLinting subject: {file}")
                linting_result = subprocess.run(
                    ["ruff", "check", "--diff", find_file_path(file)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                receipt_file.write(linting_result.stdout)
                print(f"File --> {file} linting successful.")
                if linting_result.stderr:
                    receipt_file.write("\nErrors: ")
                    receipt_file.write(linting_result.stderr)


# Function to format Python files and write results to a receipt file
def format_files(python_files):
    if python_files:
        with open("Formatting_receipt.txt", "w") as receipt_file:
            for file in python_files: #PFA
                if os.path.basename(file) == "PFA.py":
                    continue
                receipt_file.write(f"\nFormatting subject: {file}")
                formatting_result = subprocess.run(
                    ["ruff", "format", "--diff", find_file_path(file)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                receipt_file.write(formatting_result.stdout)
                print(f"File --> {file} formatting successful.")
                if formatting_result.stderr:
                    receipt_file.write("\nErrors: ")
                    receipt_file.write(formatting_result.stderr)


#Code quality checker
def CodeQualityChecks(python_files):
    if python_files:
        for file in python_files:
            # Find the full path of the file
            file_path = find_file_path(file)
            if not file_path:
                print(f"File {file} not found.")
                continue

            # Formatting the code
            codeFormat = subprocess.run(
                ["ruff", "format", find_file_path(file)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            # Linting the code
            codelinting = subprocess.run(
                ["ruff", "check", "--fix", find_file_path(file)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            # git diff of quality checked code online and offline
            command = "pushd /home/bkristinsson/cmssw && git diff && popd" # Should change the hardcoded dir ->/home/bkristinsson/cmssw
            gitdiff_Receipt = subprocess.run(
                [command, find_file_path(file)],
                shell=True,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            with open("CQC_receipt.txt", "w") as diff_file:
                diff_file.write(gitdiff_Receipt.stdout)
                diff_file.write("\n")

# Main function to parse arguments and call other functions
def main():
    parser = argparse.ArgumentParser(
        description="Linting and formatting Python files in directories or file paths."
    )
    parser.add_argument(
        "paths", nargs="+", help="List of directories or file paths to process"
    )
    args = parser.parse_args()

    all_python_files = []
    for path in args.paths:
        if os.path.isdir(path):
            all_python_files.extend(find_python_files(path))
        elif os.path.isfile(path):
            all_python_files.append(path)
        else:
            print(f"Error: {path} is not a valid file or directory.")
            return
    CodeQualityChecks(all_python_files)

# Entry point of the script !always at the end.
if __name__ == "__main__":
    main()
