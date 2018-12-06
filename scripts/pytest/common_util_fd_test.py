import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os
import shutil

class Test_TestIncrementDecrement(unittest.TestCase):
    def setUp(self):
        self.dd = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dd)

    def test_increment(self):
        self.assertFalse(os.path.exists('a'))


if __name__ == '__main__':
    unittest.main()
