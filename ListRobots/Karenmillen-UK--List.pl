#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
use utf8;
use HTML::Entities;

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
my $Retailer_Random_String='Kar';
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

# Main URL to capture the cache
my $url = 'http://www.karenmillen.com';
my $content = $utilityobject->Lwp_Get($url);

# Setting the country as UK and garbing the source
my $url = 'http://www.karenmillen.com/?lng=en&ctry=GB&';
my $content = $utilityobject->Lwp_Get($url);

my $trend_flag=0;

# collecting the menu1 and source content block 
while($content=~m/<a\s*class\=\"level_1\"\s*href\=\"([^>]*?)\"\s*rel\=\"canonical\">([^>]*?)<\/a>([\w\W]*?)<\/ul>\s*<div/igs)
{
	my $Menu1=Trim($2);
	my $Menu1_block=$3;
	my $Menu1_text=lc($Menu1);
	$Menu1_text=~s/\s+/ /igs;
	$Menu1_text=~s/^\s+|\s+$//igs;
	my $VMenu2='shop by category';
	$Menu1_block=$Menu1_block.'<ENDINGBLOCK>';

	# To navigate to NEW IN Category block and extracting the NEW IN block
	if($Menu1_block=~m/<a\s*class\=\"level_1\"\s*href\=\"([^>]*?)\"\s*rel\=\"canonical\">([^>]*?)<\/a>([\w\W]*?)<ENDINGBLOCK>/is) 
	{
		$Menu1=Trim($2);
		$Menu1_block=$3;
	}
	
	# Extracting Menu2 from Menu1 source block
	while($Menu1_block=~m/<a\s*class\=\"level_2\"\s*href\=\"([^>]*?)\"\s*rel\=\"canonical\">([^>]*?)<\/a>\s*(?:<div\s*class\=\"level_3\s*children_1\">([\w\W]*?)<\/ul>\s*<\/div>)?/igs)
	{
		my $Menu2_url=$1;
		my $Menu2=Trim($2);
		my $Menu2_block=$3;

		unless($Menu2_url=~m/^\s*http\:/is)
		{
			$Menu2_url='http://www.karenmillen.com'.$Menu2_url;
		}
		$Menu2_url=~s/\?\?/#/igs;
		$Menu2_url=~s/\?/#/igs;
		$Menu2_url=~s/\#/\?/igs;
		$Menu2_url=~s/&amp;/&/igs;
		
		my $Menu2_url_content = $utilityobject->Lwp_Get($Menu2_url);
		
		# Calling the Menu_2 filter navigation subroutine
		&filternavigation($Menu2_url_content, $Menu1, $VMenu2, $Menu2, "",$Menu2_url);
		
		while($Menu2_block=~m/<a\s*class\=\"level_3\"\s*href\=\"([^>]*?)\"\s*rel\=\"canonical\">([^>]*?)<\/a>/igs)
		{
			my $Menu3_url=$1;
			my $Menu3=Trim($2);
			unless($Menu3_url=~m/^\s*http\:/is)
			{
				$Menu3_url='http://www.karenmillen.com'.$Menu3_url;				
			}
			$Menu3_url=~s/\?\?/#/igs;
			$Menu3_url=~s/\?/#/igs;	
			$Menu3_url=~s/\#/\?/igs;			
			$Menu3_url=~s/&amp;/&/igs;
			my $Menu3_url_content = $utilityobject->Lwp_Get($Menu3_url);
			
			# Calling the Menu_3 filter navigation subroutine
			&filternavigation($Menu3_url_content, $Menu1, $VMenu2, $Menu2, $Menu3,$Menu3_url);
		}
		undef($Menu2_block);	
	}
	
	# Trend navigation point
	trend_navigation:	
	
	# Fetching the JavaScript URL from the content
	if($trend_flag==1)
	{
		$Menu1='TRENDS';
		$Menu1_text='TRENDS';
	}
	if($content=~m/<script\s*src\=\'([^>]*?)\'\s*async\s*defer><\/script>/is)
	{
		my $jsurl=$1;
		$jsurl='http:'.$jsurl;
		my $jsurl_content = $utilityobject->Lwp_Get($jsurl);
		if($Menu1_text!~m/^\s*Trends\s*/is)
		{
			$VMenu2='shop by collection';
		}
		
		# Fetching the exact trend Menu_1 content from JavaScript URL source
		if($jsurl_content=~m/name\s*\:\s*\"Header\s*\-\s*($Menu1_text)\s*\"([\w\W]*?)\}/is)
		{	 
			my $js_menu1=$1;
			my $sbc_block=$2;
			# Extracting the trend Menu_2 URL and Menu
			while($sbc_block=~m/<a\s*href\=\\x22([^>]*?)\\x22\s*class\=\\x22\s*level_2\\x22>([^>]*?)<\/a>/igs)
			{
				my $Menu2_url=$1;
				my $Menu2=$2;				
				unless($Menu2_url=~m/^\s*http\:/is)
				{
					$Menu2_url='http://www.karenmillen.com'.$Menu2_url;
				}				
				$Menu2_url=~s/\?\?/#/igs;
				$Menu2_url=~s/\?/#/igs;
				$Menu2_url=~s/\#/\?/igs;
				$Menu2_url=~s/&amp;/&/igs;
				
				my $Menu2_url_content = $utilityobject->Lwp_Get($Menu2_url);
				
				# Calling Menu 2 filter navigation subroutine				
				&filternavigation($Menu2_url_content, $Menu1, "", $Menu2, "",$Menu2_url);			
			}
		}
	}	
}	

# For trend navigation, if missed inside the loop
if($trend_flag==0)
{
	$trend_flag=1;
	my $Menu1='TRENDS';
	my $Menu1_text='TRENDS';
	
	# Fetching the JavaScript URL from the content
	if($content=~m/<script\s*src\=\'([^>]*?)\'\s*async\s*defer><\/script>/is)
	{
		my $jsurl=$1;
		$jsurl='http:'.$jsurl;
		my $jsurl_content = $utilityobject->Lwp_Get($jsurl);
		my $VMenu2='';
		
		# Fetching the exact trend Menu_1 content from JavaScript URL source		
		if($jsurl_content=~m/name\s*\:\s*\"Header\s*\-\s*($Menu1_text)\s*\"([\w\W]*?)\}/is)
		{	 
			my $js_menu1=$1;
			my $sbc_block=$2;
			
			# Extracting the trend Menu_2 URL and Menu
			while($sbc_block=~m/<a\s*href\=\\x22([^>]*?)\\x22\s*class\=\\x22\s*level_2\\x22>([^>]*?)<\/a>/igs)
			{
				my $Menu2_url=$1;
				my $Menu2=Trim($2);				
				unless($Menu2_url=~m/^\s*http\:/is)
				{
					$Menu2_url='http://www.karenmillen.com'.$Menu2_url;
				}				
				$Menu2_url=~s/\?\?/#/igs;
				$Menu2_url=~s/\?/#/igs;
				$Menu2_url=~s/\#/\?/igs;
				$Menu2_url=~s/&amp;/&/igs;
				
				# Extracting the $Menu2 URL content
				my $Menu2_url_content = $utilityobject->Lwp_Get($Menu2_url);
				
				# Extracting the $Menu3 URL content or Cut-work collection
				if($Menu2_url_content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"cta\">([^>]*?)<\/a>/is)  
				{
					my $menu3_url=$1;
					my $menu3=$2;					
					unless($menu3_url=~m/^\s*http\:/is)
					{
						$menu3_url='http://www.karenmillen.com'.$menu3_url;
					}
					my $menu3_url_content = $utilityobject->Lwp_Get($menu3_url);
					
					# Calling the Menu_3 filter navigation subroutine
					&filternavigation($menu3_url_content, $Menu1, "", $Menu2, $menu3,$menu3_url);
				} 
				elsif($Menu2_url_content=~m/<a\s*href\=\"([^>]*?)\s*\">\s*<p\s*class\=\"shop\-now\">([^>]*?)<\/p><\/a>/is)
				{
					my $menu3_url=$1;
					my $menu3=$2;
					unless($menu3_url=~m/^\s*http\:/is)
					{
						$menu3_url='http://www.karenmillen.com'.$menu3_url;
					}
					my $menu3_url_content = $utilityobject->Lwp_Get($menu3_url);
					
					# Calling Menu 3 filter navigation subroutine
					&filternavigation($menu3_url_content, $Menu1, "", $Menu2, $menu3,$menu3_url);
				}
				elsif($Menu2_url_content=~m/<div\s*id\=\"botanics\">([\w\W]*?)<\!--\s*CMS\s*PLACEHOLDER/is) # If URBAN BOTANICS Menu available
				{
					my $menu2_sub_block=$1;
					while($menu2_sub_block=~m/<a\s*href\=\"([^>]*?)\">\s*<img\s*src\=/igs) 
					{
						my $product_url=$1;
						unless($product_url=~m/^\s*http\:/is)
						{
							$product_url='http://www.karenmillen.com'.$product_url;		
						}
						
						# Skipping the pin interest URLS
						next if($product_url=~m/pinterest\.com/is);

						# Extracting the product ID
						my $product_id;
						if($product_url=~m/^[^>]*?\/([\d\w]+)$/is)  ### Unique ID Creation
						{
							$product_id=$1;
						}
						elsif($product_url=~m/^[^>]*?\/([\d\w]+)\?[^>]*?$/is)
						{
							$product_id=$1;
						}
					
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						
						# Saving the tag information to table
						$dbobject->SaveTag('Menu_1',$Menu1,$product_object_key,$robotname,$Retailer_Random_String) if($Menu1 ne '');
						my ($tag_flag2,$tag_flag3,$tag_flag4);
						if($VMenu2!~m/^\s*$/is)
						{
							$dbobject->SaveTag('Menu_2',$VMenu2,$product_object_key,$robotname,$Retailer_Random_String) if($VMenu2 ne '');
							$tag_flag2=1;
						}
						if($tag_flag2==1)
						{
							$dbobject->SaveTag('Menu_2',$Menu2,$product_object_key,$robotname,$Retailer_Random_String) if($Menu2 ne '');
						}
						else
						{
							$dbobject->SaveTag('Menu_3',$Menu2,$product_object_key,$robotname,$Retailer_Random_String) if($Menu2 ne '');
						}
						
						# Committing the transaction.
						$dbobject->commit();
					}					
				}
				else
				{	# Calling the Menu_2 filter navigation subroutine
					&filternavigation($Menu2_url_content, $Menu1, "", $Menu2, "",$Menu2_url);
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

# Disconnecting all DB objects
$dbobject->Destroy();

# subroutine for filter navigation (LHM)
sub filternavigation
{
	my $Menu3_url_content=shift;
	my $Menu1=shift;
	my $VMenu2=shift;
	my $Menu2=shift;
	my $Menu3=shift;
	my $listing_url=shift;
	
	# Filter header name from Menu_3 URL content
	while($Menu3_url_content=~m/<p\s*class\=\"filter_title\s*\"[^>]*?>([^>]*?)<\/p>([\w\W]*?)<\/ul>/igs)	
	{
		my $filter_header=Trim($1);
		my $filter_block=$2;
		
		# skipping the size, price filters
		if($filter_header=~m/\s*size\s*$|^\s*$|\s*maxprice\s*|\s*minprice\s*|\s*price\s*/is)
		{
			next;
		}
		
		# Extracting the filter name and URL from the filter block
		while($filter_block=~m/<a\s*class\=\"hover_filter\"\s*href\=\"([^>]*?)\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<span\s*class\=\"[^>]*?\">/igs)
		{
			my $filter_url=$1;
			my $filter_name=Trim($2);
			unless($filter_url=~m/^\s*http\:/is)
			{
				$filter_url='http://www.karenmillen.com'.$filter_url;				
			}
			$filter_url=~s/\?\?/#/igs;
			$filter_url=~s/\?/#/igs;
			$filter_url=~s/\#/\?/igs;
			$filter_url=~s/&amp;/&/igs;
						
			my $filter_url_content = $utilityobject->Lwp_Get($filter_url);
			
			# Calling the Product URL fetching subroutine			
			&get_products($filter_url_content, $Menu1, $VMenu2, $Menu2, $Menu3, $filter_header, $filter_name, $filter_url,$listing_url);
		}
		
		# Extracting the filter URL key and filter name
		while($filter_block=~m/<li\s*id\=\"filter_[^>]*?\"\s*class\=\"sli_unselected\"><a\s*href\=\"javascript\:processfacets2\(\s*\'\'\s*\,\s*([^>]*?)\s*\)\"\>([^>]*?)</igs)
		{	
			my $filter_url_key=$1;
			my $filter_name=Trim($2);
			my $filter_url;
			if($filter_url_key=~m/\s*\'([^>]*?)\'\s*\,\s*\'([^>]*?)\'\s*/is)
			{	
				$filter_url='http://fashion.karenmillen.com/ppc/%22shop+cutwork%22?af='.$1.':'.$2;
			}
		}
		undef($filter_block);
	}	
}

# Products URL collection subroutine
sub get_products
{
	my $product_list_content=shift;
	my $Menu1=shift;
	my $VMenu2=shift;
	my $Menu2=shift;
	my $Menu3=shift;
	my $filter_header=shift;
	my $filter_name=shift;
	my $filter_url=shift;
	my $listing_url=shift;
	
	# Extracting the product URL from the product available URL
	if($product_list_content=~m/<label\s*for\=\"sortby\"\s*id\=\"sortby_label\">/is)
	{
		my $product_url;
		while($product_list_content=~m/<p\s*class\=\"product_title\">\s*<a\s*href\=\"([^>]*?)\"\s*class\=\"product_link\">([^>]*?)<\/a>\s*<\/p>/igs)
		{
			$product_url=$1;
			my $product_url_name=$2;
			
			unless($product_url=~m/^\s*http\:/is)
			{
				$product_url='http://www.karenmillen.com'.$product_url;				
			}
			
			my $product_id;
			if($product_url=~m/^[^>]*?\/([\d\w]+)$/is)  ### Unique ID Creation
			{
				$product_id=$1;
			}
			elsif($product_url=~m/^[^>]*?\/([\d\w]+)\?[^>]*?$/is)
			{
				$product_id=$1;
			}

			# To insert product URL into table on checking the product is not available already
			my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			
			# Saving the tag information.
			$dbobject->SaveTag('Menu_1',$Menu1,$product_object_key,$robotname,$Retailer_Random_String) if($Menu1 ne '');
			
			my ($tag_flag2,$tag_flag3,$tag_flag4);			
			if($VMenu2!~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$VMenu2,$product_object_key,$robotname,$Retailer_Random_String) if($VMenu2 ne '');
				$tag_flag2=1;
			}
			
			if($tag_flag2==1)
			{
				$dbobject->SaveTag('Menu_3',$Menu2,$product_object_key,$robotname,$Retailer_Random_String) if($Menu2 ne '');
				$tag_flag3=1;
			}
			else
			{
				$dbobject->SaveTag('Menu_2',$Menu2,$product_object_key,$robotname,$Retailer_Random_String) if($Menu2 ne '');
			}
			
			if($tag_flag3==1)
			{
				if($Menu3!~m/^\s*$/is)
				{
					$dbobject->SaveTag('Menu_4',$Menu3,$product_object_key,$robotname,$Retailer_Random_String) if($Menu3 ne '');
				}
			}
			else
			{
				if($Menu3!~m/^\s*$/is)
				{
					$dbobject->SaveTag('Menu_3',$Menu3,$product_object_key,$robotname,$Retailer_Random_String) if($Menu3 ne '');
				}
			}
			if($filter_name!~m/^\s*$/is)
			{
				$dbobject->SaveTag($filter_header,$filter_name,$product_object_key,$robotname,$Retailer_Random_String) if($filter_name ne '');
			}
			
			# Committing the transaction.
			$dbobject->commit();		
		}
	}	
}

# Local Trim function with HTML decode_entities and UTF_8 function
sub Trim
{
	my $value1=shift;
	$value1=~s/\&\#8217\;/\'/igs;
	$value1=~s/\&\#8217\;/\'/igs;
	$value1=~s/\&\#10\;\s*\-/*/igs;
	$value1=~s/\&\#13\;\s*\-/*/igs;
	$value1=~s/\&quot\;/"/igs;
	$value1=~s/\&quot/"/igs;
	$value1=~s/¡¯/'/igs;
	$value1=~s/<[^>]*?>/ /igs;
	$value1=~s/\s+/ /igs;
	$value1=~s/^\s+|\s+$//igs;
	$value1=decode_entities($value1);
	utf8::decode($value1);
	return($value1);	
}

