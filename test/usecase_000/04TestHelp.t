#!/usr/bin/perl -w

use strict;
use warnings;

use test::UseCaseTesting;
my $test_command = 'perl check_glusterfs.pl';

my $result = run({
	COMMAND => <<EOD
function gluster {
	echo "[TESTENV] call: gluster \$*"
}

$test_command --help
EOD
,
	EXITCODE => 3
});

ok ($result->{stderr} =~ m/SYNOPSIS/, "Stderr has help text");

done_testing();
