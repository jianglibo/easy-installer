import unittest
from borg_server_side import main

class Test_TestBorgServerSide(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass
    
    def test_args(self):
        main("abc", "ccd")

if __name__ == '__main__':
    unittest.main()
