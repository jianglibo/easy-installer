#!/usr/bin/python

import sys
import getopt
import os
from global_static import PyGlobal
import common_util
import subprocess
import json
import shutil
import tempfile
import StringIO
import re
import io
import itertools

if not PyGlobal.config_file:
    PyGlobal.config_file = os.path.join(os.path.split(__file__)[0], 'config.json')
if os.path.exists(PyGlobal.config_file):
    common_util.get_configration(PyGlobal.config_file, "utf-8", True)
    j = PyGlobal.configuration.json
    client_bin = j['ClientBin']
    os_config = PyGlobal.configuration.get_os_config()
    server_side = os_config["ServerSide"]



def usage():
    print "usage message printed."

# "ho:" mean -h doesn't need a argument, but -o needs.

def main(action, args):
    if action == 'Archive':
        common_util.send_lines_to_client(common_util.get_diskfree())
    elif action == 'GetMycnf':
        common_util.send_lines_to_client(get_mycnf_file())
    elif action == 'DownloadPublicKey':
        common_util.send_lines_to_client(get_openssl_publickey())
    elif action == 'FileHashes':
        common_util.send_lines_to_client(common_util.get_filehashes(args[0]))
    elif action == 'Echo':
        common_util.send_lines_to_client(' '.join(args))

def get_openssl_publickey():
    openssl_exec = j["openssl"]
    private_key_file = j["PrivateKeyFile"]
    with tempfile.NamedTemporaryFile(delete=False) as tf:
        subprocess.call([openssl_exec, 'rsa', '-in' , private_key_file, '-pubout', '-out', tf.name])
        return tf.name

def get_enabled_version(lines):
    founded = []
    current_version = None
    for line in lines:
        line = line.strip()
        m = re.match(r'^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            if line == 'enabled=1' and current_version:
                founded.append(current_version)
                current_version = None
    return founded


def enable_repoversion(repo_file, version):
    common_util.backup_localdirectory(repo_file)
    lines = _enable_repoversion(repo_file, version)
    with io.open(repo_file, 'wb') as opened_file:
        opened_file.writelines(["%s%s" % (line, "\n") for line in lines])
    
def _enable_repoversion(repo_file, version):
    current_version = None
    with io.open(repo_file, mode='r') as opened_file:
        lines = [line.strip() for line in opened_file.readlines()]
        new_lines = []
    for line in lines:
        m = re.match(r'^\[.*?(\d+)-.*\]$', line)
        if m:
            current_version = m.group(1)
        else:
            m = re.match(r'^\[.*\]$', line)
            if m:
                current_version = 'others'
            else:
                m = re.match('^enabled=(0|1)$', line)
                if m:
                    if current_version == version:
                        line = 'enabled=1'
                    elif current_version != 'others':
                        line = 'enabled=0'
        new_lines.append(line)
    return new_lines

def new_mysqlextrafile(plain_password):
    mysql_user = j['MysqlUser']
    if mysql_user is None:
        raise ValueError('MysqlUser property in configuration file is empty.')
    if plain_password:
        plain_password = plain_password if plain_password != PyGlobal.empty_password else ''
        tf = tempfile.mktemp()
        with io.open(tf, mode='wb') as opened_file:
            opened_file.writelines(["%s%s" % (line, "\n") for line in ["client", "user=%s" % mysql_user, "password=%s" % plain_password]])
        return tf
    else:
        if PyGlobal.mysql_extrafile is None:
            plain_password = common_util.unprotect_password_by_openssl_publickey(j['MysqlPassword'])
            tf = tempfile.mktemp()
            with io.open(tf, mode='wb') as opened_file:
                opened_file.writelines(["%s%s" % (line, "\n") for line in ["client", "user=%s" % mysql_user, "password=%s" % plain_password]])
            PyGlobal.mysql_extrafile = tf
            return tf
        else:
            return PyGlobal.mysql_extrafile

def get_sql_commandline(sql, plain_password, combine_error=False):
    extra_file = new_mysqlextrafile(plain_password)
    cmd_line = [
        j['ClientBin'],
        "--defaults-extra-file=%s" % extra_file,
        "-X",
        "-e",
        '"%s"' % sql,
        "2>&1" if combine_error else ""
    ]
    return {"cmdline": cmd_line, "extrafile": extra_file}

# function Invoke-MysqlSQLCommand {
#     param (
#         [parameter(Mandatory = $true, Position = 0)]$sql,
#         [parameter(Mandatory = $false)][string]$UsePlainPwd,
#         [parameter()][switch]$SQLFromFile,
#         [parameter()][switch]$combineError
#     )

#     $cmdline = Get-SQLCommandLine -sql $sql -combineError:$combineError -UsePlainPwd $UsePlainPwd -SQLFromFile:$SQLFromFile
#     $cmdline | Write-Verbose
#     $r = Invoke-Expression -Command $cmdline.cmdline | Where-Object {-not ($_ -like 'Warning:*')}
#     if (-not ($sql -match 'show variables')) {
#         $r | Write-Verbose
#     }
#     if ($cmdline.sqltmp -and (Test-Path -Path $cmdline.sqltmp)) {
#         "deleting tmp sqlfile: $($cmdline.sqltmp)" | Write-Verbose
#         Remove-Item -Path $cmdline.sqltmp -Force
#     }
#     if ($cmdline.DeleteExtraFile -and $cmdline.extrafile -and (Test-Path -Path $cmdline.extrafile)) {
#         "deleting emptypass extrafile: $($cmdline.sqltmp)" | Write-Verbose
#     }
#     if ($r -like "*Access Denied*") {
#         throw "Mysql Access Denied."
#     }
#     elseif ($r -like "*Can't connect to*") {
#         throw "Mysql is not started."
#     }
#     $r
# }

def invoke_mysql_sql_command(sql, plain_password):
    pass

# function Get-MysqlVariables {
#     param (
#         [parameter(Mandatory = $false, Position = 0)][string[]]$VariableNames,
#         [parameter(Mandatory = $false)][string]$UsePlainPwd
#     )
#     $r = Invoke-MysqlSQLCommand -sql "show variables" -combineError
#     if ($VariableNames.Count -gt 0) {
#         ([xml]$r).resultset.row |
#             ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} |
#             Where-Object {$_.name -in $VariableNames} | ConvertTo-Json -Depth 10
#     }
#     else {
#         ([xml]$r).resultset.row |
#             ForEach-Object {@{name = $_.field[0].'#text'; value = $_.field[1].'#text'}} | ConvertTo-Json -Depth 10
#     }
# }

def get_mysql_variables(variable_names, plain_password):

    pass
#     $flushcmd = 
#     $flushcmd | Write-Verbose
#     $r = Invoke-Expression -Command $flushcmd
#     "Invoke flushcmd output:" | Write-Verbose
#     $r | Write-Verbose
#     $deny = $r | Where-Object {$_ -match 'Access denied'} | Select-Object -First 1
#     if ($deny) {
#         throw $r
#     }
#     $idxfile = Get-MysqlVariables -VariableNames 'log_bin_index' -UsePlainPwd $UsePlainPwd

#     "found idxfile: $idxfile" | Write-Verbose
#     if (-not $idxfile) {
#         throw 'cannot find log_bin_index variable.'
#     }

#     $idxfile = $idxfile | ConvertFrom-Json

#     if (-not $idxfile.value) {
#         throw "log_bin_index variable is null. Did logbin be enabled?"
#     }

#     if (-not (Test-Path -Path $idxfile.value -PathType Leaf)) {
#         throw 'cannot find log_bin_index file.'
#     }
#     $pf = Split-Path -Path $idxfile.value -Parent
#     "log folder is: $pf" | Write-Verbose

#     Get-Content -Path $idxfile.value | ForEach-Object {Join-Path -Path $pf -ChildPath $_} |
#         ForEach-Object {Get-FileHash -Path $_ | Add-Member @{Length=(Get-Item -Path $_).Length} -PassThru} |
#         ConvertTo-Json | Send-LinesToClient
# }

def invoke_mysqlflushlogs(plain_password):
    extra_file = new_mysqlextrafile(plain_password)
    flush_cmd = [
        j['MysqlAdminBin'],
        "--defaults-extra-file=%s" % extra_file,
        "flush-logs",
        "2>&1"
    ]
    subprocess.call(flush_cmd)
    idxfile = 
    pass

def invoke_mysqldump(plain_password):
    extra_file = new_mysqlextrafile(plain_password)
    dump_cmd = [j['DumpBin'],
                "--defaults-extra-file=%s" % extra_file,
                '--max_allowed_packet=512M',
                '--quick',
                '--events',
                '--all-databases',
                '--flush-logs',
                '--delete-master-logs',
                '--single-transaction',
                '>',
                j['DumpFilename']]
    subprocess.call(dump_cmd)
    return common_util.get_one_filehash(j['DumpFilename'])

def enable_logbin(mycnf_file, logbin_base_name='hm-log-bin', server_id='1'):
    common_util.backup_localdirectory(mycnf_file)
    with io.open(mycnf_file, 'r') as opened_file:
        lines = [line.strip() for line in opened_file.readlines()]
        lines = common_util.update_block_config_file(lines, 'log-bin', logbin_base_name)
        lines = common_util.update_block_config_file(lines, 'server-id', server_id)
    
    with io.open(mycnf_file, 'wb') as opened_file:
        opened_file.writelines(["%s%s" % (line, "\n") for line in lines])

def get_mycnf_file():
    out = subprocess.check_output([client_bin, '--help'])
    sio = StringIO.StringIO(out)
    line = sio.readline()
    found = False
    result = None
    while line:
        line = line.strip()
        if found:
            result = line
            break
        if "Default options are read from the following files in the given order:" in line:
            found = True
        line = sio.readline()
    sio.close()
    results = result.split()
    for r in results:
        if os.path.exists(r):
            return r

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hv:a:", ["help", "action="])
    except getopt.GetoptError as err:
        # print help information and exit:
        print str(err)  # will print something like "option -a not recognized"
        sys.exit(2)
    verbose = False
    action = None
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("--action", '-a'):
            action = a
        else:
            assert False, "unhandled option"
    main(action, args)

