#!/usr/bin/env python3

import argparse
import datetime
import functools
import json
import os
import re
import time

import helpers
import actions


def check_and_trigger_action(build_to_retry, job_dir, job_to_retry, error_list_action):
    """Check build logs and trigger the appropiate action if a known error is found."""
    build_dir_path = os.path.join(job_dir, build_to_retry)
    log_file_path = os.path.join(build_dir_path, "log")
    envvars_file_path = os.path.join(build_dir_path, "injectedEnvVars.txt")

    if not os.path.exists(log_file_path):
        return
    # TODO: Try not to load everything on memory
    text_log = open(log_file_path, errors="ignore")
    lines = text_log.readlines()
    text_log.close()

    job_url = (
        os.environ.get("JENKINS_URL") + "job/" + job_to_retry + "/" + build_to_retry
    )

    print("Parsing build #" + build_to_retry + " (" + job_url + ") ...")

    regex_flag = 0
    for error_and_action in error_list:
        regex_and_action = error_and_action.split(" - ")
        regex = regex_and_action[0]
        action = regex_and_action[1]
        for line in reversed(lines):
            if re.search(regex, line):
                print(
                    "... Found message "
                    + regex
                    + " in "
                    + log_file_path
                    + ". Taking action ..."
                )
                if action == "retryBuild":
                    actions.trigger_retry_action(
                        job_to_retry,
                        build_to_retry,
                        build_dir_path,
                        action,
                        regex,
                        force_retry_regex,
                    )
                else:
                    # Take action on the nodes
                    node_name = (
                        helpers.grep(envvars_file_path, "NODE_NAME=", True)
                        .split("=")[1]
                        .replace("\n", "")
                    )
                    job_url = (
                        os.environ.get("JENKINS_URL")
                        + "job/"
                        + job_to_retry
                        + "/"
                        + build_to_retry
                    )
                    node_url = os.environ.get("JENKINS_URL") + "computer/" + node_name
                    parser_url = (
                        os.environ.get("JENKINS_URL")
                        + "job/jenkins-test-parser/"
                        + parser_build_id
                    )

                    if action == "nodeOff":
                        actions.trigger_nodeoff_action(
                            job_to_retry, build_to_retry, job_url, node_name
                        )
                        actions.trigger_retry_action(
                            job_to_retry,
                            build_to_retry,
                            build_dir_path,
                            action,
                            regex,
                            force_retry_regex,
                        )
                        actions.notify_nodeoff(
                            node_name,
                            regex,
                            job_to_retry,
                            build_to_retry,
                            job_url,
                            node_url,
                            parser_url,
                        )
                    elif action == "nodeReconnect":
                        actions.trigger_reconnect_action(
                            job_to_retry, build_to_retry, job_url, node_name
                        )
                        actions.trigger_retry_action(
                            job_to_retry,
                            build_to_retry,
                            build_dir_path,
                            action,
                            regex,
                            force_retry_regex,
                        )
                        actions.notify_nodereconnect(
                            node_name,
                            regex,
                            job_to_retry,
                            build_to_retry,
                            job_url,
                            node_url,
                            parser_url,
                        )

                regex_flag = 1
                break
            if regex_flag == 1:
                break
        if regex_flag == 1:
            break
    if regex_flag == 0:
        print("... no known errors were found.")

        if helpers.grep(os.path.join(build_dir_path, "build.xml"), "<result>FAILURE"):
            # Update description to inform that no action has been taken
            actions.update_no_action_label(job_to_retry, build_to_retry)


def check_running_time(job_dir, build_to_retry, job_to_retry, max_running_time=18):
    """Check builds running time and notify in case it exceeds the maximum time defined (default max time = 18h)."""
    job_url = (
        os.environ.get("JENKINS_URL") + "job/" + job_to_retry + "/" + build_to_retry
    )
    parser_url = (
        os.environ.get("JENKINS_URL") + "job/jenkins-test-parser/" + parser_build_id
    )

    if os.path.exists(
        functools.reduce(os.path.join, [job_dir, build_to_check, "email.done"])
    ):
        print(
            "... Email notification already send for build #"
            + build_to_retry
            + " ("
            + job_url
            + ")."
        )
        return

    build_file_path = functools.reduce(
        os.path.join, [job_dir, build_to_check, "build.xml"]
    )

    start_timestamp = (
        helpers.grep(build_file_path, "<startTime>", True)
        .replace("<startTime>", "")
        .replace("</startTime>", "")
    )

    display_name = (
        helpers.grep(build_file_path, "<displayName>", True)
        .replace("<displayName>", "")
        .replace("</displayName>", "")
        .replace("\n", "")
    )

    start_datetime = datetime.datetime.fromtimestamp(int(start_timestamp) / 1000)
    now = datetime.datetime.now()
    duration = now - start_datetime

    if duration > datetime.timedelta(hours=max_running_time):

        print(
            "Build #"
            + build_to_retry
            + " ("
            + job_url
            + ") has been running for more than "
            + str(max_running_time)
            + " hours!"
        )

        # Create parser.done file
        fp = open(
            functools.reduce(os.path.join, [job_dir, build_to_retry, "email.done"]), "x"
        )
        fp.close()

        actions.notify_pendingbuild(
            display_name, build_to_retry, job_to_retry, duration, job_url, parser_url,
        )

    else:
        print(
            "... Build #"
            + build_to_retry
            + " ("
            + job_url
            + ")"
            + " has been running for "
            + str(duration)
            + " hours ... OK"
        )


if __name__ == "__main__":

    # Parsing the build id of the current job
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "parser_build_id", help="Input current build id from Jenkins env vars"
    )
    args = parser.parse_args()
    parser_build_id = args.parser_build_id

    # Define paths:
    jobs_config_path = "cms-bot/jenkins/parser/jobs-config.json"  # This file matches job with their known errors and the action to perform
    builds_dir = os.environ.get("HOME") + "/builds"  # Path to the actual build logs

    # Define e-mails to notify
    # email_addresses = "andrea.valenzuela.ramirez@cern.ch"

    with open(jobs_config_path, "r") as jobs_file:
        jobs_object = json.load(jobs_file)
        jenkins_jobs = jobs_object["jobsConfig"]["jenkinsJobs"]

        # Iterate over all the jobs jobs_object["jobsConfig"]["jenkinsJobs"][ii]["jobName"]
        for job_id in range(len(jenkins_jobs)):
            job_to_retry = jenkins_jobs[job_id]["jobName"]
            try:
                max_running_time = int(jenkins_jobs[job_id]["maxTime"])
            except KeyError:
                # The default max running time is 18h for all builds
                max_running_time = 18

            print("[" + job_to_retry + "] Processing ...")
            job_dir = os.path.join(builds_dir, job_to_retry)

            error_list, force_retry_regex = helpers.get_errors_list(jobs_object, job_id)

            finished_builds = helpers.get_finished_builds(job_dir)
            running_builds = helpers.get_running_builds(job_dir)

            print("Running builds are: ", running_builds)
            print("Finished builds are: ", finished_builds)

            for build_to_retry in sorted(finished_builds):
                check_and_trigger_action(
                    build_to_retry, job_dir, job_to_retry, error_list
                )

                # If notification.done exists, remove it.
                if os.path.isfile(
                    functools.reduce(
                        os.path.join, [job_dir, build_to_retry, "email.done"]
                    )
                ):
                    os.remove(
                        functools.reduce(
                            os.path.join, [job_dir, build_to_retry, "email.done"]
                        )
                    )

                # Create parser.done file
                fp = open(
                    functools.reduce(
                        os.path.join, [job_dir, build_to_retry, "parser.done"]
                    ),
                    "x",
                )
                fp.close()

                # Mark as retried
                actions.mark_build_as_retried(job_dir, job_to_retry, build_to_retry)

            for build_to_check in sorted(running_builds):
                check_running_time(
                    job_dir, build_to_check, job_to_retry, max_running_time
                )

    print("All jobs have been checked!")
