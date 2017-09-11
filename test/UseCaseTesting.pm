package test::UseCaseTesting;

use Test::More;
use Test::Deep;
use Data::Dumper;
use File::Temp qw/ tempfile /;

use strict;
use warnings;
use English;

use vars qw(@ISA $VERSION $AUTOLOAD @EXPORT @EXPORT_OK);
use Exporter 'import'; # {{{

$VERSION        = "0.0.1";
# Export our scalars and functions
@EXPORT		= qw( 
			run
		);
# Add symbols exported by commonly needed packages, too.
push @EXPORT, @{Data::Dumper::EXPORT};
push @EXPORT, @{Test::Deep::EXPORT};
push @EXPORT, @{Test::More::EXPORT};
push @EXPORT, "tempfile";
@EXPORT_OK      = @EXPORT;
# }}}

# Public Interface
# run {{{

=head2 run

Run a command, check expected exit code and return stdout and stderr

=head3 Parameter

GLUSTER: The gluster script that will be used
COMMAND: The command to run (bash syntax)
EXITCODE: The exit code expected

=head3 Return values

exitcode: the exit code if the process
stdout: stdout
stderr: stderr

=cut

sub run {
	my ($params) = @_;
	my $rc       = {};

	my (undef, $stdout_filename) = tempfile();
	my (undef, $stderr_filename) = tempfile();

	# Satisfy the check for the gluster binary
	open FH, ">", "gluster";
	print FH $params->{GLUSTER};
	close FH;
	system "chmod a+x gluster";

	open FH, "| bash";
	chomp($params->{COMMAND});
	print FH "export PATH=.:\$PATH\n";
	print FH $params->{COMMAND}." 2>$stderr_filename >$stdout_filename";
	close FH;
	$rc->{exitcode} = int($?/256);
	$rc->{stdout}   = scalar(`cat $stdout_filename`);
	$rc->{stderr}   = scalar(`cat $stderr_filename`);

	my $res = is (
		$rc->{exitcode},
		$params->{EXITCODE},
		"Exit code is ".$params->{EXITCODE}
	);

	if ($res == 0) {
		my $dl = $Data::Dumper::Maxdepth;
		$Data::Dumper::Maxdepth = 3;
		print STDERR "Debug: " . Dumper($rc);
		$Data::Dumper::Maxdepth = $dl;
	}

	return $rc;
} # }}}

1;
