semanage
yum provides /usr/sbin/semanage

allow apache to listen on different port:

semanage port -a -t http_port_t -p tcp 12345

controll file access:

ls -dZ /var/www/html

list all:

grep httpd /etc/selinux/targeted/contexts/files/file_contexts

chcon: change context.

ls -dZ /mount/mysqlmirror/

chcon -R -t httpd_sys_content_t /mount/mysqlmirror

semanage fcontext -a -t httpd_sys_content_t "/mount/mysqlmirror(/.*)?"

restorecon -R -v /mount/mysqlmirror/
