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

PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
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

