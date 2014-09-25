#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
use URI::Escape;

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
my $Retailer_Random_String='Sus';
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

my $url = 'http://www.sussan.com.au';
my $content = $utilityobject->Lwp_Get($url);

# Isolating the usefull content
if($content=~m/<div\s*class\=\"homePageNav\">([\w\W]*?)<\/html>/is)
{	
	$content=$1;
}

# Extracting the Menu 1 and Menu Block
while($content=~m/<li\s*class\=\"level0[^>]*?ID\=\"([^>]*?)\">([\w\W]*?)<\/ul>/igs)
{
	my $menu1=$utilityobject->Trim($1);
	my $menu_block=$2;
	
	# Skipping the Menu 1
	next if($menu1=~m/gift/is);
	next if($menu1=~m/stylefile/is);

	 # Sale Menu fixing the word if some other name come along with sale
	if($menu1=~m/sale/is)
	{
		$menu1='Sale';
	}
	
	# Extracting the Menu 2 URL and Menu2
	while($menu_block=~m/><a\s*href\=\"([^>]*?)\"\s><span>([^>]*?)<\/span>|<li\s*class\=\'level1\s*nav\-1\-[\d]+?\'><a\s*href\=\'\s*([^>]*?)\s*\'>\s*([^>]*?)\s*<\/a><\/li>/igs)
	{
		my $menu2_url=$1.$3;
		my $menu2=$utilityobject->Trim($2.$4);
		$menu2_url=~s/&amp;/&/igs;
		
		# Skipping the Unwanted Menu
		next if($menu2=~m/gifts/is);
		next if($menu2=~m/gift\s*cards/is);
		next if($menu2=~m/books/is);
		next if($menu2=~m/bcna/is);
		next if($menu2=~m/lookbooks/is);
		next if($menu2=~m/style\s*advice/is);
		next if($menu2=~m/style\s*videos/is);
		next if($menu2_url=~m/[^>]*?\/style\-videos/is);
		
		# Extraction of web page Source of the URL
		my $final_cont=$utilityobject->Lwp_Get($menu2_url);
		
		my $last_cont_url;
		my $page_size;
		my $next_url;
		my $detail_cont;
		
		# Collecting the Next page URL
		my $final_cont_new=$final_cont;
		pager0:
		if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
		{
			my $next_url=$1;
			
			# applying the URI escape
			$next_url=uri_unescape($next_url);
			
			$final_cont_new=$utilityobject->Lwp_Get($next_url);
			$detail_cont=$final_cont_new;
			
			# Extracting the Product URL
			while($detail_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
			{
				my $last_cont_url=$1;
				
				# To insert product URL into table on checking the product is not available already
				my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
				
				# Saving the tag information
				$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
				$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
				
				# Committing the transaction.
				$dbobject->commit();
			}
			
			
			if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
			{
				goto pager0;
			}
		}					
		else
		{
			# Extracting the Product URL 
			while($final_cont_new=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
			{
				my $last_cont_url=$1;
				
				# To insert product URL into table on checking the product is not available already
				my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
				
				# Saving the tag information
				$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
				$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
				
				# Committing the transaction.
				$dbobject->commit();
			}
		}

		if($menu1=~m/sale/is) # For sale Category only
		{
			$menu1='Sale';
			
			# Sale category navigation		
			if($final_cont=~m/<div\s*class\=\"all\-product\-onsale\">([\w\W]*?)<a>\s*\#\s*<\/a>([\w\W]*?)<a>\s*\#\s*<\/a>/is)
			{
				$final_cont=$1;
			}
			
			# Extraction of Sale category filters with Sale filter and sale filter URL
			while($final_cont=~m/<a\s*data\-type\=\"all_product\"\s*rel\=\"[^>]*?"\s*level\="3"\s*data-ajax="1"[^>]*?data-url\=\"http:\/\/www\.sussan\.com\.au\/onsale\"\s*onclick=[^>]*?\"\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/igs)
			{
				my $sale_filter_url=$1;
				my $sale_filter=$2;
				
				# Applying the URI Escape function for sale filter URL
				$sale_filter_url=uri_unescape($sale_filter_url);

				# Extraction of the source
				my $final_cont=$utilityobject->Lwp_Get($sale_filter_url);
				
				# Extraction of Menu 3 Header and Menu 3 block
				if($final_cont=~m/<span\s*class\=\"filter\-name\">\s*<span\s*class\=\"filter\-title\-attribute\-deskop\s*desktopHeading\">\s*(Colour)\s*<\/span>([\w\W]*?)<\/ol>\s*<\/dd>\s*<\/dl>/is)
				{
					my $menu_3_header=$1;
					my $menu_3_block=$2;
					
					# Extraction of Menu3 and Menu3 URL
					if($menu_3_block=~m/<li\s*>\s*<a\s*data\-ajax\=\"1\"\s*data\-param\=\"[^>]*?data\-url\=\"[^>]*?\"\s*[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/is)
					{
						while($menu_3_block=~m/<li\s*>\s*<a\s*data\-ajax\=\"1\"\s*data\-param\=\"[^>]*?data\-url\=\"[^>]*?\"\s*[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $menu3_url=$1;
							my $menu_3=$utilityobject->Trim($2);
							
							# Applying the URI escape function to Menu3 URL
							$menu3_url=uri_unescape($menu3_url);
							
							# Extraction of the Menu 3 URL content
							my $final_cont_new=$utilityobject->Lwp_Get($menu3_url);

							# Collection of next page URL 
							pager1:
							if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
							{
								my $next_url=$1;
								
								# Applying the URI_Escape function
								$next_url=uri_unescape($next_url);

								$final_cont_new=$utilityobject->Lwp_Get($next_url);
								$detail_cont=$final_cont_new;
								
								# Extraction of Product URLs
								while($detail_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
								{
									my $last_cont_url=$1;
									
									# To insert product URL into table on checking the product is not available already
									my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
									
									# Saving the tag information.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
									$dbobject->SaveTag('Menu_3',$sale_filter,$product_object_key,$robotname,$Retailer_Random_String) if($sale_filter ne '');
									$dbobject->SaveTag($menu_3_header,$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
									
									# Committing the transaction.
									$dbobject->commit();
								}
								if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
								{
									goto pager1;
								}
							}					
							else
							{
								# Extraction of Product URLs
								while($final_cont_new=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
								{
									my $last_cont_url=$1;
									
									# To insert product URL into table on checking the product is not available already
									my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
									
									# Saving the tag information.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
									$dbobject->SaveTag('Menu_3',$sale_filter,$product_object_key,$robotname,$Retailer_Random_String) if($sale_filter ne '');
									$dbobject->SaveTag($menu_3_header,$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
					else
					{
						pager2:
						my $final_cont_new;
						
						# Extracting the Next page URL
						if($final_cont=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
						{
							my $next_url=$1;
							$next_url=uri_unescape($next_url);
							
							# Extraction of Page source from the URL
							$final_cont_new=$utilityobject->Lwp_Get($next_url);
							$detail_cont=$final_cont_new;
							
							# Extraction of Product URLs
							while($detail_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
							{
								my $last_cont_url=$1;

								# To insert product URL into table on checking the product is not available already
								my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
								
								# Saving the tag information.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$sale_filter,$product_object_key,$robotname,$Retailer_Random_String) if($sale_filter ne '');
								
								# Committing the transaction
								$dbobject->commit();
							}
							
							# If the below regex pattern matches, then there is another page to navigate
							if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
							{
								$final_cont=$final_cont_new;
								
								# Redirecting to Pager2 label.
								goto pager2;
							}
						}					
						else
						{
							while($final_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
							{
								my $last_cont_url=$1;
								
								# To insert product URL into table on checking the product is not available already
								my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
								
								# Saving the tag information.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$sale_filter,$product_object_key,$robotname,$Retailer_Random_String) if($sale_filter ne '');
								
								# Committing the transaction
								$dbobject->commit();
							}
						}
					}
				}
			}
		}
		else #Normal Mode of crawling
		{
			# Non-sale category navigation			
			if($final_cont=~m/<span\s*class\=\"filter\-name\">\s*<span\s*class\=\"filter-title-attribute-deskop\s*desktopHeading\">\s*(Colour)\s*<\/span>([\w\W]*?)<\/ol>\s*<\/dd>\s*<\/dl>/is)
			{
				my $menu_3_header=$1;				
				my $menu_3_block=$2;
				
				# Matching the pattern too check further Menus are available
				if($menu_3_block=~m/<li\s*>\s*<a\s*data\-ajax\=\"1\"\s*data\-param\=\"[^>]*?data\-url\=\"[^>]*?\"\s*[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/is)
				{
					# Extraction Of Menu 3 URL and Menu 3 
					while($menu_3_block=~m/<li\s*>\s*<a\s*data\-ajax\=\"1\"\s*data\-param\=\"[^>]*?data\-url\=\"[^>]*?\"\s*[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $menu3_url=$1;
						my $menu_3=$utilityobject->Trim($2);

						# Applying the URI Escape function
						$menu3_url=uri_unescape($menu3_url);												
						
						# Menu 3 URL content extraction
						my $final_cont_new=$utilityobject->Lwp_Get($menu3_url);
						
						# Next Page URL navigation
						pager3:
						if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
						{
							my $next_url=$1;
							
							# URI Escape funtion applied on the next page URL
							$next_url=uri_unescape($next_url);
							
							# Extraction of the Source from the Next page URL
							$final_cont_new=$utilityobject->Lwp_Get($next_url);
							$detail_cont=$final_cont_new;

							# Collection of Product URL
							while($detail_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
							{
								my $last_cont_url=$1;
								
								# To insert product URL into table on checking the product is not available already 
								my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
								
								# Saving the tag information.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag($menu_3_header,$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
								
								# Committing the transaction.
								$dbobject->commit();
							}
							
							# Redirecting to the pager3 Label if the below Regex pattern matches
							if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
							{
								goto pager3;
							}
						}					
						else
						{
							# Collection of Product URL
							while($final_cont_new=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
							{							
								my $last_cont_url=$1;
								
								# To insert product URL into table on checking the product is not available already 
								my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
								
								# Saving the tag information.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag($menu_3_header,$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
								
								# Committing the transaction.
								$dbobject->commit();
							}
						}
					}
				}
				else
				{
					my $final_cont_new=$final_cont;
					# Label point
					
					# Navigating to the next page URL
					pager4:					
					if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
					{
						my $next_url=$1;
						
						# Applying thi URI Escape function
						$next_url=uri_unescape($next_url);
												
						$final_cont_new=$utilityobject->Lwp_Get($next_url);
						$detail_cont=$final_cont_new;
						
						# Extraction of product URL
						while($detail_cont=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
						{
							my $last_cont_url=$1;
							
							# To insert product URL into table on checking the product is not available already  
							my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is);
							
							# Saving the tag information.
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							
							# Saving the tag information.
							$dbobject->commit();
						}
						
						# Redirecting to the pager3 Label if the below Regex pattern matches and navigating to next page
						if($final_cont_new=~m/<button\s*onclick\=\"[^>]*?setNavigationUrl\(\'([^>]*?)\'\,\s*true\)\;\"\s*>\s*<span>\s*Show\s*more\s*products\s*<\/span>\s*<\/button>/is)
						{							
							goto pager4;
						}
					}					
					else						
					{
						# Extraction of product URL
						while($final_cont_new=~m/<li\s*class\=\"item\">\s*<a\s*href\=\"\s*([^>]*?)\s*\"\s*title\=/igs)
						{
							my $last_cont_url=$1;

							# To insert product URL into table on checking the product is not available already  
							my $product_object_key = $dbobject->SaveProduct($last_cont_url,$robotname,$retailer_id,$Retailer_Random_String) if($last_cont_url!~m/^\s*$/is) ;
							
							# Saving the tag information.
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							
							# Saving the tag information.
							$dbobject->commit();
						}
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
	
#Destroy all DB object
$dbobject->Destroy();