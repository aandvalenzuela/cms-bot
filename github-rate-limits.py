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
    current_time = datetime.utcnow() - datetime(1970, 1, 1)
    current_time = round(current_time.total_seconds() * 1000)
    
    gh_api_index = "cmssdt-github-api-" + str(int(((current_time / 86400000) + 4) / 7))
    gh_api_document = "github-api-data"
    unique_id = JENKINS_PREFIX + "/" + str(reset_time).split(" ")[0] + "/" + str(reset_time).split(" ")[1] + "/" + str(remaining)
    print(unique_id)
    
    payload = dict()
    payload["jenkins_server"] = JENKINS_PREFIX
    payload["api_limit"] = limit
    payload["api_remaining"] = remaining
    payload["reset_time"] = str(reset_time)

    print(payload)
    
    send_payload(gh_api_index, gh_api_document, unique_id, json.dumps(payload))
