#!/usr/bin/env python
from __future__ import print_function
from github import Github
from os.path import expanduser, abspath, dirname, join, exists
import sys, re
from argparse import ArgumentParser
from _py2with3compatibility import run_cmd, quote

SCRIPT_DIR = dirname(abspath(sys.argv[0]))

parser = ArgumentParser()
parser.add_argument(
    "-r", "--repository", dest="repo", help="Github Repositoy name e.g cms-sw/cms-bot", type=str
)
parser.add_argument("-t", "--title", dest="title", help="Issue title", type=str)
parser.add_argument(
    "-m",
    "--message",
    dest="msg",
    help="Message to be posted s body of the GH issue",
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
if not args.title:
    parser.error("Missing PR title")
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

cmd = (
    "curl -s 'https://api.github.com/search/issues?q=+repo:%s+in:title+type:issue%s'" % (args.repo, label_str)
)

print("Checking existing Issue", cmd)
exit_code, output = run_cmd(cmd)
print(output)

issues_dict = dict(output)
print(type(issues_dict))
print(issues_dict)

print("Existing Issues: " + str(issues_dict["total_count"]))

# We should have only one matching issue
assert issues_dict["total_count"] <= 1

if issues_dict["total_count"] == 0:
    print("Creating issue request")
    gh_repo.create_issue(title=args.title, body=msg, labels=args.labels)
else:
    # Check state of the issue: open/closed/building...
    print(issues_dict["items"]["title"])
    print(issues_dict["items"]["number"])

    state = issues_dict["items"]["state"]
    print(state)
    if state == "open":
        print("Issue is already open... Nothing to do!")
    elif state == "close":
        print("Ready for building!")
        # Don't delete property files
        sys.exit(1)
        # Add "building" label

# Delete property files
sys.exit(0)
