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
