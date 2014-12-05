#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use DBI;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakImages.pm";
require "/opt/home/merit/Merit_Robots/Forever21_US.pm";
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';
###########################################

####Variable Initialization##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
my $robotname_detail=$robotname;
my $robotname_list=$robotname;
$robotname_list =~ s/\-\-Detail/--List/igs;
$retailer_name =~ s/\-\-Detail\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='For';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
##########User Agent######################
my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

###########################################
use Config::Tiny;
use Try::Tiny;

# Set worker_id
my $worker_id = 'default';
if (defined $ARGV[1]) {
	$worker_id = sprintf("%03d", $ARGV[1]);
}

# Read the settings from the config file
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) {
	# Die if reading the settings failed
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, hostname(), 'aw-' . $worker_id . '@' . hostname());

my $database = AnorakDB->new($logger,$executionid);
$database->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Conect to image storage
my $images = AnorakImages->new($logger);
$images->connect($ini->{images}->{path});

# Conect to Utility package
my $utility = AnorakUtility->new($logger,$ua);
my $product_object_key = $ARGV[0];
my $product_url = $ARGV[1];
my $hashref = $database->GetAllUrls("c44bf3a82bb9214a85f2cc752298ff160a84d69");
my %hashUrl = %$hashref;
my $count;
foreach (keys %hashUrl)
{
	my $product_object_key = $_;
	my $product_url = $hashUrl{$_};
	$count++;
	print "$count -> $product_object_key -> $product_url\n";
	&Forever21_US::Forever21_US_DetailProcess($product_object_key,$product_url,'Forever21-US--worker',"c44bf3a82bb9214a85f2cc752298ff160a84d69",$logger,'http://frawspcpx.cloud.trendinglines.co.uk:3129',$ua,$database,$images,$utility);
	# exit;
}
=cut
open ss,"input.txt";
while(<ss>)
{
	chomp;
	if($_ =~ m/([^>]*?)\t([^>]*?)$/is)
	{
		my $product_object_key = $1;
		my $product_url = $2;
		print "$. -> $product_object_key -> $product_url\n";
		&Forever21_US::Forever21_US_DetailProcess($product_object_key,$product_url,'Forever21-US--worker',"c44bf3a82bb9214a85f2cc752298ff160a84d69",$logger,'http://frawspcpx.cloud.trendinglines.co.uk:3129',$ua,$database,$images,$utility);
	}
}
close ss;
=cut
$database->disconnect();
