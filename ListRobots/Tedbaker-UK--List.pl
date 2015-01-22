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
my $Retailer_Random_String='Ted';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;
###########################################

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

# URL Collection.
my $content = $utilityobject->Lwp_Get("http://www.tedbaker.com/uk?country=GB"); 

# Pattern match to get the topmenu block.
if($content=~m/<nav[^>]*?>([\w\W]*?)<\/nav>/is)
{
	my $blk=$1; 
	my $menu_1_link_content;
	
	# Pattern match to get the topmenu url and menus.(menu1=>women,men).
	while($blk=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>([^>]*?)</igs) 
	{
		my $url_1=$1;  
		my $menu_1=$utilityobject->Trim($2);
		
		my ($category_block,$category_block1,$category_url,$category_head);
		
		# Adding home URL If the URL doesn't Start with "http".
		$url_1='http://www.tedbaker.com'.$url_1 unless($url_1=~m/^\s*http\:/is);
		
		# Getting the content of the topmenu.
		$menu_1_link_content = $utilityobject->Lwp_Get($url_1);
		
		# Pattern match to get menu2 & it's url (Eg.Menu2=>Clothing,Accessories,Footwear,Gifts).
		while($menu_1_link_content=~m/<li\s*class\s*\=\s*\"\s*category_home\s*\"\s*>\s*<a[^>]*?href="\s*(\/uk\/[^\"]*?)\s*\"\s*title="\s*([^\"]*?)\s*"\s*>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>\s*<\/div>\s*<\/li>/igs) ###Clothing,Acc,Footwear,Gifts
		{
			my $menu_2_url = $1;
			my $menu_2 = $utilityobject->Trim($2);   
			my $menu_2_block=$3;   
			
			# Pattern match to get menu3 & it's url.(eg.menu3=>new arrivals,shirts).
			while($menu_2_block=~m/<a[^>]*?href="\s*(\/uk\/[^\"]*?)\s*\"\s*title="\s*([^\"]*?)\s*"\s*>/igs)
			{
				my $menu_3_link=$1;
				my $menu_3= $utilityobject->Trim($2);   
				
				# Adding home URL If the URL doesn't Start with "http".
				$menu_3_link='http://www.tedbaker.com'.$menu_3_link unless($menu_3_link=~m/^\s*http\:/is);
				
				# Getting the content of the menu3 url.
				my $menu_2_link_content = $utilityobject->Lwp_Get($menu_3_link); 
			
				# Pattern match to check whether menu3 is shirts (Different scenario - getting URLS from images).
				if($menu_3=~m/^\s*shirts\s*$/is)  
				{
					# Pattern match to get shirts collection page url.
					while($menu_2_link_content=~m/<a\s*class\s*\=\s*\"\s*image\s*\"[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?title\s*\=\"((?!view all)[^>]*?)\"[^>]*?>/igs)
					{
						my $shir_url=$1;
						my $shirt_category=$2;
						
						$shirt_category=~s/\s*shirts$//igs;
						
						# Adding home URL If the URL doesn't start with "http".
						$shir_url='http://www.tedbaker.com'.$shir_url unless($shir_url=~m/^\s*http\:/is);
						
						# Getting the content of the shirts's products collection page.
						my $menu_2_link_content_shir = $utilityobject->Lwp_Get($shir_url);
						
						# Pattern match to get each category block from main category block(eg.pattern).
						while($menu_2_link_content_shir=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/igs) 
						{
							$category_head=$1; #Category Heading
							$category_block=$2;
							$category_head =~s/Â//igs;
							
							# Pattern match to get sub category url from each category block(eg."check" under pattern).
							while($category_block=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
							{
								$category_url="$shir_url"."?q="."$1";									
								my $category= $utilityobject->Trim($2); # Category name.
								$category =~s/Â//igs;
								$category_url=~s/f\:/f%3A/igs;
								$category_url=~s/\,/%2C/igs;	
								&get_Product($category_url,$menu_1,$menu_2,$menu_3,$shirt_category,$category_head,$category); # Function call with arguments category urls and their corresponding menus.
							}
						}
					}
				}
				else
				{
					# Pattern match to get each category block from main category block (eg.choose from).
					while($menu_2_link_content=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/igs) 
					{
						$category_head=$1;  # Category heading.
						$category_block=$2;
						$category_head =~s/Â//igs;
						
						# Pattern match to get sub category URL from each category block(Eg."Beach Dress" Under Choose From)..
						while($category_block=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
						{
							$category_url="$menu_3_link"."?q="."$1";
							my $category= $utilityobject->Trim($2); # Category name.
							$category =~s/Â//igs;
							$category_url=~s/f\:/f%3A/igs;
							$category_url=~s/\,/%2C/igs;	
							&get_Product($category_url,$menu_1,$menu_2,$menu_3,'',$category_head,$category); #Function call with arguments category URLs and their corresponding menus.
						}
					}
				}
			}
		}
		&Chk_Footwear($menu_1_link_content,$menu_1);    #Taking footwear details(Having no drop-down Menu).
	}
}

sub Chk_Footwear()    #Function definition to take footwear details.
{
	my $menu_1_link_contentFoot=shift;
	my $menu1=shift;
	
	# Pattern match to check whether Menu2=>Footwear is available with category_home(doesn't have "category_home" in wep Page).
	if($menu_1_link_contentFoot !~ m/<li\s*class\s*\=\s*(?:\"|\')\s*category_home\s*(?:\"|\')\s*>\s*<a\s*class\s*\=\s*\"\s*\"\s*href\s*=\s*(?:\"|\')[^<]*?(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*Footwear\s*(?:\"|\')\s*[^>]*?>/is)
	{
		# Pattern match to get footwear URL.
		if($menu_1_link_contentFoot=~m/<li\s*class\s*\=\s*\"\s*\"\s*>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\s*\"[^>]*?>\s*(Shoes)\s*</is)
		{
			my $Foot_url=$1;
			my $menu_2=$2;
			
			# Adding home URL If the URL doesn't Start with "http".
			$Foot_url='http://www.tedbaker.com'.$Foot_url if($Foot_url!~m/^\s*http/); 
			
			# Getting the content of the Foot URL.
			my $menu_2_link_cont_Foot = $utilityobject->Lwp_Get($Foot_url); 
			
			# Pattern match to get each category block from main category block(Eg.Choose From).
			if($menu_2_link_cont_Foot=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/is)  ##To take categories under menus
			{
				my $category_head=$1;
				my $category_block=$2;
				$category_head =~s/Â//igs;
				
				# Pattern Match to get Sub Category URL from Each Category block(Eg.Boots).
				while($category_block=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
				{
					my $category_url="$Foot_url"."?q="."$1";
					my $category= $utilityobject->Trim($2);
					$category =~s/Â//igs;
					$category_url=~s/f\:/f%3A/igs;
					$category_url=~s/\,/%2C/igs;	
					&get_Product($category_url,$menu1,$menu_2,'','',$category_head,$category); #Function call with arguments category URLs and their corresponding menus
				}
			}
		}
		elsif($menu_1_link_contentFoot=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/is)  ##To take categories under menus
		{
			my $category_head=$1;
			my $category_block=$2;
			$category_head =~s/Â//igs;
			my $Foot_url;
			$Foot_url = 'http://www.tedbaker.com/uk/Womens/Shoes/c/womens_shoes' if($menu1 =~ m/^women/is);
			$Foot_url = 'http://www.tedbaker.com/uk/Mens/Shoes/c/mens_shoes' if($menu1 =~ m/^men/is);
			# Pattern Match to get Sub Category URL from Each Category block(Eg.Boots).
			while($category_block=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
			{
				my $category_url="$Foot_url"."?q="."$1";
				my $category= $utilityobject->Trim($2);
				$category =~s/Â//igs;
				$category_url=~s/f\:/f%3A/igs;
				$category_url=~s/\,/%2C/igs;	
				&get_Product($category_url,$menu1,'Shoes','','',$category_head,$category); #Function call with arguments category URLs and their corresponding menus
			}
		}
	}
}

$logger->send("$robotname :: Instance Completed  :: $pid\n");
#################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$dbobject->commit();

sub get_Product() #Function definition to get products url
{	
	my $Content_url=shift;
	my $menu_11=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $shirt_category1=shift;
	my $categ_h=shift;
	my $categ=shift;
	
	# Getting the content of the category URL.
	my $category_url_content = $utilityobject->Lwp_Get($Content_url);			

	# Pattern match to collect product URLs.
	while($category_url_content=~m/<h4\s*class="name"><a\s*href="\s*([^\"]*?)\s*"[^>]*?>\s*([^<]*?)\s*<\/a>\s*<\/h4>/igs)
	{
		my $product_url=$1;
		$product_url=~s/\&\#x2f\;/\//igs;
		
		# Adding home URL If the URL doesn't Start with "http".
		$product_url='http://www.tedbaker.com'.$product_url unless($product_url=~m/^\s*http\:/is);
		
		# Insert product values.
		my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
		# Insert tag values.
		$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
		
		unless($menu_22=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		unless($menu_33=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_3',$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		unless($shirt_category1=~m/^\s*$/is)
		{
			$dbobject->SaveTag($menu_33,$shirt_category1,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		unless(($categ=~m/^\s*$/is)&&($categ_h=~m/^\s*$/is))
		{
			$dbobject->SaveTag($categ_h,$categ,$product_object_key,$robotname,$Retailer_Random_String);
		}
		$dbobject->commit();
	}
}

