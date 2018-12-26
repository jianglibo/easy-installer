import unittest
import common_util
from global_static import PyGlobal
import tempfile
import os
import shutil, functools
import subprocess

class Test_TestLang(unittest.TestCase):
    def setUp(self):
        self.dd = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dd)

    def test_varargs(self):
        def f(*args):
            return args
        r = f(1,2,3)
        self.assertEqual(type(r), tuple)
        self.assertEqual(functools.reduce(lambda x,y: x+y, r), 6)
    
    def test_call(self):
        v = None
        try:
            v = subprocess.check_output(['ls', '/404'], stderr=subprocess.STDOUT, shell=True)
            self.assertTrue(v)
        except subprocess.CalledProcessError as cpe:
            self.assertTrue(cpe.output)
            self.assertEqual(cpe.returncode, 1)
            # self.assertEqual(cpe.message, '')

        try:
            v = subprocess.check_output(['ls', '/404'], shell=True)
            self.assertTrue(v)
        except subprocess.CalledProcessError as cpe:
            self.assertTrue(not cpe.output) # doesn't redirect output.
            self.assertEqual(cpe.returncode, 1)
            # self.assertEqual(cpe.message, '')
    
    def test_checkout_stderr(self):
        v = common_util.subprocess_checkout_print_error(['ls', '/404'], shell=True)
        self.assertFalse(v)

if __name__ == '__main__':
    unittest.main()
