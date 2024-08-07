import os
import subprocess
import argparse

def main():
    parser = argparse.ArgumentParser(description="Run Python formatting and linting.")

    # Define the arguments
    parser.add_argument(
        "--inputfile",
        required=True,
        help="Path to the file containing the list of files to process.",
    )
    parser.add_argument(
        "--cmsswbase",
        required=True,
        help="Path to the CMSSW base directory.",
    )
    parser.add_argument(
        "--outputfile",
        required=True,
        help="Path to the output file.",
    )

    # Parse the arguments
    args = parser.parse_args()

    input_file = args.inputfile
    cmssw_base = args.cmsswbase
    output_file = args.outputfile

    # Check if the input file exists
    if not os.path.isfile(input_file):
        print("Error: " + input_file + " does not exist.")
        return

    # Read the list of files from the input file
    try:
        with open(input_file, "r") as file:
            files_list = [os.path.join(cmssw_base, line.strip()) for line in file.readlines()]
    except IOError as e:
        print("Error reading " + input_file + ": " + str(e))
        return

    # Ensure the directory for the output file exists
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
        except OSError as e:
            print("Error creating directory " + output_dir + ": " + str(e))
            return

    # Run the external script and redirect output to the specified output file
    try:
        subprocess.run(
            ["python", "../cms-bot/PFA.py"] + files_list + ["--outputfile", output_file],
            check=True,
        )
        print("Successfully processed files. Output saved to " + output_file + ".")
    except subprocess.CalledProcessError as e:
        print("An error occurred while running PFA.py: " + str(e))

if __name__ == "__main__":
    main()
    