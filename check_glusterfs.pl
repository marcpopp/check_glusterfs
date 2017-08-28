#!/usr/bin/perl
#
# $Id: check_glusterfs.pl 508 2017-01-31 16:01:01Z phil $
#
# program: check_glusterfs
# author, (c): Philippe Kueck <projects at unixadm dot org>
# 

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

$|++;
my ($vols, $status, @out, @perfdata);
my $s = {'b' => 0, 'kb' => 10, 'mb' => 20, 'gb' => 30, 'tb' => 40};
my $thrs = {
	'diskwarn' => 90,
	'diskcrit' => 95,
	'inodewarn' => 90,
	'inodecrit' => 95,
	'volume' => 'all',
	'perfdata' => 0
};

sub x_crit {$status = 2 if $status < 2}
sub x_warn {$status = 1 if $status < 1}

sub nagexit {
	my $exitc = {0 => 'OK', 1 => 'WARNING', 2 => 'CRITICAL', 3 => 'UNKNOWN'};
	printf "%s - %s%s\n", $exitc->{$_[0]}, $_[1],
		($thrs->{'perfdata'}?"|".join ' ', @perfdata:"");
	exit $_[0]
}

Getopt::Long::Configure("no_ignore_case");
GetOptions(
	'H=s' => sub {},
	'w|diskwarn=i' => \$thrs->{'diskwarn'},
	'c|diskcrit=i' => \$thrs->{'diskcrit'},
	'W|inodewarn=i' => \$thrs->{'inodewarn'},
	'C|inodecrit=i' => \$thrs->{'inodecrit'},
	'l|volume=s' => \$thrs->{'volume'},
	'p|perfdata' => \$thrs->{'perfdata'},
	'f|warnonfailedheal' => \$thrs->{'warnonfailedheal'},
	'h|help' => sub {pod2usage({'-exitval' => 3, '-verbose' => 2})}
) or pod2usage({'-exitval' => 3, '-verbose' => 0});

sub fetchinfo {
	my ($v, $gh, $bi, @types);
	open $gh, "gluster volume info $thrs->{'volume'} 2>/dev/null|" or die $@;
	while (<$gh>) {
		$v = $1 if /^Volume Name: (.+)$/;
		next unless $v;
		if (/^Status: ((?:Start|Stopp|Creat)ed)$/) {
			$vols->{$v}->{'status'} = $1; next
		}
		if (/^Type: (.+)$/) {
			# Remember the order of the types
			@types = ();
			foreach my $t ( split("-", $1) ) {
				$t =~ s/d$//g;
				push @types, $t,
			}
			# there are always 2 values in the info about brick numbers
			unshift @types, "Distribute"
				if (scalar(@types) == 1);
			next
		}
		if (my @tmp = /^Number of Bricks:(?: (\d+) x (\d+)(?: x (\d+))? =)? \d+$/) {
			# set the number of bricks per type
			@tmp = grep { defined $_ && $_ ne '' } @tmp;
			for (my $i = 0; $i <= $#types; $i++) {
				if (! defined($tmp[$i])) {
					nagexit 3, "Cannot read architecture of volume '$v': $_ with types '".join(',', @types)."'";
				}
				$vols->{$v}->{'type'}->{ $types[$i] } = $tmp[$i];
			}
			next
		}
		if (my @tmp = /^Brick(\d+): ([\w._-]+:\/.+?)(?: +\([a-z]+\))?$/) {
			$vols->{$v}->{'bricks'}->{$2}->{'online'} = 0;
			$vols->{$v}->{'bricks'}->{$2}->{'index'} = $1;
			next
		}
	}
	close $gh;
	undef $v;
	open $gh, "gluster volume status $thrs->{'volume'} detail 2>&1|" or die $@;
	while (<$gh>) {
		nagexit 3, "another copy might be running, cannot continue"
			if /^Another transaction .+ in progress/;
		if (/^Status of volume: (.+)$/) {$v = $1; undef $bi; next}
		next unless $v;
		if (/^Brick\s+: Brick ([\w._-]+:\/.*)$/) {$bi = $1; next}
		next unless defined $bi;
		if (/^Online +: ([YN])/) {
			$vols->{$v}->{'bricks'}->{$bi}->{'online'} = ($1 eq "Y");
			next
		}
		if (/^(Total)? ?Disk Space (Free)? *: (\d+\.\d+)([TGMK]?B)/) {
			$vols->{$v}->{'bricks'}->{$bi}->{lc ($1||$2)} = $3*2**$s->{lc $4};
			next
		}
		if (/^(Free)? ?(Inode)s? (Count)? *: (\d+)/) {
			$vols->{$v}->{'bricks'}->{$bi}->{lc $2 . lc ($1||$3)} = $4;
		}
	}
	close $gh
}

sub fetchvolumesizes {
	my $units = 'M';
	foreach my $v (keys %$vols) {
		my @stdout = `df -aB$units`;
		@stdout = grep { /localhost:\/$v\s/ } @stdout;
		if (scalar(@stdout) == 0) {
			# mount it
			`mkdir -p /mnt/$v 2>&1 && mount -t glusterfs localhost:/$v /mnt/$v`;
			@stdout = `df -aB$units`;
		}
		foreach (@stdout) {
			if (/localhost:\/$v\s+([0-9]+)$units\s+([0-9]+)$units\s+([0-9]+)$units/) {
				my ($size, $used, $free) = ($1, $2, $3);
				push @perfdata, sprintf "'%s_used'=%d%s;%d;%d;0;%d",
					$v,
					$used, $units."B",
					$size / 100 * $thrs->{'diskwarn'},
					$size / 100 * $thrs->{'diskcrit'},
					$size;
				last;
			}
		}
	}
}

sub fetchheal {
	my $bi;
	foreach my $v (keys %$vols) {
		foreach my $h ('split-brain', 'heal-failed', 'healed') {
			open my $gh, "gluster volume heal $v info $h 2>&1|"
				or nagexit 3, $@;
			while (<$gh>) {
				nagexit 3, "another copy might be running, cannot continue"
					if /^Another transaction .+ in progress/;
				if (/^Brick ([\w._-]+:\/.*)$/) {$bi = $1; next}
				next unless $bi;
				if (/^Number of entries: (\d+)/) {
					push @perfdata, sprintf "'%s_b%d_%s'=%d;0;0;0;",
						$v, $vols->{$v}->{'bricks'}->{$bi}->{'index'},
						$h, $1;
					$vols->{$v}->{'bricks'}->{$bi}->{$h} = $1
				}
			}
			close $gh
		}
	}
}

sub check_peer_status {
	my $hostname;
	my $failed_count = 0;
	open my $gh, "gluster peer status 2>&1|"
		or nagexit 3, $@;
	while (<$gh>) {
		if (/^Hostname: (.*)$/) {
			$hostname = $1;
			next;
		}
		next unless $hostname;
		if (/^State: (.+)$/) {
			my $state = $1;
			if ($state ne 'Peer in Cluster (Connected)') {
				push @out, sprintf("Peer '%s' is in non-acceptable state '%s'", $hostname, $state);
				$failed_count++;
				x_warn if ($failed_count == 1);
				x_crit if ($failed_count > 1);
			}
		}
	}
	close $gh
}

sub check {
	foreach (keys %$vols) {
		# warn on stopped volumes
		unless ($vols->{$_}->{'status'} eq 'Started') {
			if ($vols->{$_}->{'status'} ne 'Created') {
				push @out, sprintf "%s stopped", $_;
				x_warn
			}
			next
		}
		
		# get brick redundancy
		my $offline = 0;
		my $redundancy = ($vols->{$_}->{'type'}->{'Replicate'} || 1);

		# check bricks
		foreach my $brick (sort {$vols->{$_}->{'bricks'}->{$a}->{'index'} >
				$vols->{$_}->{'bricks'}->{$b}->{'index'}}
				keys %{$vols->{$_}->{'bricks'}}) {
			unless ($vols->{$_}->{'bricks'}->{$brick}->{'online'}) {
				push @out, sprintf "%s_b%d is offline",
					$_, $vols->{$_}->{'bricks'}->{$brick}->{'index'};
				if (++$offline > $redundancy - 1) {x_crit}
				else {x_warn}
				next
			}
			# should never happen
			next unless defined $vols->{$_}->{'bricks'}->{$brick}->{'inodefree'} &&
				defined $vols->{$_}->{'bricks'}->{$brick}->{'inodecount'} &&
				defined $vols->{$_}->{'bricks'}->{$brick}->{'free'} &&
				defined $vols->{$_}->{'bricks'}->{$brick}->{'total'};

			# check heal status
			if ($thrs->{'warnonfailedheal'} &&
				($vols->{$_}->{'bricks'}->{$brick}->{'heal-failed'}||0) > 0) {
				push @out, sprintf "%s has %d failed heals",
					$_, $vols->{$_}->{'bricks'}->{$brick}->{'heal-failed'};
				x_warn
			}
			# check split brain status
			if (($vols->{$_}->{'bricks'}->{$brick}->{'split-brain'}||0) > 0) {
				push @out, sprintf "%s has %d split-brains",
					$_, $vols->{$_}->{'bricks'}->{$brick}->{'split-brain'};
				x_crit
			}

			# check disk and inode usage
			for my $i (
				['inodewarn', 'inodecrit', 'inodefree', 'inodecount', 'inodes'],
				['diskwarn', 'diskcrit', 'free', 'total', 'diskspace']) {

				my $tused = $vols->{$_}->{'bricks'}->{$brick}->{$i->[3]} -
					$vols->{$_}->{'bricks'}->{$brick}->{$i->[2]};
				my $twarn = $vols->{$_}->{'bricks'}->{$brick}->{$i->[3]} *
					$thrs->{$i->[0]}/100;
				my $tcrit = $vols->{$_}->{'bricks'}->{$brick}->{$i->[3]} *
					$thrs->{$i->[1]}/100;

				if ($tused >= $tcrit) {
					push @out, sprintf "%s_b%d %s is critical",
						$_, $vols->{$_}->{'bricks'}->{$brick}->{'index'},
						$i->[4];
					x_crit
				} elsif ($tused >= $twarn) {
					push @out, sprintf "%s_b%d %s warning",
						$_, $vols->{$_}->{'bricks'}->{$brick}->{'index'},
						$i->[4];
					x_warn
				}
				push @perfdata, sprintf "'%s_b%d_%s'=%d;%d;%d;0;%d",
					$_, $vols->{$_}->{'bricks'}->{$brick}->{'index'},
					$i->[4], $tused, $twarn, $tcrit,
					$vols->{$_}->{'bricks'}->{$brick}->{$i->[3]};
			}
		}
	}
}

eval {foreach (split ':', $ENV{'PATH'}) {die "" if -x "$_/gluster"}};
nagexit 3, "no gluster binary found" unless $@;

fetchinfo;
nagexit 3, "no volumes found" unless scalar keys %$vols;
fetchheal;

$status = 0;
check;
check_peer_status;
fetchvolumesizes if ($thrs->{'perfdata'});
@out = ("Everything is OK") 
	if (scalar(@out) == 0);
nagexit $status, join ", ", @out

__END__

=head1 NAME

check_glusterfs

=head1 VERSION

$Revision: 508 $

=head1 SYNOPSIS

 check_glusterfs [-H HOST] [-p] [-f] [-l VOLUME]
         [-w DISKWARN] [-c DISKCRIT]
         [-W INODEWARN] [-C INODECRIT]

=head1 OPTIONS

=over 8

=item B<H>

Optional. Dummy for compatibility with Nagios.

=item B<p>,B<perfdata>

Optional. Print perfdata of all or the specified volume. I<Warning>: depending on how many volumes and bricks you have, this may result in a lot of data.

=item B<f>,B<warnonfailedheal>

Optional. Warn if the I<heal-failed> log contains entries. The log can be cleared by restarting C<glusterd>.

=item B<l>,B<volume>

Optional. Only check the specified I<VOLUME>. If B<--volume> is not set, all volumes are checked.

=item B<w>,B<diskwarn>

Optional. Warn if disk usage is above I<DISKWARN>. Defaults to 90 (percent).

=item B<c>,B<diskcrit>

Optional. Return a critical error if disk usage is above I<DISKCRIT>. Defaults to 95 (percent).

=item B<W>,B<inodewarn>

Optional. Warn if inode usage is above I<DISKWARN>. Defaults to 90 (percent).

=item B<C>,B<inodcrit>

Optional. Return a critical error if inode usage is above I<DISKCRIT>. Defaults to 95 (percent).

=back

=head1 DESCRIPTION

This nagios/icinga check script checks the glusterfs volumes, their bricks and the heal logs. If enabled, it returns the per-brick perfdata split-brain, heal-failed, healed, disk used and inodes used.

=head1 CAVEATS

Do B<NOT> run multiple copies of C<check_glusterfs> simultanously in a cluster. All bricks will appear offline.

=head1 DEPENDENCIES

=over 8

=item C<Getopt::Long>

=item C<pod::Usage>

=item C<gluster>

=back

=head1 AUTHOR

Philippe Kueck <projects at unixadm dot org>
