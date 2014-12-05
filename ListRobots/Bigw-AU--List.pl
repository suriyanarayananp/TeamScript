#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl

# Required modules are initialized.
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings.
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Robotname is constructed from file name.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Big';

# Execution ID is formed by combining Process ID and IP address.
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Creating user agent (Mozilla Firefox).
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the configuration file.
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if(!defined $ini)
{
	# Die if reading the settings failed.
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog.
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

# Connect to AnorakDB package.
my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Connect to Utility package.
my $utilityobject = AnorakUtility->new($logger,$ua);

# Get Retailer_id & Proxy details.
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Set the proxy environment.
$utilityobject->SetEnv($ProxySetting);

# Saving start time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

$logger->send("$robotname :: Instance Started :: $pid\n");

# Retailer home page content.
my $home_url = 'http://www.bigw.com.au';
my $source_page = $utilityobject->Lwp_Get($home_url);

while($source_page =~ m/<a\s*title\=\"((?!electronic|toys|catalogues)[^\"]*?)\"\s*href\=\"([^\"]*?)\"\s*target\=\"_self\">/igs)
{
	my $top_menu = $utilityobject->Trim($1);
	my $top_menu_url = $2;
	$top_menu_url = $home_url.$top_menu_url unless($top_menu_url =~ m/^http/igs);
	my $top_menu_page = $utilityobject->Lwp_Get($top_menu_url);
	
	while($top_menu_page =~ m/<span>\s*([^<]*?)\s*\:\s*<\/span>\s*<\/li>\s*<li\s*class\=\"facet\-filters\">\s*<ul>\s*([\w\W]*?)<\/ul>/igs)
	{
		my $menu_2 = $utilityobject->Trim($1);
		my $menu_2_block = $2;

		while($menu_2_block =~ m/<a\s*href\=\"([^\"]*?)\">\s*([^<]*?)\s*<\/a>/igs)
		{
			my $menu_3_url = $1;
			my $menu_3 = $utilityobject->Trim($2);			
			$menu_3_url = $home_url.$menu_3_url unless($menu_3_url =~ m/^http/igs);

			next if(($top_menu eq 'Home & Gifts') and ($menu_3 ne 'Gift'));
			Top:
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);						
			
			my $flag = 0;
			while($menu_3_page =~ m/<span[^>]*?>\s*((?!size|price)[^<]*?)\s*<\/span>\s*<\/li>\s*<li\s*class\=\"clear\">[\w\W]*?<ul>([\w\W]*?)<\/ul>/igs)
			{
				my $filter_name = $utilityobject->Trim($1);
				my $filter_block = $2;

				while($filter_block =~ m/href\=\"([^\"]*?)\">\s*([^<]*?)\s*<\/a>/igs)
				{					
					my $filter_url = $1.'&dt=js&serveas=ajax';
					my $filter_value = $utilityobject->Trim($2);
					my $filter_page = $utilityobject->Lwp_Get($filter_url);
					$flag = 1;
					&Product_Insert($filter_url,$filter_page,$top_menu,$menu_2,$menu_3,$filter_name,$filter_value);
				}
			}
			if($flag == 0)
			{
				sleep(5);
				goto Top;
			}
		}
	}
}

# URL collections.
sub Product_Insert()
{
	my $filter_url = shift;
	my $page = shift;
	my $top_menu = shift;
	my $menu_2 = shift;
	my $menu_3 = shift;
	my $filter = shift;
	my $filter_value = shift;
	my $page_count = 1;

NextPage:
	# Pattern match of url from list page.
	while($page =~ m/<h3[^>]*?>\s*<a[^>]*?href\=\\\"([^\"]*?)\\\">/igs)
	{
		my $product_url = $1;
		my $product_object_key;
		$product_url = $home_url.$product_url unless($product_url =~ m/^http/igs);
		$product_url =~ s/\\\//\//igs;
		my $product_id = $1 if($product_url =~m/(\d+)\.htm/is);
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_id} eq '')
		{		
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);			
			$totalHash{$product_id} = $product_object_key;			
		}
		else
		{
			$product_object_key = $totalHash{$product_id};
		}
		
		# Storing menus into database.
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');	
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
	if($page =~ m/<li\s*class\=\\\"next\\\">/is)
	{
		$page_count++;
		my $next_page_url = $filter_url.'&page='.$page_count;
		$page = $utilityobject->Lwp_Get($next_page_url);
		goto NextPage;
	}
}

# End of List collection.

$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit transaction.
$dbobject->commit();