import common_util
from global_static import PyGlobal
import tempfile, os, json, io, shutil, subprocess
import dir_watcher
from pathlib import Path
from typing import List, Dict, NamedTuple, Tuple
from typing_extensions import Final
import threading, time
from py._path.local import LocalPath

from dir_watch_objects import get_watch_config, WatchConfig, WatchPath, DirWatchDog, load_watch_config
import threading
import pytest
from vedis import Vedis # pylint: disable=E0611

def get_configfile():
    return Path(__file__, '..', '..', 'pytest', 'dir_watcher_t.json')

CONTENT: Final = "content"

@pytest.fixture(params=[[".*\\.abc"]])
def tp(request, tmpdir):
    import math
    dt: Dict = load_watch_config(get_configfile())
    wc = get_watch_config(dt)
    wp: WatchPath = common_util.clone_namedtuple(wc.watch_paths[0], path=str(tmpdir), ignore_regexes=request.param) # type: ignore
    wc.watch_paths[0] = wp
    wd = DirWatchDog(wc)
    yield (tmpdir, wd)  # provide the fixture value
    print("teardown watchdog")
    wd.save_me = False

class TestDirWatcher(object):

    def test_create_file(self, tmp_path):
        d = tmp_path / "sub"
        d.mkdir()
        p = d / "hello.txt"
        p.write_text(CONTENT)
        assert p.read_text() == CONTENT
        assert len(list(tmp_path.iterdir())) == 1

        
    def test_create_file_1(self, tmpdir):
        p = tmpdir.mkdir("sub").join("hello.txt")
        p.write("content")
        assert p.read() == "content"
        assert len(tmpdir.listdir()) == 1

    def test_configfile(self):
        wc = get_watch_config(get_configfile())
        wp0: WatchPath  = wc.watch_paths[0]
        assert wp0.regexes[0] == '.*'

        ign: List[str] = wc.watch_paths[0].ignore_regexes
        assert ign[0] == r'.*\.txt'
        assert ign[1] == r'c:\\Users\admin'

        assert not (wc.watch_paths[0].regexes is None)

        with pytest.raises(AttributeError):
                _ = wc.watch_paths[0].regexes1

    def test_watcher(self, tp: Tuple[LocalPath, DirWatchDog]):
        tmpdir = tp[0]
        wd = tp[1]
        def to_run(number):
                wd.watch()

        t = threading.Thread(target=to_run, args=(10000,))
        t.start()
        assert t.is_alive()
        
        p: LocalPath = tmpdir.join('abc.txt')
        p.write_text('Hello.', encoding="utf-8")

        time.sleep(2)

        assert wd.get_created_number() == 1
        assert wd.get_deleted_number() == 0
        assert wd.get_modified_number() == 0
