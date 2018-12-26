import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os
import shutil
from pathlib import Path

class Test_TestCommonUtilWithDiskIO(unittest.TestCase):
    def setUp(self):
        self.dd = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(str(self.dd))

    def test_maxbackupnumber(self):
        f: Path = self.dd.joinpath('abc.txt')
        with  f.open('w') as the_file:
            the_file.write('Hello\n')

        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 0)

        f1: Path = self.dd.joinpath("abc.txt.1")
        with f1.open('w') as the_file:
            the_file.write('Hello\n')
        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 1)

        f2 = self.dd.joinpath("abc.txt.2")
        with f2.open('w') as the_file:
            the_file.write('Hello\n')
        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 2)
    
    def test_backupdirectory(self):
        d: Path = self.dd.joinpath("d0")
        d.mkdir(parents=True)
        d1 = common_util.backup_localdirectory(d)
        self.assertEqual(str(d1), str(d) + ".1")

if __name__ == '__main__':
    unittest.main()
