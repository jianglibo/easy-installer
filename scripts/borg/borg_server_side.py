#!/usr/bin/python

import sys
import getopt
import os
from global_static import PyGlobal
import common_util

PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
common_util.get_configration(PyGlobal.config_file, "utf-8", True)


def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'Archive':
        pass
    elif action == 'Prune':
        pass
    elif action == 'DiskFree':
        pass
    elif action == 'MemoryFree':
        pass
    elif action == 'DownloadPublicKey':
        pass
    elif action == 'Echo':
        common_util.send_lines_to_client(' '.join(args))
    

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
