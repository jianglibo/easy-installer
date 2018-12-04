# type(a)
# vars(a)
# inspect.getmembers(a, inspect.isfunction) 
# https://www.tutorialspoint.com/python/python_lists.htm

import os
import urllib2
import io
import json
from global_static import PyGlobal

def split_url(url, parent):
    parts = url.split('://', 1)
    if (len(parts) == 2):
        has_protocol = True
        [before_protocol, after_protocol] = parts
    else:
        has_protocol = False
        after_protocol = parts[0]
    
    idx = after_protocol.rfind('/')
    if (idx == -1):
        return (url, '')[parent]
    else: 
        if (parent):
            after_protocol = after_protocol[0:idx+1]
            return (after_protocol, "%s://%s" % (before_protocol, after_protocol))[has_protocol]
        else:
            return after_protocol[idx+1:]
        
def get_software_packages(target_dir, softwares):
    if (not(os.path.exists(target_dir))):
        os.makedirs(target_dir)
    for software in softwares:
        url = software['PackageUrl']
        ln = software['LocalName']
        if (not(ln)):
            ln = split_url(url, False)
        lf = os.path.join(target_dir, ln)
        if (not(os.path.exists(lf))):
            print "start downloading..."
            downloading_file = urllib2.urlopen(url)
            with open(lf,'wb') as output:
                output.write(downloading_file.read())
    

def get_configration(config_file, encoding="utf-8", server_side=False):
    if (os.path.isfile(config_file) and os.path.exists(config_file)):
        try:
            f = io.open(config_file,mode="r",encoding=encoding)
            s = f.read()
        except UnicodeDecodeError:
            f = io.open(config_file,mode="r",encoding='utf-16')
            s = f.read()
        finally:
            f.close()
        j = json.loads(s)
        os_type = j['OsType']
        os_config = j['SwitchByOs'][os_type]
        softwares = os_config['Softwares']
        if (server_side):
            dl = os_config['ServerSide']['PackageDir']
        else:
            dl = os.path.join(PyGlobal.project_dir, 'downloads', j['AppName'])
        get_software_packages(dl, softwares)
        PyGlobal.configuration = j
        return j
    else:
        raise ValueError("config file %s doesn't exists." % config_file)
