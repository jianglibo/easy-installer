import os
from typing import List, Dict, Any, NamedTuple, Optional
from pathlib import Path

class MysqlVariableNames:
    data_dir = "datadir"

Software = NamedTuple('Software', [('PackageUrl', str),('LocalName', Optional[str])])

class Configuration:
    'A Wrapper for json configuration'
    def __init__(self, json):
        self.json = json
        self.my_os = json["OsType"]
        self.by_os_config = json['SwitchByOs'][self.my_os]
        self.server_side = self.by_os_config['ServerSide']
        self.package_dir = self.server_side['PackageDir']
        self.softwares : List[Software] = [Software(s['PackageUrl'], s['LocalName']) for s in self.by_os_config['Softwares']]

    # def get_os_config(self):
    #     my_os = self.json["OsType"]
    #     return self.json['SwitchByOs'][my_os]

    # def get_server_side(self):
    #     return self.get_os_config()["ServerSide"]

    # def get_packagedir(self):
    #     return self.get_server_side()["PackageDir"]
    
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
        super().__init__(json)
        # if not(type(json) is dict):
        #     raise ValueError('json is not a dict.')
        # self.json = json

    def borg_repo_path(self, dv):
        return self.get_property_if_need(dv, "BorgRepoPath")
    

class PyGlobal:
    configuration: Configuration
    config_file = None
    mysql_extrafile= None
    verbose = False
    line_start = "for-easyinstaller-client-use-start"
    line_end = "for-easyinstaller-client-use-end"
    this_file: Path
    python_dir: Path
    script_dir: Path
    project_dir: Path
    common_dir: Path
    empty_password = "USE-EMPTY-PASSWORD"

PyGlobal.this_file = Path(__file__)
PyGlobal.python_dir = PyGlobal.this_file.parent
PyGlobal.script_dir = PyGlobal.python_dir.parent
PyGlobal.project_dir = PyGlobal.script_dir.parent
PyGlobal.common_dir = PyGlobal.script_dir.joinpath('common')