#!/usr/bin/env python
from __future__ import print_function
from github import Github
from os.path import expanduser
from datetime import datetime
from socket import setdefaulttimeout

from es_utils import send_payload, get_payload_wscroll
from hashlib import sha1
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
    print("User: ", gh.get_organization())

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
    unique_id = JENKINS_PREFIX + "/" + str(reset_time).split(" ")[0].replace("-","") + "/" + str(reset_time).split(" ")[1].replace(":","") + "/" + str(remaining)
    unique_id = sha1(unique_id.encode()).hexdigest()
    print(unique_id)
    payload = dict()
    payload["jenkins_server"] = JENKINS_PREFIX
    payload["api_limit"] = limit
    payload["api_remaining"] = remaining
    payload["reset_time"] = str(reset_time)
    payload["@timestamp"] = current_time

    print(payload)
    
    send_payload(gh_api_index, gh_api_document, unique_id, json.dumps(payload))

    query = (
        """{
    "query": {"bool": {"must": {"query_string": {"query": "_index:cmssdt-github-api-* AND jenkins_server:%s", "default_operator": "AND"}}}},
    "from": 0,
    "size": 10000
    }"""
        % JENKINS_PREFIX
    )

    content_hash = get_payload_wscroll("cmssdt-github-api-*", query)
    if content_hash:
        if (not "hits" in content_hash) or (not "hits" in content_hash["hits"]):
            print("ERROR: ", content_hash)
            sys.exit(1)

    print("Found " + str(len(content_hash["hits"]["hits"])) + " entries!")
    for hit in content_hash["hits"]["hits"]:
        print(hit)
        print(hit["_source"])
