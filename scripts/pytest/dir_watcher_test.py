import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os, json, io
import shutil
import subprocess
import dir_watcher

class Test_TestDirWatcher(unittest.TestCase):
    def setUp(self):
        self.dd = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dd)

    def test_configfile(self):
        cfgfile = os.path.join(__file__, '..', 'dir_watcher_t.json')
        with io.open(cfgfile, 'rb') as openedfile:
            content = openedfile.read()
        j = json.loads(content)
        t = type(j)
        self.assertEqual(t, dict)
        self.assertEqual(j['watch_paths'][0]['regexes'][0], '.*')
        ign = j['watch_paths'][0]['ignore_regexes']
        self.assertEqual(ign[0], r'.*\.txt')
        self.assertEqual(ign[1], r'c:\\Users\admin')

        self.assertIsNotNone(j['watch_paths'][0].get('regexes'))
        self.assertIsNone(j['watch_paths'][0].get('regexes1'))

        wc = dir_watcher.WatchConfig(j)

        self.assertEqual(wc.watch_paths[0].regexes[0], '.*')

if __name__ == '__main__':
    unittest.main()
