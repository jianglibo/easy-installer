import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os
import shutil

class Test_TestCommonUtilWithDiskIO(unittest.TestCase):
    def setUp(self):
        self.dd = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dd)

    def test_maxbackupnumber(self):
        f = os.path.join(self.dd, "abc.txt")
        with open(f, 'wb') as the_file:
            the_file.write('Hello\n')
        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 0)

        f1 = os.path.join(self.dd, "abc.txt.1")
        with open(f1, 'wb') as the_file:
            the_file.write('Hello\n')
        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 1)

        f1 = os.path.join(self.dd, "abc.txt.2")
        with open(f1, 'wb') as the_file:
            the_file.write('Hello\n')
        n = common_util.get_maxbackupnumber(f)
        self.assertEqual(n, 2)
    
    def test_backupdirectory(self):
        d = os.path.join(self.dd, "d0")
        os.makedirs(d)
        d1 = common_util.backup_localdirectory(d)
        self.assertEqual(d1, d + ".1")


if __name__ == '__main__':
    unittest.main()
