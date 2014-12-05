#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use DBI;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
use Try::Tiny;
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakImages.pm";
require "/opt/home/merit/Merit_Robots/Walmart_US.pm";
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
my $Retailer_Random_String='Wal';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
##########User Agent######################
my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;

###########################################


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

my $hashref = $database->GetAllUrls("597cc6fd67d142785c038f344273a0c12e8a38");
my %hashUrl = %$hashref;
 &Walmart_US::Walmart_US_DetailProcess('0457F9DE1D0A40A2A89DFF6936406781','http://www.walmart.com/ip/36296394','Walmart-US--Worker',"597cc6fd67d142785c038f344273a0c12e8a38",$logger,"http://frawspcpx.cloud.trendinglines.co.uk:3129",$ua,$database,$images,$utility);
 exit;
foreach (keys %hashUrl)
{
	my $product_object_key = $_;
	my $product_url = $hashUrl{$_};
	print "$product_object_key -> $product_url\n";
	#&Walmart_US::Walmart_US_DetailProcess($product_object_key,$product_url,'Walmart-US--Worker',"597cc6fd67d142785c038f344273a0c12e8a38",$logger,"http://frawspcpx.cloud.trendinglines.co.uk:3129",$ua,$database,$images,$utility);
   # &Walmart_US::Walmart_US_DetailProcess('002412C699F3CD5DBFD6F23E168D6628','http://www.walmart.com/ip/21564546','Walmart-US--Worker',"597cc6fd67d142785c038f344273a0c12e8a38",$logger,"http://frawspcpx.cloud.trendinglines.co.uk:3129",$ua,$database,$images,$utility);
   # &Walmart_US::Walmart_US_DetailProcess('402B8FC052ADD5781FB13B6088996D49','http://www.walmart.com/ip/37622659','Walmart-US--Worker',"597cc6fd67d142785c038f344273a0c12e8a38",$logger,"http://frawspcpx.cloud.trendinglines.co.uk:3129",$ua,$database,$images,$utility);
   &Walmart_US::Walmart_US_DetailProcess('CFC11EE74F891FB3DF3DD2989176360B','http://www.walmart.com/ip/29680953','Walmart-US--Worker',"597cc6fd67d142785c038f344273a0c12e8a38",$logger,"http://frawspcpx.cloud.trendinglines.co.uk:3129",$ua,$database,$images,$utility);
	exit;
}
$database->disconnect();
