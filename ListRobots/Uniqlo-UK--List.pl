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
my $Retailer_Random_String='Uni';

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
my $home_url = 'http://www.uniqlo.com/uk';
my $source_page = $utilityobject->Lwp_Get($home_url);

# Extracts top menus : women, men and kids.
while($source_page =~ m/<\!\-\-\s*start\s*(?:(?:wo)?men|kidsbabies)?\s*\/\/\s*\-\->\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*end\s*((?:(?:wo)?men|kidsbabies)?)\s*\-\->/igs)
{
	my $top_menu_block = $1;
	my $top_menu = $utilityobject->Trim($2); # Women.
	$top_menu =~ s/kidsbabies/kids & babies/igs;

	 # Extracts menu 2 block from top menu block.
	# while($top_menu_block =~ m/<a\s*href\=\"\#\">\s*<img\s*src\=\"[^>]*?\"\s*alt\=\"([^>]*?)\"[^>]*?>\s*<\/a>\s*<ul\s*class\=\"sub\s*hidden\">\s*([\w\W]*?)\s*<\/ul>\s*<\/li>/igs)
	while($top_menu_block =~ m/<img\s*src\=\"[^>]*?\"\s*alt\=\"([^>]*?)\"[^>]*?>\s*<\/a>\s*<ul\s*class\=\"sub\s*hidden\">\s*([\w\W]*?)\s*<\/ul>\s*<\/li>/igs)
	{
		my $menu_2 = $utilityobject->Trim($1); # Tops.
		my $menu_2_block = $2;
		
		# Extracts menu 3 and url from menu 2 block (skip menu 3 -> uniqlo app).
		while($menu_2_block =~ m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*((?!UNIQLO\s*app)[^>]*?)\s*<\/a>\s*<\/li>/igs)
		{
			my $menu_3_url = $1;
			my $menu_3 = $utilityobject->Trim($2); # Polo shirts.
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
			
			# Extracts the menu 3 page which contains "select by style" filter (navigation: women -> tops -> dresses & tunics -> select by style -> dresses).
			if($menu_3_page =~ m/<a\s*href\=\"\#[^>]*?\">\s*<img\s*alt\=\"[^>]*?\"\s*src\=\"[^>]*?\/[\w\-]*?\.jpg\">/is)
			{
				# Extracts style code and style value.
				while($menu_3_page =~ m/<a\s*href\=\"\#([^>]*?)\">\s*<img\s*alt\=\"[^>]*?\"\s*src\=\"[^>]*?\/([\w\-]*?)\.jpg\">/igs)
				{
					my $style_code = $1;
					my $style = $utilityobject->Trim($2); # Dresses.
					
					# Data cleansing.					
					$style =~ s/^[^>]*?type(_[^>]*?)$/$1/igs;
					$style =~ s/_W_//igs;
					$style =~ s/\-W_//igs;
					$style =~ s/_M_//igs;
					$style =~ s/innerwear_//igs;
					$style =~ s/_/ /igs;
					$style =~ s/^w\s//igs;
					$style =~ s/^m\s//igs;					
					$style =~ s/socks\-//igs;
					$style =~ s/standard/regular/igs;					
					$style = lc($style);					
					
					# Extracts style block by passing style code in regex.
					if($menu_3_page =~ m/<div\s*class\=\"contProd\">\s*<h3\s*id\=\"$style_code\"\s*class\=\"[^>]*?\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*(?:end\s*)?alias\s*\-\->/is)
					{
						my $style_block = $1;
						&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Select by style',$style); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: women -> tops -> dresses & tunics -> select by style -> dresses).
					}
					else
					{
						&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu, menu_2, menu_3 to product_insert module for inserting tags into db (navigation: women -> tops -> dresses & tunics).
					}
				}
			}
			elsif($menu_3_page =~ m/<a\s*href\=\"\#[^>]*?\"\s*title\=\"[^>]*?\">\s*[^>]*?\s*<\/a>/is) # Extracts the menu 3 page which contains category type (navigation: women -> accessories & underwear -> accessories -> category -> hats).
			{
				# Extracts style code and style value.
				while($menu_3_page =~ m/<a\s*href\=\"\#[^>]*?\"\s*title\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $style_code = $1;
					my $style = $utilityobject->Trim($2); # Hats.
					
					# Extracts style block by passing style code in regex.
					if($menu_3_page =~ m/<div\s*class\=\"unit\s*title\"\s*id\=\"$style_code\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/alias\s*\-\->/is)
					{
						my $style_block = $1;
						&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Category',$style); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: women -> accessories & underwear -> accessories -> category -> hats).
					}
				}
			}
			elsif($menu_3_page =~ m/<\!\-\-\s*[^>]*?\s*\-\->\s*<div\s*class\=\"contProd\">/is) # Extracts the menu 3 page which contains category type (navigation: women -> collection -> ultra light down -> category -> uld for women).
			{
				# Extracts style value and style block.
				while($menu_3_page =~ m/<\!\-\-\s*([^>]*?)\s*\-\->\s*<div\s*class\=\"contProd\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*end[^>]*?\s*\-\->/igs)
				{
					my $style = $1; # ULD for women.
					my $style_block = $2;
					
					# Data cleansing.					
					$style = 'Collaboration' if($style=~m/^\/\/\s*end/is);
					$style = 'Accessories' if($style=~m/^\s*Goods/is);
					$style = 'ULD For Women' if($style=~m/Women\'s\s*ULD/is);
					$style = 'ULD For Men' if($style=~m/Men\'s\s*ULD/is);				
					
					&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Category',$style); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: women -> collection -> ultra light down -> category -> uld for women).
				}
			}
			else # Extracts the menu 3 page where no categories are available (navigation: women -> outerwear -> coats & blazers).
			{
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu, menu_2 and menu_3 to product_insert module for inserting tags into db (navigation: women -> outerwear -> coats & blazers).
			}
		}
	}	
	
	# Extracts menu 2 : new in, limited offer and sale.
	while($top_menu_block =~ m/<li>\s*<a[^>]*?href\=\"([^>]*?)\">\s*<img[^>]*?alt\=\"([^>]*?)\"[^>]*?>\s*<\/a>\s*<\/li>/igs)
	{
		my $menu_2_url = $1;
		my $menu_2 = $utilityobject->Trim($2); # New in.
		my $menu_2_page = $utilityobject->Lwp_Get($menu_2_url);
		
		# Grouping menu 3 into a block.
		while($menu_2_page =~ m/<ul\s*id\=\"navSpecialCategory\">\s*([\w\W]*?)\s*<\/ul>/igs)
		{
			my $menu_2_block = $1;
			
			# Segments each menu 3 and it's url.
			while($menu_2_block =~ m/<a[^>]*?href\=\"([^>]*?\/((?!ut)[\w]*?))\">/igs)
			{
				my $menu_3_url = $1;
				my $menu_3 = $2; # Outerwear.
				$menu_3 =~ s/and/ \& /igs;
				my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # Transports product_url, top_menu, menu_2 and menu_3 to product_insert module for inserting tags into db (navigation: women -> new in -> outerwear).
			}
		}
	}
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
	while($page =~ m/<dt\s*class\=\"name\">\s*<a\s*href\=[\'|\"]([^>]*?)[\"|\']\s*[^>]*?>\s*[^>]*?\s*<\/a>\s*<\/dt>/igs)
	{
		my $product_url = $1;
		my $product_object_key;
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_url} eq '')
		{
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);			
			$totalHash{$product_url} = $product_object_key;
		}
		$product_object_key = $totalHash{$product_url};
		
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