#!/tmp/guds_perl -w

use strict;
use POSIX qw(strftime);
use Sun::Solaris::Kstat;
use Getopt::Long;
use IO::Handle;
use integer;

my %cols = (# HDR => [Size, Description]
	"Time"	=>[8, "Time"],
	"hits"	=>[4, "Arc reads per second"],
	"miss"	=>[4, "Arc misses per second"],
	"read"	=>[4, "Total Arc accesses per second"],
	"Hit%"	=>[4, "Arc Hit percentage"],
	"miss%"	=>[5, "Arc miss percentage"],
	"dhit"	=>[4, "Demand Data hits per second"],
	"dmis"	=>[4, "Demand Data misses per second"],
	"dh%"	=>[3, "Demand Data hit percentage"],
	"dm%"	=>[3, "Demand Data miss percentage"],
	"phit"	=>[4, "Prefetch hits per second"],
	"pmis"	=>[4, "Prefetch misses per second"],
	"ph%"	=>[3, "Prefetch hits percentage"],
	"pm%"	=>[3, "Prefetch miss percentage"],
	"mhit"	=>[4, "Metadata hits per second"],
	"mmis"	=>[4, "Metadata misses per second"],
	"mread"	=>[5, "Metadata accesses per second"],
	"mh%"	=>[3, "Metadata hit percentage"],
	"mm%"	=>[3, "Metadata miss percentage"],
	"arcsz"	=>[5, "Arc Size"],
	"c" 	=>[4, "Arc Target Size"],
	"mfu" 	=>[4, "MFU List hits per second"],
	"mru" 	=>[4, "MRU List hits per second"],
	"mfug" 	=>[4, "MFU Ghost List hits per second"],
	"mrug" 	=>[4, "MRU Ghost List hits per second"],
	"eskip"	=>[5, "evict_skip per second"],
	"mtxmis"=>[6, "mutex_miss per second"],
	"rmis"	=>[4, "recycle_miss per second"],
	"dread"	=>[5, "Demand data accesses per second"],
	"pread"	=>[5, "Prefetch accesses per second"],
);
my %szcol = (
	"arcsz" => 1,
	"c"     => 1
);
my %v=();
my @hdr = qw(Time read miss miss% dmis dm% pmis pm% mmis mm% arcsz c);
my @xhdr = qw(Time mfu mru mfug mrug eskip mtxmis rmis dread pread read);
my $int = 1;		# Print stats every 1 second by default
my $count = 0;		# Print stats forever
my $hdr_intr = 20;	# Print header every 20 lines of output
my $opfile = "";
my $sep = "  ";		# Default seperator is 2 spaces
my $version = "0.2";
my $cmd = "Usage: arcstat.pl [-hvx] [-f fields] [-o file] [interval [count]]\n";
my %cur;
my %d;
my $out;
my $kstat = Sun::Solaris::Kstat->new();
STDOUT->autoflush;

sub detailed_usage {
	print STDERR "Arcstat version $version\n$cmd";
	print STDERR "Field definitions are as follows\n";
	foreach my $hdr (keys %cols) {
		print STDERR sprintf("%6s : %s\n", $hdr, $cols{$hdr}[1]);
	}
	print STDERR "\nNote: K=10^3 M=10^6 G=10^9 and so on\n";
	exit(1);

}

sub usage {
	print STDERR "Arcstat version $version\n$cmd";
	print STDERR "\t -x : Print extended stats\n";
	print STDERR "\t -f : Specify specific fields to print (see -v)\n";
	print STDERR "\t -o : Print stats to file\n";
	print STDERR "\t -s : Specify a seperator\n\nExamples:\n";
	print STDERR "\tarcstat -o /tmp/a.log 2 10\n";
	print STDERR "\tarcstat -s , -o /tmp/a.log 2 10\n";
	print STDERR "\tarcstat -v\n";
	print STDERR "\tarcstat -f Time,Hit%,dh%,ph%,mh%\n";
	exit(1);
}

sub init {
	my $desired_cols;
	my $xflag = '';
	my $hflag = '';
	my $vflag;
	my $res = GetOptions('x' => \$xflag,
		'o=s' => \$opfile,
		'help|h|?' => \$hflag,
		'v' => \$vflag,
		's=s' => \$sep,
		'f=s' => \$desired_cols);
	$int = $ARGV[0] || $int;
	$count = $ARGV[1] || $count;
	usage() if !$res or $hflag or ($xflag and $desired_cols);
	detailed_usage() if $vflag;
	@hdr = @xhdr if $xflag;		#reset headers to xhdr
	if ($desired_cols) {
		@hdr = split(/[ ,]+/, $desired_cols);
		# Now check if they are valid fields
		my @invalid = ();
		foreach my $ele (@hdr) {
			push(@invalid, $ele) if not exists($cols{$ele});
		}
		if (scalar @invalid > 0) {
			print STDERR "Invalid column definition! -- "
				. "@invalid\n\n";
			usage();
		}
	}
	if ($opfile) {
		open($out, ">$opfile") ||die "Cannot open $opfile for writing";
		$out->autoflush;
		select $out;
	}
}

# Capture kstat statistics. We maintain 3 hashes, prev, cur, and
# d (delta). As their names imply they maintain the previous, current,
# and delta (cur - prev) statistics.
sub snap_stats {
	my %prev = %cur;
	if ($kstat->update()) {
		printf("<State Changed>\n");
	}
	my $hashref_cur = $kstat->{"zfs"}{0}{"arcstats"};
	%cur = %$hashref_cur;
	foreach my $key (keys %cur) {
		next if $key =~ /class/;
		if (defined $prev{$key}) {
			$d{$key} = $cur{$key} - $prev{$key};
		} else {
			$d{$key} = $cur{$key};
		}
	}
}

# Pretty print num. Arguments are width, num, and divisor
sub prettynum {
	my @suffix=(' ','K', 'M', 'G', 'T', 'P', 'E', 'Z');
	my $num = $_[1] || 0;
	my $sz = $_[0];
	my $index = 0;
	return sprintf("%s", $num) if not $num =~ /^[0-9\.]+$/;
	while ($num >= $_[2] and $index < 8) {
		$num = $num/$_[2];
		$index++;
	}
	return sprintf("%*d", $sz, $num) if ($index == 0);
	return sprintf("%*d%s", $sz - 1, $num,$suffix[$index]);
}

sub print_values {
	foreach my $col (@hdr) {
	        if (defined $v{$col}) {
		    my $divisor = defined $szcol{$col} ? 1024 : 1000;
		    printf("%s%s", prettynum($cols{$col}[0], $v{$col}, $divisor), $sep);
                }
	}
	printf("\n");
}

sub print_header {
	foreach my $col (@hdr) {
	        if (defined $v{$col}) {
		     printf("%*s%s", $cols{$col}[0], $col, $sep);
		}
	}
	printf("\n");
}

sub calculate {
	%v=();
	$v{"Time"}   = strftime("%H:%M:%S", localtime);
	$v{"hits"}   = $d{"hits"}/$int;
	$v{"miss"}   = $d{"misses"}/$int;
	$v{"read"}   = $v{"hits"} + $v{"miss"};
	$v{"Hit%"}   = $v{"read"} > 0 ? 100*$v{"hits"}/$v{"read"} : 0;
	$v{"miss%"}  = $v{"read"} > 0 ? 100 - $v{"Hit%"} : 0;

	$v{"dhit"}   = ($d{"demand_data_hits"} + $d{"demand_metadata_hits"})/$int;
	$v{"dmis"}   = ($d{"demand_data_misses"}+$d{"demand_metadata_misses"})/$int;
	$v{"dread"}  = $v{"dhit"} + $v{"dmis"};
	$v{"dh%"}    = $v{"dread"} > 0 ? 100*$v{"dhit"}/$v{"dread"} : 0;
	$v{"dm%"}    = $v{"dread"} > 0 ? 100 - $v{"dh%"} : 0;

	$v{"phit"}   = ($d{"prefetch_data_hits"} + $d{"prefetch_metadata_hits"})/$int;
	if (defined $d{"prefetch_metadata_misses"}) {
	  $v{"pmis"}   = ($d{"prefetch_data_misses"}+$d{"prefetch_metadata_misses"})/$int;
	} else {
	  $v{"pmis"}   = 0; # S11.3 removed the above 2 kstats when the prefetch code changed
	}
	$v{"pread"}  = $v{"phit"} + $v{"pmis"};
	$v{"ph%"}    = $v{"pread"} > 0 ? 100*$v{"phit"}/$v{"pread"} : 0;
	$v{"pm%"}    = $v{"pread"} > 0 ? 100 - $v{"ph%"} : 0;

	$v{"mhit"}   = ($d{"prefetch_metadata_hits"}+$d{"demand_metadata_hits"})/$int;
	if (defined $d{"prefetch_metadata_misses"}) {
	  $v{"mmis"}   = ($d{"prefetch_metadata_misses"}+$d{"demand_metadata_misses"})/$int;
	} else {
	  $v{"mmis"}   = ($d{"demand_metadata_misses"})/$int;
          # S11.3 removed the prefetch_metadata_misses kstat when the prefetch code changed
	}
	$v{"mread"}  = $v{"mhit"} + $v{"mmis"};
	$v{"mh%"}    =  $v{"mread"} > 0 ? 100*$v{"mhit"}/$v{"mread"} : 0;
	$v{"mm%"}    =  $v{"mread"} > 0 ? 100 - $v{"mh%"} : 0;
	$v{"arcsz"}  = $cur{"size"};
	$v{"c"}      = $cur{"c"};
	$v{"mfu"}    = $d{"hits"}/$int;
	$v{"mru"}    = $d{"mru_hits"}/$int;
	$v{"mrug"}   = $d{"mru_ghost_hits"}/$int;
	$v{"mfug"}   = $d{"mru_ghost_hits"}/$int;
	$v{"eskip"}  = $d{"evict_skip"}/$int if defined $d{"evict_skip"};
	$v{"rmiss"}  = $d{"recycle_miss"}/$int if defined $d{"recycle_miss"};
	$v{"mtxmis"} = $d{"mutex_miss"}/$int if defined $d{"mutex_miss"};
}

sub main {
	my $i = 0;
	my $count_flag = 0;

	init();
	if ($count > 0) { $count_flag = 1; }
	while (1) {
                snap_stats();
		calculate();
		print_header() if ($i == 0);
		print_values();
		last if ($count_flag == 1 && $count-- <= 1);
		$i = ($i == $hdr_intr) ? 0 : $i+1;
		sleep($int);
	}
	close($out) if defined $out;
}

&main;
