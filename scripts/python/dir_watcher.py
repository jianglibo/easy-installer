import os, io, json, sys
import time
import logging
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler
islinux = 'nux' in sys.platform
if islinux:
    import daemon
else:
    import win32service # pylint: disable=E0401
    import win32serviceutil # pylint: disable=E0401
    import win32event # pylint: disable=E0401
import getopt
from vedis import Vedis # pylint: disable=E0611
from collections import namedtuple

WatchPath = namedtuple('WatchPath', ['regexes', 'ignore_regexes', 'ignore_directories', 'case_sensitive', 'path', 'recursive'])

class WatchConfig():
    def __init__(self, jdict):
        self.vedisdb = os.path.expanduser(jdict['vedisdb'])
        self.logfile = os.path.expanduser(jdict['logfile']) if jdict['logfile'] else None
        wps = jdict['watch_paths']
        for wp in wps:
            wp['path'] = os.path.expanduser(wp['path'])
        self.watch_paths = [WatchPath(**p) for p in wps]
        self.pidfile = os.path.expanduser(jdict['pidfile']) if jdict['pidfile'] else None

    def get_unexists_paths(self):
        return [p for p in self.watch_paths if not os.path.exists(p.path)]

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
    def __init__(self,db, regexes=[r".*"], ignore_regexes=[],
                 ignore_directories=False, case_sensitive=False):
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
            i = self.db.incr(src_path)
            n_size_time = self.stat_tostring(src_path)
            if size_mtime == n_size_time:
                logging.info("Modified size_time not changed. %s: %s", what, src_path)
            else:
                logging.info("Modified Truely %s: %s", what, src_path)
                self.db.sadd('true-modified', src_path)
                self.db.commit()

# http://www.chrisumbel.com/article/windows_services_in_python

class DirWatchDog():

    def __init__(self, wc):
        self.wc = wc
        self.db = Vedis(wc.vedisdb)
        self.save_me = True

    def watch(self):
        observers = []
        for ps in self.wc.watch_paths:
            event_handler = LoggingSelectiveEventHandler(
                self.db,
                regexes=ps.regexes,
                ignore_regexes=ps.ignore_regexes,
                ignore_directories=ps.ignore_directories,
                case_sensitive=ps.case_sensitive)
            observer = Observer()
            observer.schedule(event_handler, ps.path, recursive=ps.recursive)
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

if not islinux:
    class WatchDogSvc(win32serviceutil.ServiceFramework):
            # you can NET START/STOP the service by the following name
        _svc_name_ = "WatchDogSvc"
        # this text shows up as the service name in the Service
        # Control Manager (SCM)
        _svc_display_name_ = "Python watchdog Service"
        # this text shows up as the description in the SCM
        _svc_description_ = "This service watch file changes, and save the result the vedis db."

        def __init__(self, args):
            win32serviceutil.ServiceFramework.__init__(self, args)
            # create an event to listen for stop requests on
            # self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)

        # core logic of the service
        def SvcDoRun(self):
            pass
            # DirWatchDog.watch()
            # import servicemanager
            # rc = None
            # if the stop event hasn't been fired keep looping
            # while rc != win32event.WAIT_OBJECT_0:
                # block for 5 seconds and listen for a stop event
                # rc = win32event.WaitForSingleObject(self.hWaitStop, 5000)
            # Gns.stop = True

        # called when we're being shut down
        def SvcStop(self):
            # tell the SCM we're shutting down
            self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
            # fire the stop event
            DirWatchDog.save_me = False
            # win32event.SetEvent(self.hWaitStop)


def usage(msg):
    if msg:
        print msg
    else:
        print "usage: dir_watcher.py --config /path-which-exists"


if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "", [
                                   "help", "action=", "config=", "asservice"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    asservice = None
    action = None
    vedisdb = None
    config = None
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

    if not os.path.exists(config):
        usage("config file %s doesn't exists." % config)
        sys.exit(0)
    with io.open(config, 'rb') as openedfile:
        content = openedfile.read()
    j = json.loads(content)
    wc = WatchConfig(j)
    unexist_watch_paths = wc.get_unexists_paths()

    if len(unexist_watch_paths) > 0:
        usage("these watch_paths %s doesn't exists." % unexist_watch_paths)
        sys.exit(0)
    
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')
    wd = DirWatchDog(wc)
    if asservice:
        if islinux:
            print "start daemonize pidfile is %s" % wc.pidfile
            with daemon.DaemonContext(pidfile='/home/osboxes/wd.pid'):
                print "start daemonize logfile is %s" % wc.logfile
                logging.basicConfig(level=logging.INFO,
                                    filename=wc.logfile,
                                    format='%(asctime)s - %(message)s',
                                    datefmt='%Y-%m-%d %H:%M:%S')
                print "starting....."
                wd.watch()
        else:
            win32serviceutil.HandleCommandLine(WatchDogSvc, argv=["install"])
    else:
        print 'starting inactive.'
        wd.watch()
