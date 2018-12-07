#!/usr/bin/python

import sys
import getopt
import os
from global_static import PyGlobal
import common_util
import subprocess
import json
import shutil
import tempfile

PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
common_util.get_configration(PyGlobal.config_file, "utf-8", True)
j = PyGlobal.configuration.json
repo_path = j['BorgRepoPath']
borg_bin = j['BorgBin']
os_config = PyGlobal.configuration.get_os_config()
server_side = os_config["ServerSide"]

def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'Archive':
        common_util.send_lines_to_client(new_borg_archive())
    elif action == 'Prune':
        common_util.send_lines_to_client(invoke_prune())
    elif action == 'DiskFree':
        common_util.send_lines_to_client(common_util.get_diskfree())
    elif action == 'MemoryFree':
        common_util.send_lines_to_client(common_util.get_memoryfree())
    elif action == 'InitializeRepo':
        common_util.send_lines_to_client(init_borg_repo())
    elif action == 'DownloadPublicKey':
        common_util.send_lines_to_client(get_openssl_publickey())
    elif action == 'Install':
        common_util.send_lines_to_client(install_borg())
    elif action == 'FileHashes':
        common_util.send_lines_to_client(common_util.get_filehashes(args[0]))
    elif action == 'Echo':
        common_util.send_lines_to_client(' '.join(args))

def get_openssl_publickey():
    openssl_exec = j["openssl"]
    private_key_file = j["PrivateKeyFile"]
    with tempfile.NamedTemporaryFile(delete=False) as tf:
        subprocess.call([openssl_exec, 'rsa', '-in' , private_key_file, '-pubout', '-out', tf.name])
        return tf.name

def install_borg():
    if os.path.exists(borg_bin):
        common_util.send_lines_to_client("AlreadyInstalled")
    else:
        common_util.get_software_packages(server_side["PackageDir"], os_config["Softwares"])
        pk = common_util.get_software_package_path()
        shutil.copy(pk, borg_bin)
        subprocess.call(['chmod', '755', borg_bin])
        common_util.send_lines_to_client("Install Success.")
    

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
