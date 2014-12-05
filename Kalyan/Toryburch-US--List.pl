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

# Variable Initialization.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Tor';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %hash_id;
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

# Getting home page content.
###my $content = $utilityobject->Lwp_Get("http://www.toryburch.com/");
my $content = $utilityobject->Lwp_Get("http://www.toryburch.com/on/demandware.store/Sites-ToryBurch_US-Site/default/Default-Start?campid=int_us");

############ URL Collection ##############
# Pattern match to take Top menu & it's block.
if($content=~m/<li\s*class\=\"$ARGV[0]\">\s*([\w\W]*?)(?:<li\s*class\=\"categorymenudivider\">|<\/div>\s*<\/li>\s*<\/ul>)/is)
{
	my $menu1 = lc($ARGV[0]);
	my $block1 = $1;
	
	next if($menu1 =~ m/musthaves|beauty|home|Tory\s*daily/is);
	
	##$menu1 = "TORY'S MUST-HAVES" if($menu1 =~ m/musthaves/is);
	
	if($block1 =~ m/class\=\"group\-hdr\">\s*([^>]*?)\s*<([\w\W]*?)<\/ul>/is)
	{
		while($block1 =~ m/class\=\"group\-hdr\">\s*([^>]*?)\s*<([\w\W]*?)<\/ul>/igs)
		{
			my $menu2 = lc($1);
			my $block2 = $2;
			
			next if($menu2 =~ m/Shops/is);
			
			while($block2 =~ m/href\s*\=\s*\"\s*([^>]*?)\s*\"\s*[^>]*?>\s*([^<]*?)\s*</igs)
			{
				my $purl = $1;
				my $menu3 = $2;
				
				next if(($menu1!~m/Clothing/is)&&($menu3=~m/Workweek\s*chic/is));
				#next if($menu3=~m/View\s*all/is);
				
				my $pcontent = $utilityobject->Lwp_Get($purl);
				
				# Looping through to get the filter header and it's block.
				while($pcontent=~m/navgroup\s*refinement\s*\"[^>]*?>\s*<h3[^>]*?>((?!Size)[^<]*?)<([\w\W]*?)<\!\s*\-\s*\-\s*END\s*\:\s*refineattributes\s*\-\s*\-\s*>/igs)
				{
					my $filter_header = $1;			# Color
					my $filter_block = $2;  

					# Looping through to get the filter url and it's value.
					while($filter_block =~ m/href\s*\=\s*\"\s*([^>]*?)\s*\"\s*[^>]*?>\s*([^<]*?)\s*</igs)
					{
						my $filter_url = $1;   
						my $filter_value = $2; # Red, Green , Blue..,

						$filter_url=~s/amp;//igs;

						&collect_product($menu1,$menu2,$menu3,$filter_header,$filter_value,$filter_url); # Function call to collect product urls.
					}
				}
			}
		}
	}
	elsif($block1 =~ m/href\s*\=\s*\"\s*([^>]*?)\s*\"\s*[^>]*?>\s*([^<]*?)\s*</is)
	{
		&collect_product($menu1,'','','','',$1); # Function call to collect product urls.
	}
}

$logger->send("$robotname :: Instance Completed  :: $pid\n");
################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################
$dbobject->commit();


# Function definition to get product urls.
sub collect_product()
{	
	my $menu_11=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $filter_header_1=shift;
	my $filter_value_1=shift;
	my $product_collection_url=shift;
	
	print "menu: $menu_11\t$menu_22\t$menu_33\t$filter_header_1\t$filter_value_1\n";
	
	$product_collection_url=~s/\#//igs;
	
	my $collection_Page_conetnt=$utilityobject->Lwp_Get($product_collection_url);
	
	# Pattern match to check whether page size available in java script.
	if($collection_Page_conetnt=~m/current\s*\=\s*\'\s*\+\s*([^<]*?)\s*\+\s*\'\s*pageSize\s*\=\s*\'\s*\+\s*([^<]*?)\s*\+/is)
	{
		my $product_collection_url_ajax;
		
		# Pattern match to check whether category url having character "?" to append "&" character to get the correct product page content.
		if($product_collection_url=~m/\?/is)
		{
			$product_collection_url_ajax="$product_collection_url&start=$1&format=ajax&sz=$2";
		}
		else # To append "?" character to get the correct product page content.
		{
			$product_collection_url_ajax="$product_collection_url?start=$1&format=ajax&sz=$2";
		}
	
NextPage:
		if($product_collection_url_ajax eq '')
		{
			$product_collection_url_ajax='$product_collection_url';
		}
				
		my $collection_Page_conetnt=$utilityobject->Lwp_Get($product_collection_url_ajax);
	
		my $count=0;	
	
		# Looping through to collect product urls.
		while($collection_Page_conetnt=~m/<div[^>]*?class\s*\=\s*\"\s*name\s*\"[^>]*?>\s*<a[^>]*? href\s*\=\s*\"([^<]*?\.html)[^<]*?\"[^>]*?>/igs)
		{
			my $prod_url=$1;
			$count++;

			my $product_object_key;
			# my $prod_id=$1 if($prod_url=~m/\/([^\/]*?)\.html/is);
			
			if($hash_id{$prod_url} eq '')
			{
				$product_object_key = $dbobject->SaveProduct($prod_url,$robotname,$retailer_id,$Retailer_Random_String);
				$hash_id{$prod_url}=$product_object_key;
			}
			$product_object_key=$hash_id{$prod_url};
			
			# Insert Tag values.
			$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String) if($menu_11 ne '');
			
			unless($menu_22=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_33=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_3',$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($filter_header_1=~m/^\s*$/is)
			{
				$dbobject->SaveTag($filter_header_1,$filter_value_1,$product_object_key,$robotname,$Retailer_Random_String) if($filter_value_1 ne '');
			}
			# Committing the transaction.
			$dbobject->commit();
		}
		print "Product count: $count\n";
		
		# Pattern match to get url for the next page.
		if($collection_Page_conetnt=~m/thePageURL\s*\=\s*(?:\'|\")([^<]*?ajax[^<]*?)(?:\'|\")/is)
		{
			$product_collection_url_ajax=$1;
			goto NextPage;
		}
	}
	else
	{
		# Looping through to collect product urls.
		my $collection_Page_conetnt=$utilityobject->Lwp_Get($product_collection_url);
		my $count=0;
		while($collection_Page_conetnt=~m/<div[^>]*?class\s*\=\s*\"\s*name\s*\"[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^<]*?\.html)[^<]*?\"[^>]*?>/igs)
		{
			my $prod_url=$1;
			$count++;
			
			my $product_object_key;
			# my $prod_id=$1 if($prod_url=~m/\/([^\/]*?)\.html/is);
			
			if($hash_id{$prod_url} eq '')
			{
				$product_object_key = $dbobject->SaveProduct($prod_url,$robotname,$retailer_id,$Retailer_Random_String);
				$hash_id{$prod_url}=$product_object_key;
			}
			$product_object_key=$hash_id{$prod_url};
			
			# Insert Tag values.
			$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String) if($menu_11 ne '');
			
			unless($menu_22=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_33=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_3',$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($filter_header_1=~m/^\s*$/is)
			{
				$dbobject->SaveTag($filter_header_1,$filter_value_1,$product_object_key,$robotname,$Retailer_Random_String);
			}
			# Committing the transaction.
			$dbobject->commit();
		}
	}
}
