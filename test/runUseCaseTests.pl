#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use Params::Check qw[check];
use File::Basename;
use Clone qw[clone];

my $params = {};
# Get and check params {{{
GetOptions ($params,
		"level=i",
		"depend!",
		"verbose!",
		"output=s",
		"jobs=s",
	)
	or die("Error in command line arguments\n");
$params = check( 
	{
		level => {
			required => 1,
			defined => 1,
		},
		verbose => {
			required => 0,
			default => 1,
		},
		depend => {
			required => 0,
			default => 1,
		},
		output => {
			required => 0,
			default => "TAP",
			allow => [ "TAP", "XML" ],
		},
		jobs => {
			required => 0,
			default => 9,
		},
	}, 
	$params, 
	1 ) or die "Could not parse arguments! Run perldoc runUseCaseTests.pl for documentation!";

$params->{level} = sprintf("%03d", $params->{level});
# }}}

# Get some common stuff {{{
my $pathwc = dirname($0)."/..";
chdir($pathwc);
# }}}

sub runTests { # {{{
	my ($params) = @_;

	if ($params->{depend} == 1) {
		#print "Running previous levels of tests\n";
		my $p = clone($params);
		$p->{level}--;
		$p->{level} = sprintf("%03d", $p->{level});
		#print "Checking ".$p->{level}."\n";
		while (! -d "test/usecase_".$p->{level} and $p->{level} > 0 ) {
			$p->{level}--;
			$p->{level} = sprintf("%03d", $p->{level});
			#print "Checking ".$p->{level}."\n";
		}
		if ( $p->{level} >= 0 ) {
			runTests($p);
		}
		#else {
		#	print "No more levels found\n";
		#}
	}

	print "Running Tests for ".$params->{level}."\n";

	my $file_pattern = 'test/usecase_'.$params->{level}.'/*.t';
	my @tests = `ls -1 $file_pattern 2>/dev/null`;
	chomp(@tests);
	if (scalar(@tests) == 0) {
		return;
	}

	my $success = 0;
	# For parallel jobs
	my $rules = { seq =>  [
				{ par => 'test/usecase_'.$params->{level}.'/00*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/01*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/02*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/03*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/04*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/05*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/06*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/07*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/08*.t' },
				{ par => 'test/usecase_'.$params->{level}.'/09*.t' },
				{ par => '**'     },
			],
		};
	my $args_formatter = {
			verbosity => $params->{verbose},
			timer => 1,
			failures => 1,
			show_count => 1,
			normalize => 1,
			color => 1,
			errors => 1,
			jobs => $params->{jobs},
		};
	my $args = { # For the harness
			#exec => [ 'sudo', 'tools/perlworkingcopy' ],
			lib => [ '.' ],
			merge => 1,
			jobs => $params->{jobs},
			rules => $rules,
		};

	my $OUTXML = undef;
	system "mkdir -p test-reports 2>/dev/null";
	my $file = "test-reports/UseCase".$params->{level}.".xml";
	if ($params->{output} eq "XML") {
		use TAP::Formatter::JUnit;
		my $formatter = TAP::Formatter::JUnit->new($args_formatter);
		open $OUTXML, '>', $file
			or die "Cannot write file '$file': $!";
		$formatter->stdout($OUTXML);
		$args->{formatter} = $formatter;
	}
	elsif ($params->{output} eq "TAP") {
		use TAP::Formatter::Console;
		my $formatter = TAP::Formatter::Console->new($args_formatter);
		$args->{formatter} = $formatter;
	}

	use TAP::Harness;
	my $harness = TAP::Harness->new($args);
	my $aggregator = $harness->runtests(@tests);
	$success = ($aggregator->get_status() eq "PASS");

	if ($params->{output} eq "XML") {
		close $OUTXML
			or die "Cannot write file '$file': $!";
		print "JUnit Report written to $file\n";
	}

	print "\n";
	if ($success == 0) {
		print "Tests Failed\n";
		exit 1;
	}
	else {
		print "Tests Successful!\n";
	}
} # }}}

runTests($params);

__END__

=head1 NAME

runUseCaseTests.pl currently part of https://github.com/marcpopp/check_glusterfs

=head1 SYNOPSIS

 runUseCaseTests.pl 
         --level X
         [--output { TAP | XML }]
         [--[no-]verbose]
         [--jobs 9]
         [--[no-]depend]

=head1 DESCRIPTION

This is an improved wrapper to run perl tests.
It supports parallism with dependencies, manuall running subsets of tests, JUnit XML and TAP output

=head2 levels

This skript is expecting a set of levels of tests. 
Each level is a subfolder with the nameing schema "usecase_000".
The levels do not have to be consecutively. 
Each level is execute strictly seperated.

=head2 parallel groups

In each level there can be up to 10 parallel groups.
Each parallel group is labeled by the 2 starting chars of the test file names. 
They have to follow the schema "00*.t". Currently 00 through 09 are supported. More might come.
The parallel gorups do not have to be consecutively. 
All parallel groups of a level are run one after the other, starting from 00.
All tests of a parallel group are executed in parallel. (the concurrency can be adjusted with --jobs) 

=head1 OPTIONS

=head2 --level X

Mandatory.
The level up to which the tests should be run.

=head2 --output TYPE

Optional.
The output type to use. Currently the following outputs are supported:

=over 4

=item TAP = TAP::Formatter::Console

=item XML = TAP::Formatter::JUnit

=back

=head2 --verbose

Optional. Default is off.
Enable verbosity for the TAP::Formater

=head2 --jobs X

Optional. Default is 9.
The number of concurrent jobs to be run.

=head2 --depend

Optional. Default is on
Respect dependencies of levels. If this is turned off (--no-depend) then only the level given in the parameter --level is executed.
THis is a good parameter for manual execution, if you want to run or rerun certain tests only.

=head1 CAVEATS

Doesn't automatically skip successful tests on rerun (that would be nice, wouldn't it?)

=head1 DEPENDENCIES

=over 8

=item C<Getopt::Long>

=item C<pod::Usage>

=item C<Params::Check>

=item C<Clone>

=item C<TAP::Harness>

=item C<TAP::Formatter::Console>

=item C<TAP::Formatter::JUnit>

=back

=head1 AUTHOR

Marc Popp <marc dot popp at sunny-computing dot com>

http://www.sunny-computing.com/

