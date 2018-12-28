import os, json, sys, re
import time
from pathlib import Path
import logging
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler, FileSystemEventHandler
from typing import NamedTuple, List, Optional, Dict, Any, Iterator, Pattern
from dir_watch_objects import LoggingSelectiveEventHandler, WatchConfig, DirWatchDog, get_watch_config
islinux: bool = 'nux' in sys.platform

import getopt
from vedis import Vedis # pylint: disable=E0611
from collections import namedtuple

def usage(msg):
    if msg:
        print(msg)
    else:
        print("usage: dir_watcher.py --config /path-which-exists")

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "", [
                                   "help", "action=", "config=", "asservice", "debug"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print(str(err))  # will print something like "option -a not recognized"
        sys.exit(2)
    asservice = None
    action = None
    log_level = logging.WARNING
    config: Optional[str] = None
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage(None)
            sys.exit()
        elif o == '--asservice':
            asservice = True
        elif o == '--action':
            action = a
        elif o == '--config':
            config = a
        elif o == '--debug':
            log_level = logging.DEBUG
        else:
            assert False, "unhandled option"
    wc: WatchConfig = get_watch_config(config)
    logging.basicConfig(level=log_level,
                        format='%(asctime)s - %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')
    wd = DirWatchDog(wc)
    if asservice:
        pass
    else:
        print('starting inactive.')
        wd.watch()

# if islinux:
#     import daemon # pylint: disable=E0401
# else:
#     import win32service # pylint: disable=E0401
#     import win32serviceutil # pylint: disable=E0401
#     import win32event # pylint: disable=E0401
        # if islinux:
        #     print("start daemonize pidfile is %s" % wc.pidfile)
        #     with daemon.DaemonContext(pidfile='/home/osboxes/wd.pid'):
        #         print("start daemonize logfile is %s" % wc.logfile)
        #         logging.basicConfig(level=logging.INFO,
        #                             filename=wc.logfile,
        #                             format='%(asctime)s - %(message)s',
        #                             datefmt='%Y-%m-%d %H:%M:%S')
        #         print("starting.....")
        #         wd.watch()
        # else:
        #     win32serviceutil.HandleCommandLine(WatchDogSvc, argv=["install"])

# nt.stat_result(st_mode=33206, st_ino=0L, st_dev=0L, st_nlink=0, st_uid=0, 
# st_gid=0, st_size=1907L, st_atime=1545382009L, st_mtime=1545369026L, st_ctime=1348715808L)
# def stat_to_dict(stat):
#     h =  {
#         "st_mode": str(stat.st_mode),
#         "st_ino": str(stat.st_ino),
#         "st_dev": str(stat.st_dev),
#         "st_nlink": str(stat.st_nlink),
#         "st_uid": str(stat.st_uid),
#         "st_gid": str(stat.st_gid),
#         "st_size": str(stat.st_size),
#         "st_atime": str(stat.st_atime),
#         "st_mtime": str(stat.st_mtime),
#         "st_ctime": str(stat.st_ctime)
#     }
#     return h

# http://www.chrisumbel.com/article/windows_services_in_python

# if not islinux:
#     class WatchDogSvc(win32serviceutil.ServiceFramework):
#             # you can NET START/STOP the service by the following name
#         _svc_name_ = "WatchDogSvc"
#         # this text shows up as the service name in the Service
#         # Control Manager (SCM)
#         _svc_display_name_ = "Python watchdog Service"
#         # this text shows up as the description in the SCM
#         _svc_description_ = "This service watch file changes, and save the result the vedis db."

#         def __init__(self, args):
#             win32serviceutil.ServiceFramework.__init__(self, args)
#             # create an event to listen for stop requests on
#             # self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)

#         # core logic of the service
#         def SvcDoRun(self):
#             pass
#             # DirWatchDog.watch()
#             # import servicemanager
#             # rc = None
#             # if the stop event hasn't been fired keep looping
#             # while rc != win32event.WAIT_OBJECT_0:
#                 # block for 5 seconds and listen for a stop event
#                 # rc = win32event.WaitForSingleObject(self.hWaitStop, 5000)
#             # Gns.stop = True

#         # called when we're being shut down
#         def SvcStop(self):
#             # tell the SCM we're shutting down
#             self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
#             # fire the stop event
#             DirWatchDog.save_me = False
#             # win32event.SetEvent(self.hWaitStop)
