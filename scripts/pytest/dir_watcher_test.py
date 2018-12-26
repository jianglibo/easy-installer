import unittest
import common_util
from global_static import PyGlobal
import tempfile, os, json, io, shutil, subprocess
import dir_watcher
from pathlib import Path
from typing import List, Dict
import threading, time

from dir_watch_objects import get_watch_config, WatchConfig, WatchPath, DirWatchDog, load_watch_config
import threading

class Test_TestDirWatcher(unittest.TestCase):
    def setUp(self):
        self.dd: Path = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(str(self.dd))
    
    def test_configfile(self):
        config_file = os.path.join(__file__, '..', 'dir_watcher_t.json')
        wc = get_watch_config(config_file)
        
        wp0: WatchPath  = wc.watch_paths[0]
        self.assertEqual(wp0.regexes[0], '.*')
        ign: List[str] = wc.watch_paths[0].ignore_regexes
        self.assertEqual(ign[0], r'.*\.txt')
        self.assertEqual(ign[1], r'c:\\Users\admin')

        self.assertIsNotNone(wc.watch_paths[0].regexes)
        with self.assertRaises(AttributeError):
            self.assertIsNone(wc.watch_paths[0].regexes1)

    def test_watcher(self):
        import math
        config_file = os.path.join(__file__, '..', 'dir_watcher_t.json')
        dt: Dict = load_watch_config(config_file)
        wc = get_watch_config(dt)
        wc.watch_paths[0].regexes = []
        wc.watch_paths[0].path = str(self.dd)
        wd = DirWatchDog(wc)
        def to_run(number):
            wd.watch()
            # for i in range(number):
            #     print(math.pow(i, 3))
        t = threading.Thread(target=to_run, args=(10000,))
        t.start()
        # time.sleep(1)
        self.assertTrue(t.is_alive())
        p: Path = self.dd.joinpath('abc.txt')
        p.write_text('Hello.')
        time.sleep(5)
        wd.save_me = False


if __name__ == '__main__':
    unittest.main()
