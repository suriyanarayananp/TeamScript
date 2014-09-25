#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Variable Initialization
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Off';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;

# User Agent
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the config file
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) {
	# Die if reading the settings failed
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Conect to Utility package
my $utilityobject = AnorakUtility->new($logger,$ua);

# Getting Retailer_id & Proxy
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment
$utilityobject->SetEnv($ProxySetting);

# Sending the retailer starting information to dashboard
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Sending retailer starting information to logger 
$logger->send("$robotname :: Instance Started :: $pid\n");

my $url='http://www.office.co.uk/';
my $content = $utilityobject->Lwp_Get($url);

# Extraction of the Menu1 URL, Menu1 Name, Menu1 block
while($content=~m/<li\s*class\=\"parent\s*\">\s*<a\s*href\=\"([^>]*?)\">\s*(?:<[^>]*?>)?([^>]*?)\s*(?:<\/span>)?\s*<\/a>(?:\s*<div>([\W\w]*?)<\/ul><\/div>\s*<\/li>)/igs)
{
	my $Menu1_URL=$1;
	my $Menu1=$2;
	my $Menu1_block=$3;
	
	# Skipping the Menu1
	next if($Menu1=~m/Trainers|BRAND|Blog|Sale/is);
	
	# Skipping the Menu1 # testing
	#next if($Menu1=~m/Trainers|BRAND|Blog|Sale|HIS|KIDS/is);
	
	# Framing the URL
	unless($Menu1_URL=~m/^\s*http\:/is)
	{
		$Menu1_URL='http://www.office.co.uk/'.$Menu1_URL;
	}
	print "MENU1:: $Menu1 :: MENU 1 URL:; $Menu1_URL \n";

	while($Menu1_block=~m/<li\s*class\=\"child\">\s*<div\s*class\=\"header\">([^>]*?)<\/div>([\w\W]*?)<\/ul>\s*<\/li>/igs)
	{
		my $menu2=$utilityobject->Decode($1);
		my $menu2_block=$2;
		print "menu2 :: $menu2\n";
		
		# Skipping the Brand section to avoid unwanted rotation without any new data
		next if($menu2=~m/BRAND/is);
		
		my $menu3_header;
		###while($menu2_block=~m/<li\s*class\=\"grandchild([^>]*?)\">\s*<a\s*href\=\"([^>]*?)\">\s*(?:<[^>]*?>)?([^>]*?)(?:<\/strong>)?\s*<\/a>\s*<\/li>/igs)
		while($menu2_block=~m/<li\s*class\=\"grandchild([^>]*?)\">\s*(?:<strong>)?\s*<a\s*href\=\"([^>]*?)\">\s*(?:<[^>]*?>)?([^>]*?)(<\/strong>)?\s*<\/a>\s*(?:<\/strong>)?<\/li>/igs)
		{
			my $check_value=$1.$4;
			my $menu3_URL=$2;
			my $menu3=$3;
			$check_value=~s/\s+//igs;
			$menu3=~s/\&pound\;/£/igs;
				
			# Skipping the Menu if View all
			#next if (($check_value!~m/^\s*$/is) && ($menu3=~m/View\s*All/is));
			next if($menu3=~m/View\s*All|all\s*brand/is);					
			
			# site Issue / all products displaying
			next if($menu3=~m/Flats|AW14\s*style|Jelly\s*Shoes/is);
			
			next if($menu3=~m/^\s*$/is);
			
			next if($menu3 eq '');
			
			# If the check flag value is available, then it is Header
			if($check_value!~m/^\s*$/is)
			{
				$menu3_header=$menu3;
				$menu3='';
				print "menu3 header after assigned :: $menu3_header\n";
				##next;
			}
			
			# Framing the URL
			unless($menu3_URL=~m/^\s*http\:/is)
			{
				$menu3_URL='http://www.office.co.uk'.$menu3_URL;
			}
			
			print "MENU 3 URL:: $menu3_URL \n";
			
			# Setting the URL to fetch 100 products per page
			if($menu3_URL=~m/\?/is)
			{
				$menu3_URL=$menu3_URL.'&pageSize=100';
			}
			else
			{
				$menu3_URL=$menu3_URL.'?pageSize=100';
			}
			print "MENU 3 URL with page size:: $menu3_URL \n";
			
			my $next_page=$menu3_URL;
			my $domain_url;
			if($menu3_URL=~m/^([^>]*?)\?[^>]*?$/is)
			{
				$domain_url=$1;				
			}
			else
			{
				$domain_url=$menu3_URL;
			}
			
			pagination:
			# Fetching the URL content
			my $page_content =$utilityobject->Lwp_Get($next_page);
			
			# Product collection
			while($page_content=~m/<div\s*class\=\"productList_item\">\s*<div[^>]*?>\s*<a\s*class\=\"displayBlock\s*brand\"\s*href\=\"([^>]*?)\">/igs)
			{
				my $product_url='http://www.office.co.uk'.$1;
				
				# To insert product URL into table on checking the product is not available already
				my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				
				# Saving the tag information.
				$dbobject->SaveTag('Menu_1',$Menu1,$product_object_key,$robotname,$Retailer_Random_String) if($Menu1!~m/^\s*$/is);
				$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2!~m/^\s*$/is);
				$dbobject->SaveTag('Menu_3',$menu3_header,$product_object_key,$robotname,$Retailer_Random_String) if(($menu3_header!~m/^\s*$/is) && ($menu3_header ne ''));
				if(($menu3 ne '')&&($menu3!~m/^\s*$/is))
				{
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if(($menu3!~m/^\s*$/is) && ($menu3_header=~m/^\s*$/is) && ($menu3 ne ''));
				}
				$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if(($menu3!~m/^\s*$/is) && ($menu3_header!~m/^\s*$/is) && ($menu3 ne ''));
				
				# Committing the transaction.
				$dbobject->commit();				
			}
			
			# Page navigation
			if($page_content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"pagination_[^>]*?\">\s*Next\s*<\/a>/is)
			{
				$next_page=$domain_url.$1;
				
				# Framing the URL
				unless($next_page=~m/^\s*http\:/is)
				{
					$next_page=$domain_url.$next_page;
				}
				print "pagination:; $next_page\n";
				goto pagination;
			}
			
			# Filter navigation
			while($page_content=~m/<span\s*class\=\"categoryTree_bold\s*active\"\s*id\=\"[^>]*?_facetValues\"\s*name\=\"filter\">\s*<[^>]*?>\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>\s*(?:<a[^>]*?>[^>]*?<\/a>\s*)?<\/li>/igs)
			{
				my $filter_header=$utilityobject->Decode($1);
				my $filter_block=$2;

				# Skipping the Shop by filter
				next if($filter_header=~m/Shop\s*by|Size|price/is);
				
				while($filter_block=~m/<a\s*href\=\"([^>]*?)\"\s*[^>]*?>\s*<span\s*class\=\"facetNameVal\">([^>]*?)<\/span>\s*<span\s*class\=\"facetVal\">[^>]*?<\/span>\s*<\/a>/igs)
				{
					my $filter_url=$1;
					my $filter_name=$2;
					
					# Framing the URL
					unless($filter_url=~m/^\s*http\:/is)
					{
						$filter_url=$domain_url.$filter_url;
					}
					
					print "Filter URL:: $filter_url\n";
					$next_page=$filter_url;
					
					# Filter page navigation
					pagination1:
					# Fetching the URL content
					my $page_content =$utilityobject->Lwp_Get($next_page);
					
					# Product collection
					while($page_content=~m/<div\s*class\=\"productList_item\">\s*<div[^>]*?>\s*<a\s*class\=\"displayBlock\s*brand\"\s*href\=\"([^>]*?)\">/igs)
					{
						my $product_url='http://www.office.co.uk'.$1;
						
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						# Saving the tag information.
						$dbobject->SaveTag('Menu_1',$Menu1,$product_object_key,$robotname,$Retailer_Random_String) if($Menu1!~m/^\s*$/is);
						$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2!~m/^\s*$/is);
						$dbobject->SaveTag('Menu_3',$menu3_header,$product_object_key,$robotname,$Retailer_Random_String) if($menu3_header ne '');
						$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if(($menu3!~m/^\s*$/is) && ($menu3_header=~m/^\s*$/is));
						$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if(($menu3!~m/^\s*$/is) && ($menu3_header!~m/^\s*$/is));
						$dbobject->SaveTag($filter_header,$filter_name,$product_object_key,$robotname,$Retailer_Random_String) if($filter_name!~m/^\s*$/is);
						
						# Committing the transaction.
						$dbobject->commit();				
					}
					
					# Page navigation
					if($page_content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"pagination_[^>]*?\">\s*Next\s*<\/a>/is)
					{
						$next_page=$domain_url.$1;
						
						# Framing the URL
						unless($next_page=~m/^\s*http\:/is)
						{
							$next_page=$domain_url.$next_page;
						}
						print "pagination1:: $next_page\n";
						goto pagination1;
					}
				}
			}
		}
	}	
}

# Sending retailer completion information to dashboard
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Sending instance completion information to logger
$logger->send("$robotname :: Instance Completed  :: $pid\n");	

# Committing all the transaction.
$dbobject->commit();

# Disconnecting all DB objects
$dbobject->disconnect();

# Destroying all DB objects
$dbobject->Destroy();