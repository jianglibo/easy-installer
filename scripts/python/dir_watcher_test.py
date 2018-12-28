import common_util
from global_static import PyGlobal
import tempfile, os, json, io, shutil, subprocess, re
import dir_watcher
from pathlib import Path
from typing import List, Dict, NamedTuple, Tuple
from typing_extensions import Final
import threading, time, logging
from py._path.local import LocalPath

from dir_watch_objects import get_watch_config, WatchConfig, WatchPath, DirWatchDog, load_watch_config
import threading
import pytest
from vedis import Vedis # pylint: disable=E0611

from _pytest.logging import LogCaptureFixture

def get_configfile() -> Path:
    return Path(__file__, '..', '..', 'pytest', 'dir_watcher_t.json')

CONTENT: Final = "content"

@pytest.fixture(params=[{"tid": 0, "ignore_regexes": [".*\\.abc"]},
    {"tid": 1, "ignore_regexes": [".*\\.txt"]},
    {"tid": 2, "ignore_regexes": [r"\w:\\.*"]}])
def tp(request, tmpdir: LocalPath):
    import math
    print(tmpdir.strpath)
    dt: Dict = load_watch_config(get_configfile())
    wc = get_watch_config(dt)
    ignore_regexes = request.param["ignore_regexes"]
    tid = request.param["tid"]
    wp: WatchPath = common_util.clone_namedtuple(wc.watch_paths[0], path=str(tmpdir), ignore_regexes=ignore_regexes) # type: ignore
    wc.watch_paths[0] = wp
    wd = DirWatchDog(wc)
    yield (tmpdir, wd, tid)  # provide the fixture value
    print("teardown watchdog")
    # tmpdir.remove()
    wd.save_me = False
    wd.wait_seconds(10)

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
        wc: WatchConfig = get_watch_config(get_configfile())
        wp0: WatchPath  = wc.watch_paths[0]
        assert wp0.regexes[0] == '.*'

        ign: List[str] = wc.watch_paths[0].ignore_regexes
        assert ign[0] == r'.*\.txt'
        assert ign[1] == r'c:\\Users\admin'

        assert not (wc.watch_paths[0].regexes is None)

        with pytest.raises(AttributeError):
                _ = wc.watch_paths[0].regexes1

    def test_watcher(self, tp: Tuple[LocalPath, DirWatchDog, int], caplog: LogCaptureFixture):
        tmpdir = tp[0]
        wd = tp[1]
        tid = tp[2]
        caplog.set_level(logging.DEBUG)

        assert re.match(r"\w:\\.*", tmpdir.strpath)
        def to_run(number):
                wd.watch()

        t = threading.Thread(target=to_run, args=(10000,))
        t.start()
        assert t.is_alive()
        time.sleep(2)
        if tid == 0:
            p: LocalPath = tmpdir.join('abc.txt')
            p.write_text('Hello.', encoding="utf-8")
            time.sleep(1)
            p.write_text('1Hello.', encoding="utf-8")
            time.sleep(1)
            p.write_text('1Hello.', encoding="utf-8")
            time.sleep(1)
            target_file = tmpdir.join('abc1.txt')
            p.move(target_file)
            time.sleep(1)
            target_file.remove()
            time.sleep(1)
            assert wd.get_created_number() == 1
            assert wd.get_deleted_number() == 1
            assert wd.get_modified_number() == 1
            assert wd.get_moved_number() == 1

            for r in caplog.records:
                print(r)
        elif tid == 1:
            p = tmpdir.join('abc.txt')
            p.write_text('Hello.', encoding="utf-8")

            time.sleep(2)

            assert wd.get_created_number() == 0
            assert wd.get_deleted_number() == 0
            assert wd.get_modified_number() == 0
        elif tid == 2:
            p = tmpdir.join('abc.txt')
            p.write_text('Hello.', encoding="utf-8")

            time.sleep(2)

            assert wd.get_created_number() == 0
            assert wd.get_deleted_number() == 0
            assert wd.get_modified_number() == 0
            
