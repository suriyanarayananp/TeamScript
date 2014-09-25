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
my $Retailer_Random_String='Mat';

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
my $home_url = 'http://www.matalan.co.uk';
my $source_page = $utilityobject->Lwp_Get($home_url);

# Extracting top menu/url -> womens, mens, boys, girls, shoes,homeware and sale.
# while($source_page =~ m/dept\-((?!home\b|style|in|reward|sport)[^>]*?)\">\s*<a\s*class\=\"\s*link\"\s*href\=\"([^>]*?)\"/igs)
while($source_page =~ m/<nav\s*id\=\"dept\-((?!home\b|style|in|reward|sport|life)[^\"]*?)\"\s*class\=\"drop\-nav\">\s*([\w\W]*?)\s*<\/nav>/igs)
{
	my $top_menu = $utilityobject->Trim($1); # Women.
	my $top_menu_page = $2;
	# my $top_menu_url = $home_url.$2;	
	# my $top_menu_page = $utilityobject->Lwp_Get($top_menu_url);
	
	# LHM full block.
	# if($top_menu_page =~ m/<nav\s*id\=\"section\-nav\">\s*([\w\W]*?)\s*<\/nav>/is)
	# {
		# my $menu_block = $1;		
		
		# LHM -> extracting separate blocks for each menu_2.
		# while($menu_block =~ m/<h4>\s*<span\s*class\=\"\s*link\">\s*([^>]*?)\s*<\/span>\s*<\/h4>\s*([\w\W]*?)\s*<\/ul>/igs)
		while($top_menu_page =~ m/<h4>\s*<span\s*class\=\"\s*link\">\s*([^>]*?)\s*<\/span>\s*<\/h4>\s*([\w\W]*?)\s*<\/ul>/igs)
		{
			my $menu_2 = $utilityobject->Trim($1); # Women's Highlights
			my $menu_2_block = $2;
			
			# LHM -> extracting menu_3/url from each menu_2 block
			while($menu_2_block =~ m/<a\s*class\=\"\s*link\"\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>/igs)
			{
				my $menu_3_url = $home_url.$1;
				my $menu_3 = $utilityobject->Trim($2); # New arrivals.
				my $part_filter_url = $menu_3_url;				
				$menu_3_url = $menu_3_url.'?size=120&page=1'; # Displays 120(maximum) products per page.
				my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
				&Product_Insert($menu_3_url,$menu_3_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu, menu_2 and menu_3 to product_insert module for inserting tags into db (navigation example : menu_1(women) -> menu_2(women's highlights) -> menu_3(new arrivals)).
				
				# Filter block - excluding filters : size, price and rating.
				while($menu_3_page =~ m/<h5>\s*<span[^>]*?>\s*<\/span>\s*((?!\s*size|\s*price|\s*rating)[^>]*?)\s*<\/h5>\s*([\w\W]*?)\s*<\/ul>/igs)
				{
					my $filter = $utilityobject->Trim($1); # Color
					my $filter_block = $2;
					
					# Extracting filter values from each filter block excluding colour.
					while($filter_block =~ m/<input\s*type\s*[^>]*?name=\"([^>]*>?)\"\s*value\=\"([^>]*>?)\"/igs)
					{
						my $part_name = $1;
						my $filter_value = $utilityobject->Trim($2); # White
						my $filter_url = $part_filter_url.'?'.$part_name.'='.$filter_value.'&size=120&page=1'; # Constructing filter url to extract product urls from display page (120 url per page).
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_url,$filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter_name and filter_value to product_insert module for inserting tags into db (navigation example : menu_1(women) -> menu_2(women's highlights) -> menu_3(new arrivals) -> (color) -> (white)).
						undef $filter_page;
					}
					
					# Extracting filter values for colour block.
					while($filter_block =~ m/<input\s*type\=\"checkbox\"\s*value\=\"([^>]*?)\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*\/>/igs)
					{
						my $filter_value = $utilityobject->Trim($1); # White.
						my $part_name = $2;
						my $filter_url = $part_filter_url.'?'.$part_name.'='.$filter_value.'&size=120&page=1'; # Constructing filter url to extract product urls from display page (120 url per page).
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_url,$filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter_name and filter_value to product_insert module for inserting tags into db (navigation example : mENU_1(women) -> mENU_2(women's highlights) -> mENU_3(new arrivals) -> (color) -> (white)).
						undef $filter_page;
					}
				}
				undef $menu_3_page;
			}
			undef $menu_2_block;
		}
	# }
}
undef $source_page;

# URL collection.
sub Product_Insert()
{
	my $url = shift;
	my $page = shift;
	my $top_menu = shift;
	my $menu_2 = shift;
	my $menu_3 = shift;
	my $filter = shift;
	my $filter_value = shift;
	
	my $page_count = 1;
	nextPage:
	# Pattern match of url from list page.
	while($page =~ m/<h3>\s*<a\s*class\=\"link\"\s*href\=\"([^>]*?)"[^>]*?>\s*[^>]*?\s*<\/a>/igs)
	{
		my $product_url = $1;
		$product_url = $home_url.$1 if($product_url =~ m/(\/s\d+)\//is); # CONSTRUCTING UNIQLE PRODUCT URL
		my $product_object_key;
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_url} eq '')
		{
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);			
			$totalHash{$product_url} = $product_object_key;
		}
		$product_object_key = $totalHash{$product_url};
		$filter_value =~ s/_/ /igs;
		
		# Storing menus into database.		
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if(($menu_2 !~ m/sale/is) && ($menu_2 ne ''));
		$dbobject->SaveTag('Menu_2',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 =~ m/sale/is);
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if(($menu_3 !~ m/\s+sale/is) && ($menu_3 ne ''));
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
	
	# Next page navigation.
	if($page =~ m/<li\s*class\=\"next\">/is)
	{
		$page_count++;
		$url = $1.$page_count if($url =~ m/([^>]*?\&page\=)/is);
		$page = $utilityobject->Lwp_Get($url);
		goto nextPage;
	}
}

# End of List collection.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit the Transaction.
$dbobject->commit();