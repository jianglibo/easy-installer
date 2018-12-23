import os, io, json, sys
import time
import logging
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler
islinux = 'nux' in sys.platform
if islinux:
    pass
else:
    import win32service
    import win32serviceutil
    import win32event
import getopt
from vedis import Vedis # pylint: disable=E0611
from collections import namedtuple

WatchPath = namedtuple('WatchPath', ['regexes', 'ignore_regexes', 'ignore_directories', 'case_sensitive', 'path'])

class WatchConfig():
    def __init__(self, jdict):
        self.vedisdb = jdict['vedisdb']
        self.watch_paths = [WatchPath(**p) for p in jdict['watch_paths']]



# class Gns():
#     path = None
#     excludes = []
#     stop = False
#     logfile = None
#     regexes = [r".*"]
#     ignore_regexes = [r".*\.txt", r"c:\\Users\\admin\\AppData\\Roaming\\.*",
#      r"c:\\Users\\admin\\AppData\\Local\\.*",
#      r".*vedisdb.*"]
#     ignore_directories = False
#     case_sensitive = False
#     db = None

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
    
    def stat_tostring(self, a_path):
        try:
            stat = os.stat(a_path)
            return "%s,%s" % (stat.st_size, stat.st_mtime)
        except:
            return None

    def on_moved(self, event):
        super(LoggingSelectiveEventHandler, self).on_moved(event)
        what = 'directory' if event.is_directory else 'file'
        logging.info("Moved %s: from %s to %s", what, event.src_path,
                     event.dest_path)
        self.db.sadd('moved', "%s|%s" % (event.src_path, event.dest_path))
        self.db.commit()

    def on_created(self, event):
        super(LoggingSelectiveEventHandler, self).on_created(event)
        what = 'directory' if event.is_directory else 'file'
        logging.info("Created %s: %s", what, event.src_path)
        self.db.sadd('created', event.src_path)
        self.db.commit()

    def on_deleted(self, event):
        super(LoggingSelectiveEventHandler, self).on_deleted(event)
        self.db.sadd('deleted', event.src_path)
        self.db.commit()
        what = 'directory' if event.is_directory else 'file'
        logging.info("Deleted %s: %s", what, event.src_path)

    def on_modified(self, event):
        super(LoggingSelectiveEventHandler, self).on_modified(event)
        print os.stat(event.src_path)
        what = 'directory' if event.is_directory else 'file'
        logging.info("Modified %s: %s", what, event.src_path)

        size_mtime = self.db.hget("modified", event.src_path)
        if size_mtime is None:
            size_mtime = self.stat_tostring(event.src_path)
            if size_mtime is None:
                logging.error("stat error %s: %s", what, event.src_path)
            else:
                self.db.hset("modified", event.src_path, size_mtime)
        else:
            i = self.db.incr(event.src_path)
            n_size_time = self.stat_tostring(event.src_path)
            if size_mtime == n_size_time:
                pass
            else:
                self.db.sadd('true-modified', event.src_path)
                self.db.commit()

# http://www.chrisumbel.com/article/windows_services_in_python

class DirWatchDog():
    # db = None
    # case_sensitive = None
    # watch_paths = None
    # ignore_directories = True
    # regexes = [r".*"]
    # ignore_regexes = [r".*\.txt", r"c:\\Users\\admin\\AppData\\Roaming\\.*",
    #     r"c:\\Users\\admin\\AppData\\Local\\.*",
    #     r".*vedisdb.*"]
    
    # save_me = True
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S')

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
            observer.schedule(event_handler, ps.path, recursive=True)
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
                                   "help", "action=", "config=", "serviceaction="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    serviceaction = None
    action = None
    vedisdb = None
    config = None
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage(None)
            sys.exit()
        elif o == '--serviceaction':
            serviceaction = a
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
    watch_paths = j.get('watch_paths')

    if len([p for p in watch_paths if os.path.exists(p['path'])]) == 0:
        usage("watch_paths %s doesn't exists." % watch_paths)
        sys.exit(0)
    try:
        wd = DirWatchDog(WatchConfig(j))
        if serviceaction:
            if islinux:
                pass
            else:
                win32serviceutil.HandleCommandLine(WatchDogSvc, argv=["install"])
        else:
            print 'starting inactive.'
            wd.watch()
    except Exception as e:
        print type(e)
        print e
        print e.message
    finally:
        pass