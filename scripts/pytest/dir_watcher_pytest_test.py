# import unittest
import common_util
from global_static import PyGlobal
import tempfile, os, json, io, shutil, subprocess
import dir_watcher
from pathlib import Path
from typing import List, Dict
from typing_extensions import Final
import threading, time

from dir_watch_objects import get_watch_config, WatchConfig, WatchPath, DirWatchDog, load_watch_config
import threading
import pytest

def func(x):
    return x + 1

def test_answer():
    assert func(3) == 5

CONTENT: Final = "content"

def test_create_file(tmp_path):
    d = tmp_path / "sub"
    d.mkdir()
    p = d / "hello.txt"
    p.write_text(CONTENT)
    assert p.read_text() == CONTENT
    assert len(list(tmp_path.iterdir())) == 1
    assert 0

def test_create_file_1(tmpdir):
    p = tmpdir.mkdir("sub").join("hello.txt")
    p.write("content")
    assert p.read() == "content"
    assert len(tmpdir.listdir()) == 1
    assert 0


def test_configfile():
    config_file = os.path.join(__file__, '..', 'dir_watcher_t.json')
    wc = get_watch_config(config_file)
    wp0: WatchPath  = wc.watch_paths[0]
    assert wp0.regexes[0] == '.*'

    ign: List[str] = wc.watch_paths[0].ignore_regexes
    assert ign[0] == r'.*\.txt'
    assert ign[1] == r'c:\\Users\admin'

    assert not (wc.watch_paths[0].regexes is None)

    with pytest.raises(AttributeError):
        _ = wc.watch_paths[0].regexes1

def test_watcher(tmpdir):
    import math
    config_file = os.path.join(__file__, '..', 'dir_watcher_t.json')
    dt: Dict = load_watch_config(config_file)
    wc = get_watch_config(dt)
    wc.watch_paths[0].regexes = []
    wc.watch_paths[0].path = str(tmpdir)
    wd = DirWatchDog(wc)
    def to_run(number):
        wd.watch()
        # for i in range(number):
        #     print(math.pow(i, 3))
    t = threading.Thread(target=to_run, args=(10000,))
    t.start()
    # time.sleep(1)
    assert t.is_alive()
    p: Path = tmpdir.joinpath('abc.txt')
    p.write_text('Hello.')
    time.sleep(5)
    wd.save_me = False
