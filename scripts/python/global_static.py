import os

class PyGlobal:
    configuration = None
    config_file = None
    line_start = "for-easyinstaller-client-use-start"
    line_end = "for-easyinstaller-client-use-end"
    gc_file = os.path.realpath(__file__)
    python_dir = os.path.dirname(gc_file)
    script_dir = os.path.dirname(python_dir)
    project_dir = os.path.dirname(script_dir)
    common_dir = os.path.join(script_dir, "common")

class Configuration:
    'A Wrapper for json configuration'
    def __init__(self, json):
        self.json = json
    
    def get_property(self, pn):
        return self.json[pn]
    
    def get_property_if_need(self, v, pn):
        if v:
            return v
        else:
            return self.json[pn]

class BorgConfiguration(Configuration):
    'Borg configuration'
    def __init__(self, json):
        if not(type(json) is dict):
            raise ValueError('json is not a dict.')
        self.json = json

    def borg_repo_path(self, dv):
        return self.get_property_if_need(dv, "BorgRepoPath")
