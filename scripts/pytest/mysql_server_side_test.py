import unittest
import mysql_server_side, common_util
import os, re, io, tempfile, shutil

class Test_TestMysqlServerSide(unittest.TestCase):

    def setUp(self):
        self.dd = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dd)
    
    def test_enable_repo(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "mysql-community.repo")
        lines = mysql_server_side._enable_repoversion(p, '56')
        r = mysql_server_side.get_enabled_version(lines)
        print(r)
        self.assertEquals(len(r), 1)
        self.assertEqual(r[0], '56')

        lines = mysql_server_side._enable_repoversion(p, '57')
        r = mysql_server_side.get_enabled_version(lines)
        print(r)
        self.assertEquals(len(r), 1)
        self.assertEqual(r[0], '57')
    
    def test_enable_repo_true(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "mysql-community.repo")
        tp = os.path.join(self.dd, 'mysql-community.repo')
        shutil.copy(p, tp)
        mysql_server_side.enable_repoversion(tp, '57')
    
    def test_update_mycnf(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "my.cnf")
        with io.open(p, mode='r') as opened_file:
            lines_in = [line.strip() for line in opened_file.readlines()]
            lines_out = common_util.update_block_config_file(lines_in, 'a', 'cc')
            self.assertEqual(len(lines_in), len(lines_out) - 1)

    def test_enable_login(self):
        p = os.path.join(__file__, "..", "..", "mysql", "fixtures", "my.cnf")
        tp = os.path.join(self.dd, 'my.cnf')
        shutil.copy(p, tp)
        tp1 = "%s.1" % tp
        mysql_server_side.enable_logbin(tp, 'hm-log-bin',server_id='1')
        self.assertTrue(os.path.exists(tp1))
        self.assertEqual(common_util.get_block_config_value(tp, '[mysqld]', 'log-bin'), 'hm-log-bin')

if __name__ == '__main__':
    unittest.main()
