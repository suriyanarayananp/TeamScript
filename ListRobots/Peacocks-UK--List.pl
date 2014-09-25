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
my $Retailer_Random_String='Pea';

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
if (!defined $ini)
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
my $home_url = 'http://www.peacocks.co.uk';
my $source_page = $utilityobject->Lwp_Get($home_url);

# Pattern matches top menus, excluding "Trends".
while($source_page =~ m/<a\s*href\=\"[^>]*?\"\s*class\=\"level\-top\"\s*>\s*<span>\s*([^>]*?)\s*<\/span>\s*([\w\W]*?)\s*<\!\-\-\s*\/menu\s*\-\->/igs)
{
	my $top_menu = $utilityobject->Trim($1); # Top menu is stored. For example - Womens.
	my $top_menu_block = $2;
		
	# Entry for top menus, "New in" and "Sale".
	if($top_menu =~ m/New\s*in|Sale/is)
	{
		while($top_menu_block =~ m/<a\s*href\=\"([^>]*?)\"\s*>\s*<span>\s*([^>]*?)\s*<\/span>/igs)
		{
			my $menu_2_url = $1;
			my $menu_2 = $utilityobject->Trim($2); # New womens.			
			$menu_2_url = 'http://www.peacocks.co.uk'.$menu_2_url unless($menu_2_url =~ m/^http/is);
			
			my $no_filter_url = $menu_2_url;
			$no_filter_url = $1.'/where/limit/all'.$2 if($no_filter_url=~m/([^>]*?)(\.html)/is);
			my $no_filter_page = $utilityobject->Lwp_Get($no_filter_url); # Page shows full products for the categories without applying filters like colour.
			&Product_Insert($no_filter_page,$top_menu,$menu_2); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation example : menu_1(new in) -> menu_2(new womens)).
			undef $no_filter_page;			
			my $menu_2_page = $utilityobject->Lwp_Get($menu_2_url);
			
			# Fetching filter blocks excluding size, price, offer and gender.
			while($menu_2_page =~ m/<h4>\s*((?!price|size|offer|gender)[^>]*?)\s*<\/h4>([\w\W]*?)\s*<\/div>\s*<\/div>/igs)
			{				
				my $filter = $utilityobject->Trim($1); # Colour.
				my $filter_block = $2;			
				
				# Extracting filter values from each filter block.
				while($filter_block =~ m/setLocation\(\'([^>]*?)\'\)[^>]*?>\s*([^>]*?)\s*<span>/igs)
				{
					my $filter_url = $1;
					my $filter_value = $utilityobject->Trim($2); # Black.					
					
					$filter_url =~ s/where/where\/limit\/all/igs if($filter_url!~m/where\/limit\/all/is);
					my $filter_page = $utilityobject->Lwp_Get($filter_url); # Page shows full products after applying filters.
					&Product_Insert($filter_page,$top_menu,$menu_2,'',$filter,$filter_value); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation example : menu_1(new in) -> menu_2(new womens) -> (colour) -> (black)).
				}
			}
		}		
	}
	else # Entry for top menus : womens, mens, boys and girls.
	{
		while($top_menu_block =~ m/<h6>\s*<span>\s*([^>]*?)\s*<\/span>\s*<\/h6>([\w\W]*?)(?:<li\s*class\=\"level1[^>]*?>|<\!\-\-\s*\/cols\s*\-\->)/igs)
		{
			my $menu_2 = $utilityobject->Trim($1); # Shop department.
			my $menu_2_block = $2;			
			
			# Extracting menu 3/url from menu 2 block.
			while($menu_2_block =~ m/<a\s*href\=\"([^>]*?)\"\s*>\s*<span>\s*([^>]*?)\s*<\/span>/igs)
			{
				my $menu_3_url = $1;
				my $menu_3 = $utilityobject->Trim($2); # Dresses.
				my $no_filter_url = $menu_3_url;				
				
				$menu_3_url = 'http://www.peacocks.co.uk'.$menu_3_url unless($menu_3_url =~ m/^http/is);
				$no_filter_url = $1.'/where/limit/all'.$2 if($no_filter_url=~m/([^>]*?)(\.html)/is);
				my $no_filter_page = $utilityobject->Lwp_Get($no_filter_url); # Page shows full products for the categories without applying filters.
				&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation example : menu_1(new in) -> menu_2(shop department) -> menu_3(dresses)).
				undef $no_filter_page;
				
				my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
				
				# Fetching filter blocks excluding size, price, offer and gender.
				while($menu_3_page =~ m/<h4>\s*((?!price|size|offer|gender)[^>]*?)\s*<\/h4>([\w\W]*?)\s*<\/div>\s*<\/div>/igs)
				{
					my $filter = $utilityobject->Trim($1); # Colour
					my $filter_block = $2;
					
					# Extracting filter values from each filter block.
					while($filter_block =~ m/setLocation\(\'([^>]*?)\'\)[^>]*?>\s*([^>]*?)\s*<span>/igs)
					{
						my $filter_url = $1;
						my $filter_value = $utilityobject->Trim($2); # Black.
						
						$filter_url =~ s/where/where\/limit\/all/igs if($filter_url!~m/where\/limit\/all/is);
						my $filter_page = $utilityobject->Lwp_Get($filter_url); # Page shows full products after applying filters.
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation example : menu_1(new in) -> menu_2(shop department) -> menu_3(dresses) -> (colour) -> (black)).
					}					
				}
			}			
		}
	}
	undef $top_menu_block;
}
undef $source_page;

# URL collection.
sub Product_Insert()
{
	my $page = shift;
	my $top_menu = shift;
	my $menu_2 = shift;
	my $menu_3 = shift;
	my $filter = shift;
	my $filter_value = shift;
	
	# Pattern match of url from list page.	
	while($page =~ m/<a\s*href\=\"([^\"]*?)\"\s*title\=\"[^\"]*?\"\s*class\=\"product\-image\">/igs)
	{
		my $product_url = $1;
		my $product_object_key;
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_url} eq '')
		{			
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$totalHash{$product_url} = $product_object_key;
		}
		$product_object_key = $totalHash{$product_url}; # Using existing product_id if the hash table contains this url.
		
		# Storing menus into database.
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');	
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
}

# End of List collection.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit the Transaction.
$dbobject->commit();