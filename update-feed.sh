#!/bin/bash


FILE=/var/www/html/svn.atom
LOG=/var/tmp/feed2.log
DEBUGLOG=/var/tmp/svn2feed.debug

rm -f "${FILE}"

echo "Updating rev: $2 repo: $1" >> $LOG

/var/www/svn/localrepo/hooks/svn2feed/svn2feed.rb -d --debug-log=$DEBUGLOG --format=atom --feed-url=http://server00/repos/localrepo/ --feed-title="Localrepo SVN" --item-url=http://server00/repos/localrepo/  --feed-file=${FILE} --repo="$1" --revision="$2" --ldap-author --ldap-server=ldap00 --ldap-base="o=example,c=US" --ldap-objectclass=uid --check-puppet-validate --check-puppet-lint --max-items=25 1>>$LOG 2>>$LOG

