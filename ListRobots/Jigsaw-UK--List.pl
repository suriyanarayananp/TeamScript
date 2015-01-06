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
my $Retailer_Random_String='Jig';

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
my $home_url = 'http://www.jigsaw-online.com';
my $source_page = $utilityobject->Lwp_Get($home_url);

$source_page =~ s/(<li\s*class\=\"level_1[^>]*?\"\s*id\=\"wc_(?!explore)[^>]*?\">)/\^\$\^ $1/igs;
$source_page =~ s/(<li\s*id\=\"stores\"\s*class\=\"level_1\">)/\^\$\^ $1/igs;

# Extracts top menus excluding "explore" and "stores".
while($source_page =~ m/<li\s*class\=\"level_1[\w\W]*?id\=\"[\w\W]*?\">\s*<a\s*class\=\"level_1\"[\w\W]*?>((?!Explore)[^>]*?)<\/a>([\w\W]*?)\^\$\^/igs)
{
	my $top_menu = $utilityobject->Trim($1); # Women.
	my $top_menu_block = $2;

	# Entry for "new in" and "homeware" menus.
	if($top_menu =~ m/New\s*In|Homeware/is)
	{
		# Extracts menu 2/url from top menu block.
		while($top_menu_block =~ m/class\=\"level_2\"\s*href\=\"([^>]*?)\"[\w\W]*?>([^>]*?)<\/a>/igs)
		{
			my $menu_2_url = $1;
			my $menu_2 = $utilityobject->Trim($2); # New in women's.
			my $menu_2_page = $utilityobject->Lwp_Get($menu_2_url);
			&Product_Insert($menu_2_page,$top_menu,$menu_2); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation: new in -> new in women's).
			
			# Extracts filter block (excluding size and price).
			while($menu_2_page =~ m/<p\s*class\=\"filter_title\">\s*((?!\s*Size|\s*Price)[^>]*?)\s*<\/p>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs)
			{
				my $filter = $utilityobject->Trim($1); # Colour.
				my $filter_block = $2;

				# Extracts filter value and it's corresponding url.
				while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $filter_url = $1;
					my $filter_value = $utilityobject->Trim($2); # Green.
					my $filter_page = $utilityobject->Lwp_Get($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,'',$filter,$filter_value); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation: new in -> new in women's -> colour -> white).
				}
			}
		}				
	}
	else # Entry for "women", "men", "junior" and "sale" menus.
	{
		# Extracts menu 2 and menu 2 block from top menu block.
		while($top_menu_block =~ m/<span\s*class\=\"level_2\">\s*([^>]*?)\s*<\/span>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs)
		{
			my $menu_2 = $utilityobject->Trim($1); # Clothing.
			my $menu_2_block = $2;

			# Extracts menu 3/url from menu 2 block.
			while($menu_2_block =~ m/class="level_3"\s*href="([^>]*?)\"[\w\W]*?>([^>]*?)<\/a>/igs)
			{
				my $menu_3_url = $1;
				my $menu_3 = $utilityobject->Trim($2); # Dresses.
				my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation: women -> clothing -> dresses).

				# Extracts filter block (excluding size and price).
				while($menu_3_page =~ m/<p\s*class\=\"filter_title\">\s*((?!\s*Size|\s*Price|\s*Go\s*to)[^>]*?)\s*<\/p>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs)
				{
					my $filter = $utilityobject->Trim($1); # Colour.
					my $filter_block = $2;
					
					next if($filter =~ m/^\s*$/is);
					# Extracts filter value and it's corresponding url.
					while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $filter_url = $1;
						my $filter_value = $utilityobject->Trim($2); # Green.
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # Transports product_url, top_menu and menu_2 to product_insert module for inserting tags into db (navigation: women -> clothing -> dresses -> colour -> green).
					}
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
	my $filter = shift;
	my $filter_value = shift;

	# Pattern match of url from list page.
	while($page =~ m/href\=\"([^>]*?)\"\s*class\=\"product_link\"><img/igs)
	{
		my $product_url = $home_url.$1;
		my $unique = $1 if($product_url =~ m/\/products\/([^>]*?)\-\d+/is);
		$product_url =~ s/\s+//igs;
		my $product_object_key;
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$unique} eq '')
		{		
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);			
			$totalHash{$unique} = $product_object_key;
		}
		$product_object_key = $totalHash{$unique};
		
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

# Commit transaction.
$dbobject->commit();