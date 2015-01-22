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
my $Retailer_Random_String='Wal';
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

# Getting arguments 
my $menu1 = $ARGV[0];
my $menu2 = $ARGV[1];
my $menu3 = $ARGV[2];
my $pgurl1 = $ARGV[3];

my $url = 'http://www.walmart.com';
# Making the URL absolute
$pgurl1 = $url.$pgurl1 unless($pgurl1 =~ m/^http/is);
my $cont2 = $utilityobject->Lwp_Get($pgurl1);

my $abspath = $1 if($cont2 =~ m/rel\=canonical\s*href\=\"([^>]*?)\"/is);
$abspath = "http://www.walmart.com".$abspath if($abspath !~ m/^http/is);

# Matching the filter content
if($cont2 =~ m/class\=(?:\")?expander\-toggle(?:\")?\s*href\=\"#\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/is)
{
	# Matching the filter and collecting the filter header and filter block
	while($cont2 =~ m/class\=(?:\")?expander\-toggle(?:\")?\s*href\=\"#\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
	{
		my $filterheader = $utilityobject->Decode($1);
		my $filterblock = $2;
		next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skipping few filters
		# Collecting the filters
		if($filterblock =~ m/href\=\"([^>]*?)\"[^>]*?data\-index\=\d+>\s*<span>\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is)
		{
			while($filterblock =~ m/href\=\"([^>]*?)\"[^>]*?data\-index\=\d+>\s*<span>\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
			{
				my $filterurl = $utilityobject->Decode($1.$3);
				my $filtervalue = $utilityobject->Decode($2.$4);
				
				if($filterheader =~ m/\bRetailer\b/is)
				{
					next unless($filtervalue=~ m/walmart/is);
				}
				my %nextpage;
				NextPage1:
				$filterurl =~ s/\s+//igs;
				if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
				{
					$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
				}
				else
				{
					$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
				}
				my $filtercont = $utilityobject->Lwp_Get($filterurl);
				
				# Collecting the Product URL ID for product URL
				while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=(?:\s*\")?([^>]*?)(?:\s*\")?\s*data-seller[^>]*?>/igs)
				{					
					my $pid = $utilityobject->Trim($1.$2);
					my $purl = "http://www.walmart.com/ip/$pid";
					$purl = $url.$purl unless($purl =~ m/^http/is);
					my $product_object_key;
					
					# Removing the duplicates with Hash ID
					if($hash_id{$pid} eq '')
					{
						$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
						$hash_id{$pid}=$product_object_key;
					}
					else
					{
						$product_object_key=$hash_id{$pid};
					}
					
					# Insert Tag values.
					$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
					$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
					unless($filterheader=~m/^\s*$/is)
					{
						$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
					}
					
					# Committing the transaction.
					$dbobject->commit();
				}
				
				# Next page naviagtion
				if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
				{
					$filterurl = $utilityobject->Decode($1.$2);
					if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
					{
						$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
					}
					else
					{
						$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
					}
					my $pageid;
					if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
					{
						$pageid = $1;
						$nextpage{$pageid}++;
					}
					# Routing/Diverting to Label
					goto NONextPage2 if($nextpage{$pageid}>1);
					goto NextPage1;
				}
				#Label point
				NONextPage2:
			}
		}
	}
}
elsif($cont2 =~ m/class\=(?:\")?expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/is)
{
	# Collecting the filters
	while($cont2 =~ m/class\=(?:\")?expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?<\/div>\s*)<\/div>/igs)  ## LH Filter Block
	{
		my $filterheader = $utilityobject->Decode($1);
		my $filterblock = $2;
		next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
		
		if($filterblock =~ m/href\=\"([^>]*?)\"[^>]*?data\-index\=\d+>\s*<span>\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\"[^>]*?data\-name[^>]*?>\s*([^>]*?)\s*<\/a>/is)
		{
			while($filterblock =~ m/href\=\"([^>]*?)\"[^>]*?data\-index\=\d+>\s*<span>\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\"[^>]*?data\-name[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
			{
				my $filterurl = $utilityobject->Decode($1.$3);
				my $filtervalue = $utilityobject->Decode($2.$4);
				if($filterheader =~ m/\bRetailer\b/is)
				{
					next unless($filtervalue=~ m/walmart/is);
				}
				my %nextpage;
				# Next page label point
				NextPage:
				$filterurl =~ s/\s+//igs;
				if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
				{
					$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
				}
				else
				{
					$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
				}
				my $filtercont = $utilityobject->Lwp_Get($filterurl);
				
				# Collecting the product ID to form Product URL
				while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=(?:\s*\")?([^>]*?)(?:\s*\")?\s*data-seller[^>]*?>/igs)
				{					
					my $pid = $utilityobject->Trim($1.$2);
					my $purl = "http://www.walmart.com/ip/$pid";
					$purl = $url.$purl unless($purl =~ m/^http/is);
					my $product_object_key;
					
					if($hash_id{$pid} eq '')
					{
						$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
						$hash_id{$pid}=$product_object_key;
					}
					else
					{
						$product_object_key=$hash_id{$pid};
					}
					
					# Insert Tag values.
					$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
					$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
					unless($filterheader=~m/^\s*$/is)
					{
						$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
					}
					
					# Committing the transaction.
					$dbobject->commit();
				}
				
				# Next page navigation
				if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
				{
					$filterurl = $utilityobject->Decode($1.$2);					
					if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
					{
						$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
					}
					else
					{
						$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
					}
					my $pageid;
					# collecting the page ID to form next page navigation URL
					if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
					{
						$pageid = $1;
						$nextpage{$pageid}++;
					}
					# Routing/ Diverting to Label
					goto NONextPage if($nextpage{$pageid}>1);
					goto NextPage;
				}
				# Label Point
				NONextPage:
			}
		}
	}
}
elsif($cont2=~ m/<li\s*class\=\"header\">([^>]*?)<\/li>([\w\W]*?)<\/ul>/is) # Exlusion of normal/regular flow 
{
	my $menu4_header=$1;
	my $menu4_block=$2;
	while($menu4_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
	{
		my $menu4_URL=$1;
		my $menu4=$2;
		my $cont2 = $utilityobject->Lwp_Get($menu4_URL);
		
		# Collecting the Left hand filters
		while($cont2 =~ m/class\=(?:\")?expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
		{
			my $filterheader = $utilityobject->Decode($1);
			my $filterblock = $2;
			
			# Skip this while Loop if the header matches the below headers
			next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
			
			# Collecting the Filter header and value
			while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
			{
				my $filterurl = $utilityobject->Decode($1.$3.$5);
				my $filtervalue = $utilityobject->Decode($2.$4.$6);
				# Skipping the Retailer filter other than Walmart.com
				if($filterheader =~ m/\bRetailer\b/is)
				{
					next unless($filtervalue=~ m/walmart/is);
				}
				my %nextpage;
				# Next page Label Point
				NextPage1:
				$filterurl =~ s/\s+//igs;
				if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
				{
					$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
				}
				else
				{
					$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
				}
				# Grabing the Source for Filter URL
				my $filtercont = $utilityobject->Lwp_Get($filterurl);
				
				# Collecting the PID for product URL  
				while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=(?:\s*\")?([^>]*?)(?:\s*\")?\s*data-seller[^>]*?>/igs)
				{					
					my $pid = $utilityobject->Trim($1.$2);
					my $purl = "http://www.walmart.com/ip/$pid";
					$purl = $url.$purl unless($purl =~ m/^http/is);
					my $product_object_key;
					
					# Mapping the hash to remove duplicates
					if($hash_id{$pid} eq '')
					{
						$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
						$hash_id{$pid}=$product_object_key;
					}
					else
					{
						$product_object_key=$hash_id{$pid};
					}
					
					# Insert Tag values.
					$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
					$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
					$dbobject->SaveTag($menu4_header,$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
					unless($filterheader=~m/^\s*$/is)
					{
						$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
					}
					
					# Committing the transaction.
					$dbobject->commit();
				}
				
				# Collection of filter URL
				if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
				{
					$filterurl = $utilityobject->Decode($1.$2);
					if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
					{
						$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
					}
					else
					{
						$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
					}
					my $pageid;
					
					# Collecting the Page ID for next page navigation
					if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
					{
						$pageid = $1;
						$nextpage{$pageid}++;
					}
					# Diverting to Next Page Label using goto function
					goto NONextPage1 if($nextpage{$pageid}>1);
					goto NextPage1;
				}
				# Label Point
				NONextPage1:
			}
		}
	}
}
else
{
	# Label Point
	WEDDING:
	# Collecting the Menu 4 / Filter header
	while($cont2 =~ m/class\=(?:\")?expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
	{
		my $menu4_header = $utilityobject->Decode($1);
		my $menu4_block = $2;
		next if($menu4_header =~ m/Department|rating|size|brand|price|save|Jewelry\s*Education/is);  #Skip few filters
		
		while($menu4_block=~m/href\=\"([^>]*?)\"[^>]*?>\s*<span>\s*([^>]*?)<\/span>/igs)
		{
			my $menu4_URL='http://www.walmart.com'.$1;
			my $menu4=$2;
			
			my $cont2 = $utilityobject->Lwp_Get($menu4_URL);
			# Collecting the Menu 4 / Filter header and filter block
			while($cont2 =~ m/class\=(?:\")?expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
			{
				my $filterheader = $utilityobject->Decode($1);
				my $filterblock = $2;
				next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
				# Collecting the Filter header and values
				while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $filterurl = $utilityobject->Decode($1.$3.$5);
					my $filtervalue = $utilityobject->Decode($2.$4.$6);
					
					if($filterheader =~ m/\bRetailer\b/is)
					{
						next unless($filtervalue=~ m/walmart/is);
					}
					my %nextpage;
					NextPage2:
					$filterurl =~ s/\s+//igs;
					if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
					{
						$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
					}
					else
					{
						$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
					}					
					my $filtercont = $utilityobject->Lwp_Get($filterurl);
					# Collecting the Product ID to form Product URL
					while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=(?:\s*\")?([^>]*?)(?:\s*\")?\s*data-seller[^>]*?>/igs)
					{
						my $pid = $utilityobject->Trim($1.$2);
						my $purl = "http://www.walmart.com/ip/$pid";
						$purl = $url.$purl unless($purl =~ m/^http/is);

						my $product_object_key;
						# Removing the duplicates using the Hash data structure
						if($hash_id{$pid} eq '')
						{
							$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
							$hash_id{$pid}=$product_object_key;
						}
						else
						{
							$product_object_key=$hash_id{$pid};
						}
						
						# Insert Tag values.
						$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
						$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
						$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
						$dbobject->SaveTag($menu4_header,$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
						unless($filterheader=~m/^\s*$/is)
						{
							$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
						}
						
						# Committing the transaction.
						$dbobject->commit();
					}
					
					# Collecting the Filter URL
					if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
					{
						$filterurl = $utilityobject->Decode($1.$2);
						if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
						{
							$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
						}
						else
						{
							$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
						}
						my $pageid;
						# Collecting the next page id 
						if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
						{
							$pageid = $1;
							$nextpage{$pageid}++;
						}
						# Divering to Label point
						goto NONextPage2 if($nextpage{$pageid}>1);
						goto NextPage2;
					}
					# Label Point
					NONextPage2:
				}
			}
		}					
	}	
}
				
$logger->send("$robotname :: Instance Completed  :: $pid\n");
################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################
$dbobject->commit();
$dbobject->Destroy();