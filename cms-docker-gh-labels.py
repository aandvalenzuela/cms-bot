#!/usr/bin/env python
from __future__ import print_function
from github import Github
from os.path import expanduser, abspath, dirname, join, exists
import sys, re, json, glob
from argparse import ArgumentParser
from _py2with3compatibility import run_cmd
from github_utils import add_issue_labels, remove_issue_label

SCRIPT_DIR = dirname(abspath(sys.argv[0]))

parser = ArgumentParser()
parser.add_argument(
    "-r",
    "--repository",
    dest="repo",
    help="Github Repositoy name e.g cms-sw/cms-bot",
    type=str,
)
parser.add_argument(
    "-l",
    "--labels",
    dest="labels",
    nargs="*",
    help="Labels for the GH issue (undefined number)",
    default="",
)
parser.add_argument(
    "-a", "--add-label", dest="add", help="Labels to add", type=str, default="",
)
parser.add_argument(
    "-d", "--delete-label", dest="delete", help="Delete existing label", type=str, default="",
)

args = parser.parse_args()
if not args.repo:
    parser.error("Missing Repo")

print("Authenticating to Github and connecting to repo")
repo_dir = join(SCRIPT_DIR, "repos", args.repo.replace("-", "_"))
if exists(join(repo_dir, "repo_config.py")):
    sys.path.insert(0, repo_dir)
import repo_config

gh = Github(login_or_token=open(expanduser(repo_config.GH_TOKEN)).read().strip())
gh_repo = gh.get_repo(args.repo)
print("Authentication succeeeded to " + str(gh_repo.full_name))

label_str = "+label:".join([""] + [str(label) for label in args.labels])

issues_curl = (
    "curl -s 'https://api.github.com/search/issues?q=+repo:%s+in:title+type:issue%s'"
    % (args.repo, label_str,)
)

print("Checking existing Issue", issues_curl)
exit_code, issues_obj = run_cmd(issues_curl)
print(issues_obj)

issues_dict = json.loads(issues_obj)
print("Existing Issues: " + str(issues_dict["total_count"]))

# We should have only one matching issue
assert issues_dict["total_count"] <= 1

if issues_dict["total_count"] == 0:
    print("No matching issues found, skipping...")
else:
    issue_number = issues_dict["items"][0]["number"]
    print(gh_repo.full_name)
    print(issue_number)
    if args.delete != "":
        print("Deleting label...")
        print(args.delete)
        #try:
        remove_issue_label(gh_repo.full_name, issue_number, [str(args.delete)])
        #except:
        #    print("Label not present")

    print("Adding label...")
    print(args.add)
    add_issue_labels(gh_repo.full_name, issue_number, [str(args.add)])
