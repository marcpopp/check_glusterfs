# check_glusterfs
A Fork of Philippe Kueck check_glusterfs: https://www.unixadm.org/nagios/check_glusterfs


## Features
* Check Volume stats
* Check Brick online status
* Check Brick disk usage
* Check Brick inode usage
* Check Heal status
* Performance data for Volume usage


## ToDo
* Add check for peer status
* Runs volume heal info if heal check is enabled and reports alert for entries older than --ttl. State cache can be disabled by setting --ttl 0
* Rebalance recommendation (brick used diff to average >%)


