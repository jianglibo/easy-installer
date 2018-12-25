import os, json, sys
import time
from pathlib import Path
import logging
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler
from typing import NamedTuple, List, Optional, Dict, Any, Iterator
islinux: bool = 'nux' in sys.platform
# if islinux:
#     import daemon # pylint: disable=E0401
# else:
#     import win32service # pylint: disable=E0401
#     import win32serviceutil # pylint: disable=E0401
#     import win32event # pylint: disable=E0401
import getopt
from vedis import Vedis # pylint: disable=E0611
from collections import namedtuple

WatchPath: NamedTuple = NamedTuple('WatchPath', [
    ('regexes', List[str]),
    ('ignore_regexes', List[str]),
    ('ignore_directories', bool),
    ('case_sensitive', bool),
    ('path', Path),
    ('recursive', bool)])

class WatchConfig():
    def __init__(self, jdict) -> None:
        self.vedisdb: Path = Path(jdict['vedisdb']).expanduser()
        self.logfile: Optional[Path] = Path(jdict['logfile']).expanduser() if jdict['logfile'] else None
        wps: List[Dict[str, Any]] = jdict['watch_paths']
        for wp in wps:
            wp['path'] = Path(wp['path']).expanduser()
        self.watch_paths: List[WatchPath] = [WatchPath(**p) for p in wps]
        self.pidfile = Path(jdict['pidfile']).expanduser() if jdict['pidfile'] else None

    def get_un_exists_paths(self) -> List[WatchPath]:
        return [wp for wp in self.watch_paths if not wp.path.exists()]

# nt.stat_result(st_mode=33206, st_ino=0L, st_dev=0L, st_nlink=0, st_uid=0, 
# st_gid=0, st_size=1907L, st_atime=1545382009L, st_mtime=1545369026L, st_ctime=1348715808L)
def stat_to_dict(stat):
    h =  {
        "st_mode": str(stat.st_mode),
        "st_ino": str(stat.st_ino),
        "st_dev": str(stat.st_dev),
        "st_nlink": str(stat.st_nlink),
        "st_uid": str(stat.st_uid),
        "st_gid": str(stat.st_gid),
        "st_size": str(stat.st_size),
        "st_atime": str(stat.st_atime),
        "st_mtime": str(stat.st_mtime),
        "st_ctime": str(stat.st_ctime)
    }
    return h
    

class LoggingSelectiveEventHandler(RegexMatchingEventHandler):
    """
    Logs all the events captured.
    """
    def __init__(self,db: Vedis, regexes: List[str]=[r".*"], ignore_regexes: List[str]=[],
                 ignore_directories: bool =False, case_sensitive: bool=False):
        super(LoggingSelectiveEventHandler, self).__init__(regexes=regexes,
                                                           ignore_regexes=ignore_regexes,
                                                           ignore_directories=ignore_directories,
                                                           case_sensitive=case_sensitive)
        self.db = db
        logging.info("create regexes: %s, ignore_regexes: %s", regexes, ignore_regexes)
    
    def stat_tostring(self, a_path):
        try:
            stat = os.stat(a_path)
            return "%s,%s" % (stat.st_size, stat.st_mtime)
        except:
            return None

    def on_moved(self, event):
        # super(LoggingSelectiveEventHandler, self).on_moved(event)
        what = 'directory' if event.is_directory else 'file'
        logging.info("Moved %s: from %s to %s", what, event.src_path,
                     event.dest_path)
        self.db.sadd('moved', "%s|%s" % (event.src_path, event.dest_path))
        self.db.commit()

    def on_created(self, event):
        # super(LoggingSelectiveEventHandler, self).on_created(event)
        what = 'directory' if event.is_directory else 'file'
        logging.info("Created %s: %s", what, event.src_path)
        self.db.sadd('created', event.src_path)
        self.db.commit()

    def on_deleted(self, event):
        # super(LoggingSelectiveEventHandler, self).on_deleted(event)
        self.db.sadd('deleted', event.src_path)
        self.db.commit()
        what = 'directory' if event.is_directory else 'file'
        logging.info("Deleted %s: %s", what, event.src_path)

    def on_modified(self, event):
        # super(LoggingSelectiveEventHandler, self).on_modified(event)
        src_path = event.src_path
        what = 'directory' if event.is_directory else 'file'
        size_mtime = self.db.hget("modified", src_path)
        if size_mtime is None:
            size_mtime = self.stat_tostring(src_path)
            if size_mtime is None:
                logging.error("stat error %s: %s", what, src_path)
            else:
                self.db.hset("modified", src_path, size_mtime)
            logging.info("Modified Not in db %s: %s", what, src_path)
        else:
            self.db.incr(src_path)
            n_size_time = self.stat_tostring(src_path)
            if size_mtime == n_size_time:
                logging.info("Modified size_time not changed. %s: %s", what, src_path)
            else:
                logging.info("Modified Truely %s: %s", what, src_path)
                self.db.sadd('true-modified', src_path)
                self.db.commit()

# http://www.chrisumbel.com/article/windows_services_in_python

class DirWatchDog():

    def __init__(self, wc: WatchConfig) -> None:
        self.wc = wc
        self.db = Vedis(wc.vedisdb)
        self.save_me = True

    def watch(self) -> None:
        observers = []
        for ps in self.wc.watch_paths:
            event_handler = LoggingSelectiveEventHandler(
                self.db,
                regexes=ps.regexes,
                ignore_regexes=ps.ignore_regexes,
                ignore_directories=ps.ignore_directories,
                case_sensitive=ps.case_sensitive)
            path_to_observe: str = str(ps.path)
            observer = Observer()
            observer.schedule(event_handler, path_to_observe, recursive=ps.recursive)
            observer.start()
            observers.append(observer)
        try:
            while self.save_me:
                time.sleep(1)
            else:
                for obs in observers:
                    obs.stop()
                self.db.close()
        except KeyboardInterrupt:
            for obs in observers:
                obs.stop()
            self.db.close()

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


def usage(msg):
    if msg:
        print(msg)
    else:
        print("usage: dir_watcher.py --config /path-which-exists")


if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "", [
                                   "help", "action=", "config=", "asservice"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print(str(err))  # will print something like "option -a not recognized"
        sys.exit(2)
    asservice = None
    action = None
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
        else:
            assert False, "unhandled option"

    cp: Path
    if not config:
        if getattr(sys, 'frozen', False):
            # frozen
            f_ = Path(sys.executable)
        else:
            # unfrozen
            f_ = Path(__file__)
        cp = f_.parent / "dir_watcher.json"
    else:
        cp = Path(config)

    if not cp.exists():
        usage("config file %s doesn't exists." % config)
        sys.exit(0)
    print("with config file %s" % cp.absolute())

    with cp.open() as f:
        content = f.read()

    j: Dict[str, Any] = json.loads(content)
    wc = WatchConfig(j)
    un_exist_watch_paths = wc.get_un_exists_paths()
    
    if len(un_exist_watch_paths) > 0:
        usage("these watch_paths %s doesn't exists." % un_exist_watch_paths)
        sys.exit(0)
    
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')
    wd = DirWatchDog(wc)
    if asservice:
        pass
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
    else:
        print('starting inactive.')
        wd.watch()
