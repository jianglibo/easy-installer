import unittest
import mysql_server_side
import os
import re

class Test_TestMysqlServerSide(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass
    
    def test_enable_repo(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "mysql-community.repo")
        lines = mysql_server_side._enable_repoversion(p, '56')
        r = mysql_server_side.get_enabled_version(lines)
        print r
        self.assertEquals(len(r), 1)
        self.assertEqual(r[0], '56')

        lines = mysql_server_side._enable_repoversion(p, '57')
        r = mysql_server_side.get_enabled_version(lines)
        print r
        self.assertEquals(len(r), 1)
        self.assertEqual(r[0], '57')
    
    def test_enable_repo_true(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "mysql-community.repo")
        mysql_server_side.enable_repoversion(p, '57')



if __name__ == '__main__':
    unittest.main()
