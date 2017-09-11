#!/usr/bin/perl -w

use strict;
use warnings;

use test::UseCaseTesting;
my $test_command = 'perl check_glusterfs.pl';

my $result = run({
	COMMAND => $test_command,
	EXITCODE => 0,
	GLUSTER => <<EOD
#!/bin/bash

echo "[TESTENV] call: gluster \$*" >>gluster.calls.debug.log

if [ "\$1 \$2" == "volume info" ]; then
	echo Volume Name: volume01
	echo Type: Replicate
	echo Volume ID: 00000000-0000-0000-0000-000000000000
	echo Status: Started
	echo Snapshot Count: 0
	echo Number of Bricks: 1 x 3 = 3
	echo Transport-type: tcp
	echo Bricks:
	echo Brick1: server1:/data/glusterfs/volume01/brick1
	echo Brick2: server2:/data/glusterfs/volume01/brick1
	echo Brick3: server3:/data/glusterfs/volume01/brick1
	echo Options Reconfigured:
	echo cluster.consistent-metadata: on
elif [ "\$1 \$2 \$3 \$4" == "volume status all detail" ]; then
	echo Status of volume: volume01
	for i in server{1..3}; do
		echo ------------------------------------------------------------------------------
		echo Brick                : Brick \$i:/data/glusterfs/volume01/brick1
		echo TCP Port             : 49152               
		echo RDMA Port            : 0                   
		echo Online               : Y                   
		echo Pid                  : 29050               
		echo File System          : xfs                 
		echo Device               : /dev/sdc1           
		echo Mount Options        : rw,seclabel,noatime,attr2,inode64,noquota
		echo Inode Size           : 512                 
		echo Disk Space Free      : 737.6GB             
		echo Total Disk Space     : 744.8GB             
		echo Inode Count          : 390705152           
		echo Free Inodes          : 390700461  
	done
elif [ "\$1 \$2 \$3 \$4 \$5" == "volume heal volume01 info split-brain" ]; then
	for i in server{1..3}; do
		echo Brick \$i:/data/glusterfs/volume01/brick1
		echo Status: Connected
		echo Number of entries in split-brain: 0
		echo
	done
elif [ "\$1 \$2 \$3 \$4 \$5" == "volume heal volume01 info heal-failed" ]; then
	echo Gathering list of heal failed entries on volume volume01 has been unsuccessful on bricks that are down. Please check if all brick processes are running.
elif [ "\$1 \$2 \$3 \$4 \$5" == "volume heal volume01 info healed" ]; then
	echo Gathering list of healed entries on volume volume01 has been unsuccessful on bricks that are down. Please check if all brick processes are running.
elif [ "\$1 \$2" == "peer status" ]; then
	echo Number of Peers: 3
	for i in server{1..3}; do
		echo
		echo Hostname: \$i
		echo UUID: 000000
		echo "State: Peer in Cluster (Connected)"
	done
else
	echo "[TESTENV] call not found: gluster \$*"  >>gluster.calls.debug.log
fi
EOD
});

ok ($result->{stdout} =~ m/^OK - /, "Everything is OK");

done_testing();
