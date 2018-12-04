import unittest
import common_util
from global_static import PyGlobal
import shared_fort


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



if __name__ == '__main__':
    unittest.main()