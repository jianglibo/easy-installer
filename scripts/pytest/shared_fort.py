import os

shared_fort_file = os.path.realpath(__file__)

def get_demo_config_file():
    d = os.path.dirname(shared_fort_file)
    d = os.path.dirname(d)
    d = os.path.join(d, 'borg', 'demo-config.python.1.json')
    return d