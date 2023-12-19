#!/usr/bin/env python
from __future__ import print_function
from github import Github
from os.path import expanduser, abspath, dirname, join, exists
import sys, re, json
from argparse import ArgumentParser
from _py2with3compatibility import run_cmd, quote
from github_utils import add_issue_labels, create_issue_comment, get_issue_labels

SCRIPT_DIR = dirname(abspath(sys.argv[0]))

parser = ArgumentParser()
parser.add_argument(
    "-r", "--repository", dest="repo", help="Github Repositoy name e.g cms-sw/cms-bot", type=str
)
parser.add_argument(
    "-m",
    "--message",
    dest="msg",
    help="Message to be posted at the GH issue",
    type=str,
    default="",
)
parser.add_argument(
    "-l",
    "--labels",
    dest="labels",
    nargs='*',
    help="Labels for the GH issue (undefined number)",
    default="",
)

args = parser.parse_args()
mgs = ""
if not args.repo:
    parser.error("Missing Repo")
if not args.labels:
    parser.error("Missing Issue Labels")
if args.msg:
    msg = re.sub("@N@", "\n", args.msg)
else:
    parser.error("Missing issue message: -m|--message <message>")

print("Authenticating to Github and connecting to repo")
repo_dir = join(SCRIPT_DIR, "repos", args.repo.replace("-", "_"))
if exists(join(repo_dir, "repo_config.py")):
    sys.path.insert(0, repo_dir)
import repo_config

gh = Github(login_or_token=open(expanduser(repo_config.GH_TOKEN)).read().strip())
gh_repo = gh.get_repo(args.repo)
print("Authentication succeeeded to " + str(gh_repo))

label_str = "+label:".join([""] + [str(label) for label in args.labels])
print(label_str)

issues_curl = (
    "curl -s 'https://api.github.com/search/issues?q=+repo:%s+in:title+type:issue%s'" % (args.repo, label_str)
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
  print("Adding issue comment...")
  issue_title = issues_dict["items"][0]["title"]
  print(issue_title)
  issue_number = issues_dict["items"][0]["number"]
  print(issue_number)
  print("MESSAGE: ", msg)
  create_issue_comment(gh_repo.full_name, issue_number, msg)

