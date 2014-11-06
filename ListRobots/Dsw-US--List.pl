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
my $Retailer_Random_String='DSW';

# Execution ID is formed by combining Process ID and IP address.
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Creating user agent (Mozilla Firefox).
my $ua = LWP::UserAgent->new(show_progress=>1);
# $ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->agent('WGSN;+44 207 516 5099;datacollection@wgsn.com');
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
my $home_url = 'http://www.dsw.com';
my $source_page = $utilityobject->Lwp_Get($home_url);

# Pattern match of top menu and top menu url.
# Excluded top menus are luxury, brand and clearance.
while($source_page =~ m/primaryNavLink\"\s*href\=\"([^\"]*?)\">((?!luxury|brands|clearance)[^<]*?)</igs)
{
	my $top_menu_url = $home_url.$1;
	my $top_menu = $2; # Women.
	my $top_menu_page = $utilityobject->Lwp_Get($top_menu_url);
	
	while($top_menu_page =~ m/javascript\:void\(0\)\;\">([^<]*?)<([\w\W]*?)(?:<span\s*class\=\"no\-click\">|<\/div>)/igs)
	{
		my $menu_2 = $1; # Shop by category.
		my $menu_2_block = $2;
		$menu_2_block =~ s/(<ul\s*>[\w\W]*?<\/ul>)//igs; # removing sub categories from menu 2 block to avoid irrelevant tag issue.
		
		while($menu_2_block =~ m/<li\s*[^>]*?>\s*<span>\s*<a\s*href\=\"([^\"]*?)\"\s*class\=\"[^\"]*?\">\s*([^<]*?)\s*</igs)
		{			
			my $menu_3_url = $home_url.$1.'?view=all';
			my $menu_3 = $2; # Boots.
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
			
			# Entry if Menu 3 has sub categories.
			if($menu_3_page =~ m/>\s*$menu_3\s*<\/a>\s*<\/span>\s*(<ul\s*>[\w\W]*?<\/ul>)/is)
			{
				my $menu_3_block = $1;
				while($menu_3_block =~ m/<li\s*[^>]*?>\s*<span>\s*<a\s*href\=\"([^\"]*?)\"\s*class\=\"[^\"]*?\">\s*([^<]*?)\s*</igs)
				{
					my $menu_4_url = $home_url.$1;
					my $menu_4 = $2; # Casual boots.
					$menu_4_url = $menu_4_url.'?view=all' unless ($menu_4_url =~ m/view\=all/igs);
					my $menu_4_page = $utilityobject->Lwp_Get($menu_4_url);
					
					# Pattern match of facet.
					while($menu_4_page =~ m/data\-name\=\"(color|heelHeight)\"[^>]*?>\s*<a[^>]*?>\s*<span\s*class\=\"icon\s*[^\"]*?\">\s*<\/span>\s*<label>([^<]*?)</igs)
					{
						my $filter_name = $1; # Color.
						my $filter_value = $2; # Black.
						my $filter_url = $menu_4_url.'&'.$filter_name.'='.$filter_value.'&last='.$filter_name.'&produces=json';
						$filter_url = $filter_url.'&view=all' unless ($filter_url =~ m/view\=all/igs);
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						$filter_name =~ s/heelHeight/Heel Height/igs;
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$filter_name,$filter_value);
					}
				}
			}
			else
			{
				# Pattern match of facet.
				while($menu_3_page =~ m/data\-name\=\"(color|heelHeight)\"[^>]*?>\s*<a[^>]*?>\s*<span\s*class\=\"icon\s*[^\"]*?\">\s*<\/span>\s*<label>([^<]*?)</igs)
				{
					my $filter_name = $1; # Color.
					my $filter_value = $2; # Black.
					my $filter_url = $menu_3_url.'&'.$filter_name.'='.$filter_value.'&last='.$filter_name.'&produces=json';
					$filter_url = $filter_url.'&view=all' unless ($filter_url =~ m/view\=all/igs);
					my $filter_page = $utilityobject->Lwp_Get($filter_url);
					$filter_name =~ s/heelHeight/Heel Height/igs;
					&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'',$filter_name,$filter_value);
				}
			}
		}
	}
}

# URL collections.
sub Product_Insert()
{
	my $page = shift;
	my $top_menu = shift;
	my $menu_2 = shift;
	my $menu_3 = shift;
	my $menu_4 = shift;
	my $filter = shift;
	my $filter_value = shift;

	# Pattern match of url from list page.
	while($page =~ m/productName\">\s*<a[^>]*?href\=\"([^>]*?)\&category\=[^\"]*?\">/igs)
	{
		my $product_url = $home_url.$1;
		my $product_object_key;
		my $product_id = $1 if($product_url =~ m/prodId\=([^<]*?)$/is); # Pattern match product id from product url.

		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_id} eq '')
		{		
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);			
			$totalHash{$product_id} = $product_object_key;
		}
		$product_object_key = $totalHash{$product_id};

		# Storing tag into database.
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');	
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
		$dbobject->SaveTag('Menu_4',$menu_4,$product_object_key,$robotname,$Retailer_Random_String) if($menu_4 ne '');
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
}

# End of List collection.

$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit transaction.
$dbobject->commit();