#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;

# Package Initialization.
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings.
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Variables Initialization.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Mim';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Setting the UserAgent.
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the config file.
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) 
{
	# Die if reading the settings failed.
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog.
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

# Connect to AnorakDB Package.
my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Connect to Utility package.
my $utilityobject = AnorakUtility->new($logger,$ua);

# Getting Retailer_id and Proxystring.
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Getting the content from the home page.
my $content = $utilityobject->Lwp_Get("http://www.mimco.com.au/");
my %hash_id;

# Looping through to get top menu and it's url.
while($content=~m/<h2[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>([^>]*?)</igs)
{
	my $menu_1_url=$1;
	my $menu_1=$utilityobject->Trim($2);
	
	next if($menu_1=~m/MIMCO\s*SOUL/is);
	
	&get_product_urls($menu_1_url,$menu_1,'','','',''); # Function call to get all product urls with their corresponding arguments.
	
	$menu_1_url="http://www.mimco.com.au/".$menu_1_url if($menu_1_url!~m/^http/is);
	
	my $content = $utilityobject->Lwp_Get($menu_1_url); # Function call to get Product Page's Content.	
	
	$content=~s/<ul>\s*<\/ul>//igs; # To exclude taking block wrongly which has no content.
	
	# Pattern match to check whether category block availabe.
	if($content=~m/>\s*(?!Price\s*Range|Size)\s*(Category)<([\w\W]*?)<\/ul>\s*<\/section>/is)
	{
		my $menu_2_header=$1;
		my $menu_2_block=$&;
		
		# Looping through to navigate through next sub-menu and it's url.
		while($menu_2_block=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>([^>]*?)<\/a>(?:(?:\s*<[^>]*?>\s*)*\s*<ul[^>]*?>[\w\W]*?<\/ul>)?/igs)
		{	
			my $menu_2_url=$1;
			my $menu_2= $utilityobject->Trim($2);
			
			next if($menu_2=~m/(?:HEADPHONES|BEAUTY\s*AND\s*HOME)/is);
			
			$menu_2_url="http://www.mimco.com.au/".$menu_2_url if($menu_2_url!~m/^http/is);
			
			&get_product_urls($menu_2_url,$menu_1,$menu_2_header,$menu_2,'','');  # Function call to get all product urls from the navigated url.
			
			my $content = $utilityobject->Lwp_Get($menu_2_url); # Function call to get Product Page's Content.	
			
			$content=~s/<ul>\s*<\/ul>//igs; # To exclude taking block wrongly which has no content.
			
			my $menu_2_q=quotemeta($menu_2);
			
			# Pattern match to get next navigation sub-block.
			if($content=~m/<li[^>]*?class\s*\=\s*\"\s*on\s*\"[^>]*?>(?:\s*<[^>]*?>\s*)*\s*$menu_2_q\s*<[^>]*?>\s*<ul[^>]*?>([\w\W]*?)<\/ul>/is)
			{
				my $menu_3_main_block=$1;
				
				# Looping through to navigate through next sub-menu and it's url.
				while($menu_3_main_block=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>([^>]*?)</igs)
				{
					my $menu_3_url=$1;
					my $menu_3=$utilityobject->Trim($2);
					
					&get_product_urls($menu_3_url,$menu_1,$menu_2_header,$menu_2,$menu_3,''); # Function call to get all product urls with their corresponding arguments.
					
					my $menu_3_q=quotemeta($menu_3);
					
					my $content = $utilityobject->Lwp_Get($menu_3_url); # Function call to get Product Page's Content.
					
					$content=~s/<ul>\s*<\/ul>//igs; # To exclude taking block wrongly which has no content.
					
					# Pattern match to get next navigation sub-block.
					if($content=~m/<li[^>]*?class\s*\=\s*\"\s*on\s*\"[^>]*?>(?:\s*<[^>]*?>\s*)*\s*$menu_3_q\s*<[^>]*?>\s*<ul[^>]*?>([\w\W]*?)<\/ul>/is)
					{
						my $menu_4_main_block=$1;
						
						# Looping through to navigate through next sub-menu and it's url.
						while($menu_4_main_block=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>([^>]*?)</igs)
						{
							my $menu_4_url=$1;
							my $menu_4=$utilityobject->Trim($2);
							
							&get_product_urls($menu_4_url,$menu_1,$menu_2_header,$menu_2,$menu_3,$menu_4);# Function call to get all product urls with their corresponding arguments.
						}
					}
				}
			}
		}
	}
}
					
sub get_product_urls() #Function definition to catch all product urls. 
{
	my $products_collection_url=shift;
	my $menu_11=shift;
	my $menu_22_header=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $menu_44=shift;

Next:	
	my $content = $utilityobject->Lwp_Get($products_collection_url);
	
	# Looping through to get product urls.
	while($content=~m/<a[^>]*?class="product_link"[^>]*? href\s*\=\s*\"([^>]*?)\"[^>]*?>/igs)
	{
		my $product_url=$utilityobject->Trim($1);
		
		my ($product_id,$product_object_key);
		
		# Pattern match to get product id.
		if($product_url=~m/(\d{3,}\s*\-\s*\d+)/is)
		{
			$product_id=$1;
		}
		
		# Pattern match to check whether product id available in the hash saved,if not save product detail in product table.
		if($hash_id{$product_id} eq '')
		{
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$hash_id{$product_id}=$product_object_key;
		}
		$product_object_key=$hash_id{$product_id}; #  Save product id in the hash to remove duplicate urls by their ids.
		
		# Save the tag information of menu 1.
		$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
		
		# Save the tag information of menu 2.
		unless($menu_22 eq '')
		{
			$dbobject->SaveTag($menu_22_header,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		# Save the tag information of menu 3,if not empty.
		unless($menu_33 eq '')
		{
			$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		# Save the tag information of menu 4,if not empty.
		unless($menu_44 eq '')
		{
			$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		# Committing the transaction.
		$dbobject->commit();	
	}
	
	# Pattern match to check whether next page available.
	if($content=~m/<a[^>]*?class\s*\=\s*\"\s*next\s*\"[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>/is)
	{
		$products_collection_url=$1;
		goto Next;
	}
}

# Sending information to logger that all the instaces completed.
$logger->send("$robotname :: Instance Completed  :: $pid\n");
# For Dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
# For Dashboard.
$dbobject->commit();