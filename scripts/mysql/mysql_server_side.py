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
import StringIO
import re
import io
import itertools

PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
if os.path.exists(PyGlobal.config_file):
    common_util.get_configration(PyGlobal.config_file, "utf-8", True)
    j = PyGlobal.configuration.json
    client_bin = j['ClientBin']
    os_config = PyGlobal.configuration.get_os_config()
    server_side = os_config["ServerSide"]



def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'Archive':
        common_util.send_lines_to_client(common_util.get_diskfree())
    elif action == 'GetMycnf':
        common_util.send_lines_to_client(get_mycnf_file())
    elif action == 'DownloadPublicKey':
        common_util.send_lines_to_client(get_openssl_publickey())
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

def get_enabled_version(lines):
    founded = []
    current_version = None
    for line in lines:
        line = line.strip()
        m = re.match('^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            if line == 'enabled=1' and current_version:
                founded.append(current_version)
                current_version = None
    return founded


def enable_repoversion(repo_file, version):
    common_util.backup_localdirectory(repo_file)
    lines = _enable_repoversion(repo_file, version)
    with io.open(repo_file, 'wb') as opened_file:
        opened_file.writelines(["%s%s" % (line, "\n") for line in lines])
    
def _enable_repoversion(repo_file, version):
    current_version = None
    with io.open(repo_file, mode='r') as opened_file:
        lines = [line.strip() for line in opened_file.readlines()]
        new_lines = []
    for line in lines:
        m = re.match('^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            m = re.match('^\[.*\]$', line)
            if m:
                current_version = 'others'
            else:
                m = re.match('^enabled=(0|1)$', line)
                if m:
                    if current_version == version:
                        line = 'enabled=1'
                    elif current_version != 'others':
                        line = 'enabled=0'
        new_lines.append(line)
    return new_lines
    

    





    
def get_mycnf_file():
    out = subprocess.check_output([client_bin, '--help'])
    sio = StringIO.StringIO(out)
    line = sio.readline()
    found = False
    result = None
    while line:
        line = line.strip()
        if found:
            result = line
            break
        if "Default options are read from the following files in the given order:" in line:
            found = True
        line = sio.readline()
    sio.close()
    results = result.split()
    for r in results:
        if os.path.exists(r):
            return r




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

