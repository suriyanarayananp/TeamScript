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
my $Retailer_Random_String='Bhs';
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
my $content = $utilityobject->Lwp_Get("http://www.bhs.co.uk/");
my %hash_id;

# Array to take block for each top menus. 
my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Sale\s*(?:&amp;\s*Offers)?|Offers)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title=\"(Women)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title\s*\=\s*\"\s*(Home\s*(?:\,?\s*Lighting\s*&(?:amp\;)?\s* Furnitures?)?\s*)\s*\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title=\"(Men)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Children)\"[^<]*>','<li\s*class=\"[^<]*?471109\"\s*>\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Wedding)\"[^<]*>','<li\s*class=\"[^<]*?1288491\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*)\"[^<]*title=\"(Gifts)\"[^<]*>','<li\s*class\s*\=\s*\"\s*[^<]*?\s*\"\s*>\s*<a[^>]*?href="\s*([^>]*?home)\s*\"[^>]*?>\s*(Holiday\s*Shop)\s*<');   

# Passing topmenu as argument to get the products under the corresponding menu. 
my $robo_menu=$ARGV[0];

# Getting each pattern to get menu and it's url from array.
foreach my $regex(@regex_array)
{	
	# Pattern match to get menu and it's url from the above variable.(Eg.Menu1=>Women)
	if ( $content =~ m/$regex/is )
	{
		my $url=$1;
		my $menu_11=$utilityobject->Trim($2);
		$url =~ s/amp;//g;
		
		my $main_page_content = $utilityobject->Lwp_Get($url);
		# Declaring the variables.
		my ($menu_22,$menu_2_blk);
		
		# Pattern match to check whether menu1 is "sale" (Scenario 1).
		if(($menu_11=~m/$robo_menu/is)&&($robo_menu=~m/(?:Sale\s*(?:&amp;\s*Offers)?|Offers)/is))  
		{
			# Pattern match to get the block under the menu1 is "sale".
			if ( $main_page_content =~ m/<ul\s*class\s*\=\s*\"\s*column_1\s*\"\s*>\s*<li\s*class\s*\=\s*\"\s*category_935514\s*"\s*>([\w\W]*?)<\/ul>\s*<\/div>/is)
			{
				$menu_2_blk=$1;   # Menu2 Block.
				&func($menu_2_blk,$menu_11,'');  # Passing menu2 block ,their menus as arguments to process further.
			}
		}
		else
		{
			if(($menu_11=~m/$robo_menu/is)&&($menu_11=~m/(?:Home|women|Men|children|Wedding|Holiday\s*Shop)/is)) # Pattern matches to check whether menu1 is "Home or women or Men or children or Wedding" (Scenario 2).
			{
				while ( $main_page_content =~ m/<a[^<]*?class\s*\=\s*\"\s*division\s*\"[^<]*?>([^<]*?)<\/a>\s*<ul>([\w\W]*?)<\/ul>/igs ) # Getting LHM topmenu and it's block.
				{
					$menu_22=$utilityobject->Trim($1);  # Menu2 => Shop by Collection, Clothing,etc.
					$menu_2_blk=$2;                     # Menu2 Block.
					
					# Pattern match to avoid taking "furnitures" under "Menu1=> Home,Lighting&Furniture".(As per  assessment sheet).
					if($menu_22=~m/(?:\s*looks\s*\&(?:amp;)?\s*features\s*|buying\s*guides|BHSfurniture.co.uk|bhsdirect.co.uk)/is)
					{
						next;
					}
					&func($menu_2_blk,$menu_11,$menu_22); # Passing menu2 block ,their menus as arguments to process further.
				}
			}
			elsif(($menu_11=~m/$robo_menu/is)&&($menu_11=~m/Gifts/is)) # Pattern matches to collect products under menu "Gifts"(Scenario 3).
			{
				&GetProductcat($url,$menu_11,'','','','','','');  # Function call to collect products under filters in gifts topmenu do not have block hence directly collecting products.
			}
			else
			{
				next;
			}
		}
	}
}

sub func()  # Function definition to take LHS Menu's(#3 Scenario's ->pages having single left navigation,double left navigation,without left nevigation).
{		
	my $menu_22_blk=shift;
	my $menu_1=shift;
	my $menu_2=shift;
	
	# Looping through to get LHS menu's url and it's menu.
	while($menu_22_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
	{
		my $main_list_url = $1;
		my $menu_3=$utilityobject->Trim($2);   # Eg.Menu1=>"Home, Lighting & Furniture Kitchen & Cookware",Menu2=>"Kitchen & Cookware" having LHM menus "SHOP BY DEPARTMENT=>1)Baking & Roasting,2)Kitchen Accessories,etc".
		$main_list_url =~ s/amp;//g;
		
		# Declaring required variables.
		my ($category_url,$menu_4,$menu_4_cat,$main_list_content,$menu_5_cat,$menu_5,$main_list_url2);
		
		# Appending home url if url doesn't start with "http".
		$main_list_url="http://www.bhs.co.uk".$main_list_url unless($main_list_url=~m/^\s*http\:/is);
		
		# To avoid taking sale in menu3 (having separate sale menu),Furniture.
		if($menu_3=~m/^\s*sale\s*$|^\s*All\s*Women\'s\s*Sale\s*$|^Furniture$/is)
		{
			next;
		}
		
		my $main_list_content = $utilityobject->Lwp_Get($main_list_url);
		
		# Pattern match to check whether LHM available.(1st left navigation).
		if($main_list_content=~m/<ul\s*id\s*\=\s*\"\s*leftnav\s*"\s*>/is) 
		{
			# Looping through to get the menu's header and blk for the 1st left navigation.
			while($main_list_content=~m/<li>\s*<h2>([^<]*?)<([\w\W]*?)<\/ul>/igs) 
			{
				$menu_4_cat=$utilityobject->Trim($1);   
				my $menu_44_blk=$2;
				
				# Looping through to get the urls and the menu from the block.
				while($menu_44_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
				{
					my $main_list_url1=$1;
					$menu_4=$utilityobject->Trim($2);
					$main_list_url1 =~ s/amp;//g;
					
					# To skip if menu is "view All".
					if($menu_4=~m/(?:See|view)\s*All\s*[^>]*?/is)
					{
						next;
					}
					
					# Appending home url if url doesn't start with "http".
					$main_list_url1="http://www.bhs.co.uk".$main_list_url1 unless($main_list_url1=~m/^\s*http\:/is);
					
					my $main_list_content1 = $utilityobject->Lwp_Get($main_list_url1);
					
					# Pattern match to check whether LHM available.(2nd left navigation).
					if($main_list_content1=~m/<ul\s*id\s*\=\s*\"\s*leftnav\s*"\s*>/is) 
					{
						# Looping through to get the menu's header and block for the 1st left navigation.
						while($main_list_content1=~m/<li>\s*<h2>([^<]*?)<([\w\W]*?)<\/ul>/igs)
						{
							$menu_5_cat=$utilityobject->Trim($1);   
							my $menu_55_blk=$2;
							
							# Looping through to get the urls and the menu from the block.
							while($menu_55_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
							{
								$main_list_url2=$1;
								$menu_5=$utilityobject->Trim($2);
								$main_list_url2 =~ s/amp;//g;
								
								# To skip if menu is "view All".
								next if($menu_5=~m/^(?:See|view)\s*All\s*/is);
								
								$main_list_url2="http://www.bhs.co.uk".$main_list_url2 unless($main_list_url2=~m/^\s*http\:/is);
								
								# Function call with arguments category url and it's menus which is having 2nd left navigations and its menus.
								&GetProductcat($main_list_url2,$menu_1,$menu_2,$menu_3,$menu_4_cat,$menu_4,$menu_5_cat,$menu_5);
							}
						}
					}
					else
					{
						&GetProductcat($main_list_url1,$menu_1,$menu_2,$menu_3,$menu_4_cat,$menu_4,'',''); # Function call with arguments category url and it's menus which is having single(1st) left navigation and its menus.
					}
				}
			}
		}
		else
		{
			&GetProductcat($main_list_url,$menu_1,$menu_2,$menu_3,'','','',''); # Function call with arguments category url and it's menus of page having no left navigation and its menus.
		}
	}
}

sub GetProductcat()   # Function definition to get category urls from filter's page(Page having filters in LHS).
{
	my $main_list_url_main=shift;
	my $menu_11=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $menu_4_cat1=shift;
	my $menu_44=shift;
	my $menu_5_cat1=shift;
	my $menu_55=shift;
	$main_list_url_main =~ s/amp;//g;
	
	my $main_list_content_main = $utilityobject->Lwp_Get($main_list_url_main);
	
	# Looping through to get filter.
	while( $main_list_content_main =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)    
	{
		my $part_name = $utilityobject->Trim($1); # Taking Part name.
		my $list_part_content = $2;               # Taking part's block.
		
		# Pattern match if product page having "category" in LHS (Filtering Products by category).
		if($part_name=~m/Category/is)
		{
			# Looping through to get category url and it's name.
			while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)
			{
				my $category_url = $1;
				my $category_name = $utilityobject->Trim($2); 
				$category_url =~ s/amp;//g;
				
				
				&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55); # Function call with argumets category url and its menu.
				my $main_list_content_main1=$utilityobject->Lwp_Get($category_url);
				
				# Pattern match to check whether if category page having filter in LHS.
				if($main_list_content_main1=~m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)
				{
					# Looping through filters in LHS to take filter header and it's block.
					while ( $main_list_content_main1 =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!\s*Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)   
					{
						my $part_name = $utilityobject->Trim($1);   # Taking part name.
						my $list_part_content = $2;                 # Taking part's block.
						
						if($part_name=~m/Category/is)               # Filtering products by category within category.
						{
							# Looping through to get menu and its url.
							while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)
							{
								my $category_url = $1;
								my $category_name = $utilityobject->Trim($2);  # Taking Category name.
								$category_url =~ s/amp;//g;
								
								&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55); # Function call with arguments category url and it's menu.
								
								my $main_list_content_main1=$utilityobject->Lwp_Get($category_url);
								
								# Pattern match to check whether if category page having filter in LHS.
								if($main_list_content_main1=~m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)
								{
									# Looping through filters in LHS to take filter header and it's block.
									while ( $main_list_content_main1 =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!\s*Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)  
									{
										my $part_name = $utilityobject->Trim($1);   # Taking part name.
										my $list_part_content = $2;                 # Taking part's block.
										
										# Looping through to get category name and it's url.
										while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs) 
										{
											my $category_url = $1;
											my $category_name = $utilityobject->Trim($2);  # Taking Category name.
											$category_url =~ s/amp;//g;
											
											&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);# Function call with arguments category url and it's menu.
										}
									}
								}
							}
						}
						else
						{
							while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)# Pattern match if product page not having "category" within Category in LHS.
							{
								my $category_url = $1;
								my $category_name = $utilityobject->Trim($2);  
								$category_url =~ s/amp;//g;
								
								
								&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);# Function call with arguments category url and it's menu.
							}
						}
					}
				}
			}
			$main_list_content_main='';
		}
		else  # If product page not having "category" in LHS (Filtering Products that does not have category).
		{
			while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs) # Pattern match to get category name and it's url.
			{
				my $category_url = $1;
				my $category_name = $utilityobject->Trim($2);
				$category_url =~ s/amp;//g;
				
				&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);# Function call with arguments category url and it's menu.
			}
		}
	}
}
					
sub GetProduct()  #Function definition to collect products.
{					
	my $category_url1=shift;
	my $category_name1=shift;
	my $part_name1=shift;
	my $menu_111=shift;
	my $menu_222=shift;
	my $menu_333=shift;
	my $menu_4_cat11=shift;
	my $menu_444=shift;
	my $menu_5_cat11=shift;
	my $menu_555=shift;
	my $product_list_content;
	
	# Appending category url if category url doesn't start with "http".
	$category_url1="http://www.bhs.co.uk/en/bhuk/category/"."$category_url1" unless($category_url1=~m/^\s*http\:/);
			
	$category_url1=~ s/amp;//g;
	$category_name1 =~s/(\([\w]*\))//;
	
next_page:
	
	# Appending page size with category url for time consumption and reduce url ping.
	my $category_url11="$category_url1"."&pageSize=200";
	
	# Getting the status code for the corresponding category url.
	my $staus=$utilityobject->GetCode($category_url11);
	
	# Pattern match to check whether the status code is "200" to get the page's content.
	if($staus=~m/200/is)
	{
		$product_list_content = $utilityobject->Lwp_Get($category_url11);
	}
	else # If status code is not "200" get the page content from "category url" where page size not appended.
	{
		$product_list_content = $utilityobject->Lwp_Get($category_url1);
	}
	
	# Looping through to collect products from the category url.
	while($product_list_content=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">/igs)   
	{
		my $product_url=$1;
		
		print "$product_url\n";
		# Appending home url if product url doesn't start with "http".
		$product_url="http://www.bhs.co.uk/".$product_url unless($product_url=~m/^\s*http\:/is);	
		$product_url =~ s/amp;//g;
		
		# Pattern match to make unique product URL (If url like "http://www.bhs.co.uk/webapp/wcs/stores/servlet/ProductDisplay?refinements=category~%5b471666%7c471194%5d%5ecategory~%5b471666%7c471194%5d%5ecategory~%5b472090%7c471666%5d&beginIndex=41&viewAllFlag=&catalogId=34096&storeId=13077&productId=5108303&langId=-1").
		if($product_url=~m/([^<]*productId=[^<]*?&langId=-1)[^<]*?/is)
		{
			$product_url=$1;
			$product_url=~s/^([^>]*?\?)[^>]*?(\&catalogId=[^<]*?)$/$1$2/igs;
		}		
		elsif($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) # Pattern match to make unique product URL (If url like "http://www.bhs.co.uk/en/bhuk/product/great-value-polka-print-jersey-gypsy-dress-2651313").
		{
			$product_url='http://www.bhs.co.uk/en/bhuk/product/'.$1;
		}
		
		# Getting product id to remove duplicates.
		my $prod_id;
		
		# Pattern match to get product id(scenario 1).
		if($product_url=~m/productId\s*\=\s*(\d+)/is)
		{
			$prod_id=$1;
		}
		elsif($product_url=~m/^[^>]*?(\d+)$/is)# Pattern match to get product id(scenario 2).
		{
			$prod_id=$1;
		}
		
		# Calling SaveProduct to make entry to the product table.
		my $product_object_key;
		if($hash_id{$prod_id} eq '')
		{
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$hash_id{$prod_id}=$product_object_key;
		}
		else # If Product id already exist in hash assigning product's tag information to existed product url.
		{
			$product_object_key=$hash_id{$prod_id};
		}
		   
		# Save the tag information of menu1.
		$dbobject->SaveTag('Menu_1',$menu_111,$product_object_key,$robotname,$Retailer_Random_String);
		
		# Save the tag information if menu3 is not empty.
		unless($menu_333 eq '')
		{
			# Pattern match to check whether menu1 is sale (Topmenus have category headers).
			if($menu_111=~m/(?:Sale\s*(?:&amp;\s*Offers)?|Offers|Sale)/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_333,$product_object_key,$robotname,$Retailer_Random_String);
			}
			else # If menu1 is not sale that topmenus not have category headers.
			{
				$dbobject->SaveTag($menu_222,$menu_333,$product_object_key,$robotname,$Retailer_Random_String);
			}
		}
		# Save the tag information if menu4 is not empty.
		unless($menu_444 eq '')
		{
			$dbobject->SaveTag($menu_4_cat11,$menu_444,$product_object_key,$robotname,$Retailer_Random_String);	
		}
		# Save the tag information if menu5 is not empty.
		unless($menu_555 eq '')
		{
			$dbobject->SaveTag($menu_5_cat11,$menu_555,$product_object_key,$robotname,$Retailer_Random_String);	
		}
		# Save the tag information of filter values.
		$dbobject->SaveTag($part_name1,$category_name1,$product_object_key,$robotname,$Retailer_Random_String);	
		$dbobject->commit();
	}
	# Pattern match to get the next page url.
	if ($product_list_content =~ m/<a\s*href=\"([^<]*?)\"\s*title=\"Show\s*next\s*page\">/is )
	{
		$category_url1 = $1;
		$category_url1 =~ s/amp;//g;
		goto next_page;
	}
}

# Sending information to logger that all the instaces completed.
$logger->send("$robotname :: Instance Completed  :: $pid\n");
# For Dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
# For Dashboard.
$dbobject->commit();
