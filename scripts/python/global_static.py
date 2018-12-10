import os

class PyGlobal:
    configuration = None
    config_file = None
    mysql_extrafile= None
    line_start = "for-easyinstaller-client-use-start"
    line_end = "for-easyinstaller-client-use-end"
    gc_file = os.path.realpath(__file__)
    python_dir = os.path.dirname(gc_file)
    script_dir = os.path.dirname(python_dir)
    project_dir = os.path.dirname(script_dir)
    common_dir = os.path.join(script_dir, "common")
    empty_password = "USE-EMPTY-PASSWORD"

class MysqlVariableNames:
    data_dir = "datadir"

class Configuration:
    'A Wrapper for json configuration'
    def __init__(self, json):
        self.json = json

    def get_os_config(self):
        my_os = self.json["OsType"]
        return self.json['SwitchByOs'][my_os]

    def get_server_side(self):
        return self.get_os_config()["ServerSide"]

    def get_packagedir(self):
        return self.get_server_side()["PackageDir"]
    
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
    

