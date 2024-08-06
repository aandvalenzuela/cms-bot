import os
import subprocess
import argparse
'''
This script should accept a -f option that specifies the path to a file containing a list of file paths to process.
Run: python run-python-format.py -f/--file code-checks-files.txt
'''
def main():
    parser = argparse.ArgumentParser(description="Run Python formatting and linting.")
    parser.add_argument('-f', '--file', help="Path to the file containing the list of files to process.", required=True) # Will not run without argument
    args = parser.parse_args()

    fileName = args.file
    basePath = "/home/bkristinsson/cmssw"

    # Check if the file exists
    if not os.path.isfile(fileName):
        print("Error:" + fileName + "does not exist.")
        return

    # Read the list of files from the file
    with open(fileName, 'r') as file:
        files_list = [os.path.join(basePath, line.strip()) for line in file.readlines()]

    try:
        subprocess.run(['python', 'PFA.py'] + files_list, check=True)
    except subprocess.CalledProcessError as e:
        print("An error occurred while running PFA.py:" + e)



if __name__ == "__main__":
    main()
