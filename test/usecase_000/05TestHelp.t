#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Data::Dumper;
use File::Temp qw/ tempfile /;

my $test_command = 'perl check_glusterfs.pl';
my $test_params  = '--help';
my $expected_exitcode = 3;

my (undef, $stderr_filename) = tempfile();

# Adding the Test environment, so we can fake a glsuterfs installation
my $cmd = <<EOD
function gluster {
	echo "[TESTENV] call: gluster \$*"
}

$test_command $test_params 2>$stderr_filename
EOD
;

my $stdout = `$cmd`;
my $exitcode = int($?/256);
my $stderr = `cat $stderr_filename`;

is ($exitcode, $expected_exitcode, "Exit code is $expected_exitcode");
ok ($stderr =~ m/SYNOPSIS/, "Stderr has help text");

done_testing();
