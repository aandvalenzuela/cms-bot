import os
import subprocess

fileName = "code-checks-files.txt"
basePath = "/home/bkristinsson/cmssw"

# Check if the file exists
if not os.path.isfile(fileName):
    print(f"Error: {fileName} does not exist.")
else:
    # Read the list of files from the file
    with open(fileName, 'r') as files:
        files_list = [os.path.join(basePath, line.strip()) for line in files.readlines()]

    # Debug: Print the list of files
    #print("Files to process:", files_list)
    #print(f"Type of processing element: {type(files_list)}")

    # Print each file path
    #for file_path in files_list:
    #    print(f"Path to file: {file_path}")

    # Run the command with the list of files using subprocess
    try:
        subprocess.run(['python', 'PFA.py'] + files_list, check=True)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred while running PFA.py: {e}")

