#!/usr/bin/env python
from __future__ import print_function
from github import Github
from os.path import expanduser
from datetime import datetime
from socket import setdefaulttimeout

from es_utils import send_payload
import json, os

setdefaulttimeout(120)

if __name__ == "__main__":
    gh = Github(login_or_token=open(expanduser("~/.github-token")).read().strip())
    print("API Rate Limit")
    remaining, limit = gh.rate_limiting
    print("Remaining: ", remaining)
    print("Limit: ", limit)
    reset_time = datetime.fromtimestamp(gh.rate_limiting_resettime)
    print("Reset time (GMT): ", reset_time)

    JENKINS_PREFIX = "jenkins"
    try:
        JENKINS_PREFIX = os.environ["JENKINS_URL"].strip("/").split("/")[-1]
    except:
        JENKINS_PREFIX = "jenkins"
    
    # gh_api_index = "cmssdt-github-api*"
    gh_api_index = "cmssdt-github-api-" + str(int(((current_time / 86400000) + 4) / 7))
    gh_api_document = "github-api-data"
    unique_id = JENKINS_PREFIX + "/" + str(reset_time) + "/" + str(remaining)
    
    payload = dict()
    payload["jenkins_server"] = JENKINS_PREFIX
    payload["api_limit"] = limit
    payload["api_remaining"] = remaining

    send_payload(gh_api_index, gh_api_document, unique_id, json.dumps(payload))
