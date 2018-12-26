import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os, json, io
import shutil
import subprocess
import dir_watcher
from pathlib import Path
from typing import List
import threading
import time

from dir_watch_objects import get_watch_config, WatchConfig, WatchPath, DirWatchDog
import threading

class Test_TestDirWatcher(unittest.TestCase):
    def setUp(self):
        self.dd: Path = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(str(self.dd))
    
    def get_wc(self):
        config_file = os.path.join(__file__, '..', 'dir_watcher_t.json')
        return get_watch_config(config_file)


    def test_configfile(self):
        wc = self.get_wc()
        
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
        wc = self.get_wc()
        wd = DirWatchDog(wc)
        def to_run(number):
            wd.watch()
            # for i in range(number):
            #     print(math.pow(i, 3))
        t = threading.Thread(target=to_run, args=(10000,))
        t.start()
        # time.sleep(1)
        self.assertTrue(t.is_alive())
        t.join(timeout=1)
        time.sleep(5)
        wd.save_me = False


if __name__ == '__main__':
    unittest.main()
