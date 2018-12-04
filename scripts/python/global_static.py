import os


class PyGlobal:
    configuration = None
    gc_file = os.path.realpath(__file__)
    python_dir = os.path.dirname(gc_file)
    script_dir = os.path.dirname(python_dir)
    project_dir = os.path.dirname(script_dir)
    common_dir = os.path.join(script_dir, "common")
