import unittest
import common_util
from global_static import PyGlobal, BorgConfiguration
import shared_fort
import os, io
import hashlib
import subprocess
from functools import partial
import tempfile
import xml.etree.ElementTree as ET

def two_add(a, b, c=6):
    return a + int(b) + c

class Test_TestIncrementDecrement(unittest.TestCase):
    def test_split_url(self):
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
        ha = common_util.get_one_filehash(f_path, "SHA256")
        self.assertEqual(ha['Hash'], '87AF4543F9A0C5873CDDB280BBA6C6A0E3080888FEDB31D3468BDACCFA9F284B')

    def test_config_wrapper(self):
        cf = shared_fort.get_demo_config_file()
        j = common_util.get_configration(cf)
        wp = BorgConfiguration(j)
        self.assertEqual(wp.borg_repo_path(None), "/opt/repo")
    
    def test_subprocess_call(self):
        try:
            subprocess.check_output('exit 1')
        except WindowsError as we:
            print(we)

    def test_partial(self):
        v = partial(two_add, 1)('2')
        self.assertEqual(v, 9)
        v = partial(two_add, 1, c=1)('2')
        self.assertEqual(v, 4)
        v = partial(two_add, 1)('2', 1)
        self.assertEqual(v, 4)

    def test_filehashes(self):
        print(common_util.get_dir_filehashes(PyGlobal.python_dir))

    def test_diskfree(self):
        dfs = common_util.get_diskfree()
        df = dfs[0]
        self.assertTrue(df['Used'])
        self.assertTrue(df['Free'])
        self.assertTrue(df['Usedm'])
    
    def test_memoryfree(self):
        mf = common_util.get_memoryfree()
        print(mf)

    def test_xml(self):
        f = os.path.join(__file__, '..', '..', 'mysql', 'fixtures', 'abc.xml')
        s = common_util.get_filecontent_str(f)
        rows = [(x[0].text, x[1].text) for x in ET.fromstring(s)]
        print(rows)
        self.assertTrue(len(rows) > 0)
        


        

if __name__ == '__main__':
    unittest.main()