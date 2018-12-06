#!/usr/bin/python

import sys
import getopt
import os
from global_static import PyGlobal
import common_util
import subprocess
import json

PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
common_util.get_configration(PyGlobal.config_file, "utf-8", True)
j = PyGlobal.configuration.json
repo_path = j['BorgRepoPath']
borg_bin = j['BorgBin']

def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'Archive':
        common_util.send_lines_to_client(new_borg_archive())
    elif action == 'Prune':
        common_util.send_lines_to_client(invoke_prune())
    elif action == 'DiskFree':
        pass
    elif action == 'MemoryFree':
        pass
    elif action == 'InitializeRepo':
        common_util.send_lines_to_client(init_borg_repo())
        pass
    elif action == 'DownloadPublicKey':
        pass
    elif action == 'FileHashes':
        common_util.send_lines_to_client(common_util.get_filehashes(args[0]))
    elif action == 'Echo':
        common_util.send_lines_to_client(' '.join(args))

def new_borg_archive():
    j = PyGlobal.configuration.json
    repo_path = j['BorgRepoPath']
    borg_bin = j['BorgBin']
    bout = subprocess.check_output([borg_bin, 'list', '--json', repo_path])
    result_json = json.loads(bout)
    archives = result_json['archives']
    if (archives and (len(archives) > 0)):
        archive_name = str(int(archives[-1]['name']) + 1)
    else:
        archive_name = "1"
    create_cmd = j['BorgCreate'] % (borg_bin, repo_path, archive_name)
    return subprocess.check_output(create_cmd, shell=True)

def invoke_prune():
    j = PyGlobal.configuration.json
    repo_path = j['BorgRepoPath']
    borg_bin = j['BorgBin']
    prune_cmd = j['BorgPrune'] % (borg_bin, repo_path)
    subprocess.check_output(prune_cmd, shell=True)
    list_cmd = j['BorgList'] %  (borg_bin, repo_path)
    return subprocess.check_output(list_cmd, shell=True)

def init_borg_repo():
    init_cmd = [borg_bin, 'init', '--encryption=none', repo_path]
    try:
        subprocess.check_output(init_cmd)
        return 'SUCCESS'
    except subprocess.CalledProcessError as cpe:
        return cpe


if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hv:a:", ["help", "action="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    verbose = False
    action = None
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("--action", '-a'):
            action = a
        else:
            assert False, "unhandled option"
    main(action, args)
