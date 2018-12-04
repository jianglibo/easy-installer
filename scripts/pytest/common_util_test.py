import unittest
import common_util
from global_static import PyGlobal
import shared_fort
import os
import hashlib

class Test_TestIncrementDecrement(unittest.TestCase):
    def test_increment(self):
        self.assertEqual(common_util.split_url("http://abc/cc", True), 'http://abc/')
        self.assertEqual(common_util.split_url("http://abc/cc", False), 'cc')

    def test_static(self):
        PyGlobal.configuration = 10
        self.assertEqual(PyGlobal.configuration, 10)

    def test_load_configfile(self):
        cf = shared_fort.get_demo_config_file()
        j = common_util.get_configration(cf)
        self.assertEqual(j['UserName'], 'root')
        softwares = j['SwitchByOs'][j['OsType']]['Softwares']
        self.assertTrue(type(softwares) is list)
    
    def test_os_walk(self):
        for root, dirs, files in os.walk(PyGlobal.python_dir, topdown=False):
            for name in files:
                print(os.path.join(root, name))
            for name in dirs:
                print(os.path.join(root, name))
            self.assertTrue(type(files[0]) is str)
            self.assertEqual(len(files), 4)
            self.assertEqual(len(dirs), 0)
            pys = filter(lambda f: f.endswith('.py'), files)
            self.assertEqual(len(pys), 2)
    
    def test_file_hash(self):
        f_path = os.path.join(PyGlobal.project_dir, 'ttrap.ps1')
        ha = common_util.get_filehash(f_path, "SHA256")
        self.assertEqual(ha.upper(), '87AF4543F9A0C5873CDDB280BBA6C6A0E3080888FEDB31D3468BDACCFA9F284B')


if __name__ == '__main__':
    unittest.main()