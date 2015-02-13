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
my $Retailer_Random_String='Spo';
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

# URL Collection
my $Main_urls="http://www.sportsgirl.com.au/";
my $content100= $utilityobject->Lwp_Get($Main_urls);

# Extraction of Block for Menu
if($content100=~m/<div\s*class\s*\=\s*\"\s*nav\s*\-\s*container\s*\">\s*([\w\W]*?)\s*<script/is)
{	
	my $main_groups=$1;		
	$main_groups=~s/(<li\s*class\=\"level0\s*nav)/SportsList$1/igs;	
	
	# Extraction of Grouped Block of Menu1
	while($main_groups=~m/(<li\s*class\s*\=\s*\"level0\s*nav\s*\-\s*[\w\W]*?\s*>\s*[\w\W]*?\s*SportsList)/igs)
	{
		my $main_groups_sub=$1;			
		my($menu_1,$menu_2,$menu_3);
		
		# Extraction of Menu 1
		if($main_groups_sub=~m/level\s*\-\s*top\s*\" >\s*<span>\s*([^>]*?)\s*<\/span>/is)
		{
			$menu_1=$1;
			$menu_1=Trim($menu_1);
		}
		
		# Lookbook and Style menu Naviagtion
		if($menu_1!~m/(Lookbook|Style\s*Snaps|Blog)/is)
		{
			# Extraction of URL and Menu
			while($main_groups_sub=~m/level1[^>]*?\s*\">\s*<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\"\s*[^>]*?\s*>\s*<span>([^>]*?)<\/span>/igs)
			{		
				my $url3=$1;
				$menu_2=$2;
				$url3=~s/^\s+|\s+$//igs;
								
				# Framing the Sportsgirl URL with broken URL
				unless($url3=~m/^\s*http\:/is)
				{
					$url3="http://www.sportsgirl.com.au/".$url3;
				}
				$url3=~ s/\&amp\;/&/igs;	
				my $content= $utilityobject->Lwp_Get($url3);				
				
				# Extraction of Category Content and Name			
				while($content=~m/(<dt><span>\s*([^>]*?)\s*<\/span>\s*[\w\W]*?\s*<\/dl>\s*<\/dd>)/igs)
				{
					my $cate_content=$1;
					my $category_Name=$2;
					$category_Name=Trim($category_Name);					
					$category_Name=~ s/^\s+|\s+$//igs;
					my($Gro_URL,$sub_cate1);
					
					# Navigating to Filters Except Size and Price / Checking the category name is not Price or Size
					if($category_Name!~m/(Sizes|Price)/is)
					{	
						# URL for the Next level navigation and Sub category
						while($cate_content=~m/<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\">([^>]*?)<\/a>/igs)
						{
							$Gro_URL="$1";
							$sub_cate1=$2;
							$Gro_URL=~ s/\&amp\;/&/igs;						
							$sub_cate1=~ s/^\s+|\s+$//igs;						
							my $content3= $utilityobject->Lwp_Get($Gro_URL);

							my $ka=2;
							my $ma=1;
							
							# Navigating the Next page by using the increment operator	
							if($content3=~m/<li\s*class\s*\=\s*"\s*current\s*\">\s*([\w\W]*?)\s*<footer>/is)
							{
								my $next_content=$1;
								while($next_content=~m/<li>\s*<a\s*href=\s*[^>]*?\s*\">\s*([^>]*?)\s*</igs)
								{
									$ma++;
								}					
							}

							# Extracting the product URLs
							Next2:while($content3=~m/<h2\s*class\s*\=\s*\"product\s*\-\s*name\s*\">\s*<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\"/igs)
							{								
								my $product_url=$1;
								###Insert Product values
								
								# To insert product URL into table on checking the product is not available already
								my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Saving the tag information.
								$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
								$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');
								$dbobject->SaveTag($category_Name,$sub_cate1,$product_object_key,$robotname,$Retailer_Random_String) if($sub_cate1 ne '');
								
								# Committing the transaction.
								$dbobject->commit();								
							}
							
							# Next Page navigation URL framing
							if($ka<=$ma)
							{
								my $result;
								if(($Gro_URL=~m/([\d])/is)&&($Gro_URL=~m/\?/is))
								{
									$result="$Gro_URL"."&p=$ka&scrollCall=1";
								}
								else
								{
									$result="$Gro_URL"."?p=$ka&scrollCall=1";
								}				
								$content3 = $utilityobject->Lwp_Get($result);
								$ka++;	
								goto Next2;				
							}						
						}
					}
				}				
				
				my $ka=2;
				my $ma=1;
				
				# Navigating the Next page by using the increment operator					
				if($content=~m/<li\s*class\s*\=\s*"\s*current\s*\">\s*([\w\W]*?)\s*<footer>/is)
				{
					my $next_content=$1;
					while($next_content=~m/<li>\s*<a\s*href=\s*[^>]*?\s*\">\s*([^>]*?)\s*</igs)
					{
						$ma++;
					}
				
				}
				
				# Extracting the product URLs
				Next10:while($content=~m/<h2\s*class\s*\=\s*\"product\s*\-\s*name\s*\">\s*<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\"/igs)
				{
					my $product_url=$1;					
					
					# To insert product URL into table on checking the product is not available already
					my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					
					# Saving the tag information.
					$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
					$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');
					
					# Committing the transaction.
					$dbobject->commit();
				}
				
				#Next Page navigation			
				if($ka<=$ma)
				{
					my $result;
					
					# Framing the URL for Next page Navigation
					if(($url3=~m/([\d])/is)&&($url3=~m/\?/is))
					{
						$result="$url3"."&p=$ka&scrollCall=1";
					}
					else
					{
						$result="$url3"."?p=$ka&scrollCall=1";
					}				
					
					$content = $utilityobject->Lwp_Get($result);	
					$ka++;	
					
					# Pointing to Next10 Label
					goto Next10;
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
	
#Destroy all DB object
$dbobject->Destroy();

sub Trim
{
	my $txt = shift;
	
	$txt =~ s/\<[^>]*?\>//igs;
	$txt =~ s/\n+/ /igs;	
	$txt =~ s/^\s+|\s+$//igs;
	$txt =~ s/\s+/ /igs;
	$txt =~ s/\&nbsp\;//igs;
	$txt =~ s/\&amp\;/\&/igs;
	$txt =~ s/\&bull\;//igs;
	$txt =~ s/\&quot\;/"/igs;	
	$txt =~ s/\"/\'\'/g;
	$txt =~ s/\!//g;
	$txt =~ s/\Â//g;	
	return $txt;
}