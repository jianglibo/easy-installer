import os, json, sys, re
import time
from pathlib import Path
import logging
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler, FileSystemEventHandler, FileSystemEvent
from typing import NamedTuple, List, Optional, Dict, Any, Iterator, Pattern, Match, Union, ClassVar
import getopt
from vedis import Vedis # pylint: disable=E0611
from collections import namedtuple
from typing_extensions import Final
from enum import Enum

class ErrorNames(Enum):
    config_file_not_exists = 1
    un_exist_watch_paths = 2

class WatchPath(NamedTuple):
    regexes: List[str]
    ignore_regexes: List[str]
    ignore_directories: bool
    case_sensitive: bool
    path: Path
    recursive: bool

class WatchConfig():
    def __init__(self, jdict: Dict) -> None:
        self.vedisdb: Path = Path(jdict['vedisdb']).expanduser()
        self.logfile: Optional[Path] = Path(jdict['logfile']).expanduser() if jdict['logfile'] else None
        wps: List[Dict[str, Any]] = jdict['watch_paths']
        for wp in wps:
            wp['path'] = Path(wp['path']).expanduser()
        self.watch_paths: List[WatchPath] = [WatchPath(**p) for p in wps]
        self.pidfile = Path(jdict['pidfile']).expanduser() if jdict['pidfile'] else None

    def get_un_exists_paths(self) -> List[WatchPath]:
        return [wp for wp in self.watch_paths if not wp.path.exists()]


class DirWatchDog():
    MODIFIED_HASH_TABLE: ClassVar[str] = "modified"
    MODIFIED_REALLY_SET_TABLE: ClassVar[str] = "modified-really"
    MOVED_SET_TABLE: ClassVar[str] = "moved"
    DELETED_SET_TABLE: ClassVar[str] = "deleted"
    CREATED_SET_TABLE: ClassVar[str] = "created"

    def __init__(self, wc: WatchConfig) -> None:
        self.wc = wc
        self.db = Vedis(wc.vedisdb)
        self.save_me = True
        self.observers : List[Observer] = []

    def get_modified_number(self):
        return self.db.scard(DirWatchDog.MODIFIED_REALLY_SET_TABLE)

    def get_created_number(self):
        return self.db.scard(DirWatchDog.CREATED_SET_TABLE)

    def get_deleted_number(self):
        return self.db.scard(DirWatchDog.DELETED_SET_TABLE)
    
    def get_moved_number(self):
        return self.db.scard(DirWatchDog.MOVED_SET_TABLE)
    
    def wait_seconds(self, seconds: int) -> None:
        for obs in self.observers:
            obs.join(seconds)

    def watch(self) -> None:
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
            self.observers.append(observer)
        try:
            while self.save_me:
                time.sleep(1)
            else:
                for obs in self.observers:
                    obs.stop()
                self.db.close()
        except KeyboardInterrupt:
            for obs in self.observers:
                obs.stop()
            self.db.close()


class LoggingSelectiveEventHandler(FileSystemEventHandler):
    """
    Logs all the events captured.
    """

    def __init__(self,db: Vedis, regexes: List[str]=[r".*"], ignore_regexes: List[str]=[],
                 ignore_directories: bool =False, case_sensitive: bool=False):
        super(LoggingSelectiveEventHandler, self).__init__()
        self._regexes: List[Pattern]
        self._ignore_regexes: List[Pattern]

        if case_sensitive:
            self._regexes = [re.compile(r) for r in regexes]
            self._ignore_regexes = [re.compile(r) for r in ignore_regexes]
        else:
            self._regexes = [re.compile(r, re.I) for r in regexes]
            self._ignore_regexes = [re.compile(r, re.I) for r in ignore_regexes]
        self._ignore_directories = ignore_directories
        self._case_sensitive = case_sensitive
        self.db = db
        self._has_regexes = len(self._regexes) > 0
        logging.debug("create regexes: %s, ignore_regexes: %s", regexes, ignore_regexes)


    def dispatch(self, event: FileSystemEvent):
        """Dispatches events to the appropriate methods.

        :param event:
            The event object representing the file system event.
        :type event:
            :class:`FileSystemEvent`
        """
        src_path: str = event.src_path
        if event.is_directory and self._ignore_directories:
            logging.debug("directory %s ignored.", src_path)
            return
        for r in self._ignore_regexes:
            if r.match(src_path):
                logging.debug("%s hit ignore_regexes %s, skipping...", src_path, r.pattern)
                return
        if self._has_regexes and (not any([r.match(src_path) for r in self._regexes])):
            logging.debug("%s not in regexes, skipping...", src_path)
            return
        super().dispatch(event)
    
    def stat_tostring(self, a_path):
        try:
            stat = os.stat(a_path)
            return "%s,%s" % (stat.st_size, stat.st_mtime)
        except:
            return None

    def on_moved(self, event):
        what = 'directory' if event.is_directory else 'file'
        logging.debug("Moved %s: from %s to %s", what, event.src_path,
                     event.dest_path)
        self.db.sadd(DirWatchDog.MOVED_SET_TABLE, "%s|%s" % (event.src_path, event.dest_path))
        self.db.commit()

    def on_created(self, event):
        what = 'directory' if event.is_directory else 'file'
        logging.debug("Created %s: %s", what, event.src_path)
        self.db.sadd(DirWatchDog.CREATED_SET_TABLE, event.src_path)
        self.db.commit()

    def on_deleted(self, event):
        self.db.sadd(DirWatchDog.DELETED_SET_TABLE, event.src_path)
        self.db.commit()
        what = 'directory' if event.is_directory else 'file'
        logging.debug("Deleted %s: %s", what, event.src_path)

    def on_modified(self, event):
        src_path = event.src_path
        what = 'directory' if event.is_directory else 'file'
        size_mtime = self.db.hget(DirWatchDog.MODIFIED_HASH_TABLE, src_path)
        if size_mtime is None:
            size_mtime = self.stat_tostring(src_path)
            if size_mtime is None:
                logging.error("stat error %s: %s", what, src_path)
            else:
                self.db.hset(DirWatchDog.MODIFIED_HASH_TABLE, src_path, size_mtime)
            logging.debug("Modified Not in db %s: %s", what, src_path)
        else:
            self.db.incr(src_path)
            n_size_time = self.stat_tostring(src_path)
            if size_mtime == n_size_time:
                logging.debug("Modified size_time not changed. %s: %s", what, src_path)
            else:
                logging.debug("Modified really %s: %s", what, src_path)
                self.db.sadd(DirWatchDog.MODIFIED_REALLY_SET_TABLE, src_path)
                self.db.commit()

def load_watch_config(pathname: Union[None, str, Path]) -> Dict[str, Any]:
    cp: Path
    islinux: bool = 'nux' in sys.platform

    if islinux:
        cf = "dir_watcher_nux.json"
    else:
        cf = "dir_watcher.json"

    if not pathname:
        if getattr(sys, 'frozen', False):
            # frozen
            f_ = Path(sys.executable)
        else:
            # unfrozen
            f_ = Path(__file__)
        cp = f_.parent.parent / cf
        if not cp.exists():
            cp = f_.parent / cf
    elif isinstance(pathname, Path):
        cp = pathname
    else:
        cp = Path(pathname)

    if not cp.exists():
        raise ValueError("config file %s doesn't exists." % pathname, ErrorNames.config_file_not_exists)
    print("with config file %s" % str(cp.absolute().resolve()))

    with cp.open() as f:
        content = f.read()
    j: Dict[str, Any] = json.loads(content)
    return j

def get_watch_config(pathname: Union[Optional[str], Optional[Path], Dict]) -> WatchConfig:
    if (pathname is None) or (isinstance(pathname, str)) or (isinstance(pathname, Path)):
        wc = WatchConfig(load_watch_config(pathname))
    else:
        wc = WatchConfig(pathname)

    un_exist_watch_paths = wc.get_un_exists_paths()
    if len(un_exist_watch_paths) > 0:
        raise ValueError("these watch_paths %s doesn't exists." % un_exist_watch_paths, ErrorNames.un_exist_watch_paths)
    return wc
