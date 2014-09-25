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
my $Retailer_Random_String='Aer';
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

# Aeropostale and P.S Kids! URL
my @urls_array=('http://www.aeropostale.com/shop/index.jsp?categoryId=3534619', 'http://www.aeropostale.com/category/index.jsp?categoryId=3534620');

# Main URLs for loop
foreach my $url (@urls_array)
{
	my $menu01;
	
	# To fix the menu1 as P.S kids only when the kids URL is navigate
	if($url=~m/categoryId\=3534620/is) # Menu 1 for P.S Kids
	{
		$menu01='P.S. KIDS!';
	}
	my $content = $utilityobject->Lwp_Get($url);
	
	# The main Page content to extract the main Menu category
	while($content=~m/(class\=\"mainNavButton\"><a\s*class\=\"aeroNavBut\"\s*href\=\"([^>]*?)\">([^>]*?)<\/a>|<li\s*id\=\"nav\-[\d]+\">\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a><\/li>)/igs)
	{
		my $menu_cat_url="http://www.aeropostale.com$2$4";		
		my $menu1=lc($utilityobject->Trim($3.$5));
		$menu_cat_url=~s/^([^>^\"]*?)\"[^>]*?$/$1/igs;
		my $ps_uniform_flag=0;
		
		# To find out to navigate to Uniform Menu with various Regex than regular
		if($menu1=~m/P\.S\.\s*uniform/is)
		{
			$ps_uniform_flag=1;			
		}
		
		$menu1=~s/Aero\s//igs;
		$menu1=~s/P\.S\.//igs;
		$menu1=~s/P\.S//igs;
		
		# To find out to navigate to Uniform Menu with various Regex than regular
		if(($menu01 ne '')&&($menu1=~m/uniform/is))
		{
			$ps_uniform_flag=1;
		}
		
		# For P.S Uniform Navigation content
		my $menu_cat_content=$utilityobject->Lwp_Get($menu_cat_url);
		
		# Uniform content fetching
		if($ps_uniform_flag==1)
		{
			if($menu_cat_content=~m/title\=\"Shop\s*Girls\s*Uniform\"\s*href\=\"([^>]*?)\"\/>/is)
			{
				my $uniform_url=$1;
				$uniform_url=~s/\&amp\;/&/igs;
				$menu_cat_content=$utilityobject->Lwp_Get($uniform_url);				
			}
		}
		
		# Regex to match bunch of featured shop and Shop by category menus
		while($menu_cat_content=~m/left\-nav\-[\d]+\">((?!size)[^>]*?)<\/dt>([^^]*?)<\/dl>/igs)
		{
			my $menu2=lc($utilityobject->Trim($1));
			my $menu2_block=$2;
			
			# To navigate to FEATURED SHOPS menu sub menus
			if($menu2=~m/FEATURED\s*SHOPS/is)
			{
				# Setting the Menu2 name if Menu1 is empty
				if($menu01 ne '')
				{
					$menu2='FEATURES';
				}
				
				# Sub menu/Menu 3 Link and name
				while($menu2_block=~m/redir\:p\+([^>]*?)\"\s*href\=\"([^>]*?)\">([^>]*?)</igs)
				{		
					my $final_link="http://www.aeropostale.com$2&$1&view=all";
					my $menu3=lc($utilityobject->Trim($3));
					my $final_cont=$utilityobject->Lwp_Get($final_link);
					
					# Extracting the product URLs from the menu 3 URL
					while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
					{
						my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
						$product_url=~s/([^>]*?)&cp\=[^>]*?$/$1/igs;
						
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						# Saving the tag information.
						if($menu01 ne '')
						{
							$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
							$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
						}
						else
						{
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
						}
						
						# Committing the transaction.
						$dbobject->commit();
					}
				}
			} # To navigate to SHOP BY CATEGORY menu's sub menus		
			elsif($menu2=~m/SHOP\s*BY\s*CATEGORY/is)
			{
				if($menu2_block=~m/<dt[^>]*?>\s*<a\s*rel[^>]*?>([^>]*?)<\/a>\s*<\/dt>([^^]*?)<\/ul>\s*<\/dd>/is)
				{					
					while($menu2_block=~m/<dt[^>]*?>[^>]*?<a\s*rel[^>]*?href="([^>]*?)\">([^>]*?)<\/a>[\w\W]*?<\/dt>(\s*<dd>\s*<ul>([\w\W]*?)<\/ul>\s*<\/dd>)?/igs)
					{
						my $menu3_url=$1;
						my $menu3=lc($utilityobject->Trim($2));
						my $check=$3;
						my $menu3_subblock=$4;
					
						# Default product collection for header menu
						$menu3_url="http://www.aeropostale.com$menu3_url&view=all";
						my $final_cont=$utilityobject->Lwp_Get($menu3_url);
						
						while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
						{
							my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
							$product_url=~s/([^>]*?)\&cp\=[^>]*?$/$1/igs;
							
							# To insert product URL into table on checking the product is not available already
							my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
							
							# Saving the tag information.
							if($menu01 ne '')
							{
								$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
								$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
																	
							}
							else
							{
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
								
							}
							
							# Committing the transaction.
							$dbobject->commit();
						}
						
						# Default product collection end
						# Sub menu or menu 5
						while($menu3_subblock=~m/<li>\s*<a\s*rel\=\"redir\:p\+([^>]*?)\"\s*href\=\"([^>]*?)\">([^>]*?)</igs)
						{
							my $final_link="http://www.aeropostale.com$2&$1&view=all";
							my $menu4=lc($utilityobject->Trim($3));
							
							# Menu3 block is empty, will skip the next navigation  
							if($check=~m/^\s*$/is)
							{
								next;
							}
							my $final_cont=$utilityobject->Lwp_Get($final_link);
							
							# Menu 4 URL extraction
							while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
							{
								my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
								$product_url=~s/([^>]*?)\&cp\=[^>]*?$/$1/igs;
								
								# To insert product URL into table on checking the product is not available already
								my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Saving the tag information.
								if($menu01 ne '')
								{
									$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
									$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
									$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
									$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
									$dbobject->SaveTag('Menu_5',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');									
								}
								else
								{
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
									$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
									$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
								}
								
								# Committing the transaction.
								$dbobject->commit();
							}
							
							# Subcategory under menu 4 / Menu 5 availablity check
							if($final_cont=~m/<h2>\s*<a\s*name[^>]*?>([^>]*?)<\/a>\s*<\/h2>([^^]*?)<\/div>\s*<\/div>\s*<\![^>]*?>\s*<\/div>\s*<\![^>]*?>\s*<\/div>\s*<\![^>]*>\s*<\/div>\s*<\/div>/is)
							{
								my @arr;
								my $arr_count=0;
								# Menu 5 Extraction and 
								while($final_cont=~m/<h2>\s*<a\s*name[^>]*?>([^>]*?)<\/a>\s*<\/h2>([^^]*?)<\/div>\s*<\/div>\s*<\![^>]*?>\s*<\/div>\s*<\![^>]*?>\s*<\/div>\s*<\![^>]*>\s*<\/div>\s*<\/div>/igs)
								{
									my $menu5=$1;									
									my $menu5_subblock=$2;
									
									my $temp;
									if($final_cont=~m/subsubsubcategory\">([^^]*?)<\/ul>/is)
									{
										my $block=$1;
										while($block=~m/<a\s*href\=[^>]*?>([^>]*?)<\/a>/igs)
										{
											push(@arr,"$1");
										}
									$temp=@arr;
									}
									$menu5=$arr[$arr_count] if($temp>0);
									while($menu5_subblock=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
									{
										my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
										$product_url=~s/([^>]*?)&cp\=[^>]*?$/$1/igs;
										
										# To insert product URL into table on checking the product is not available already
										my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Saving the tag information.
										if($menu01 ne '')
										{
											$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
											$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
											$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
											$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
											$dbobject->SaveTag('Menu_5',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
											$dbobject->SaveTag('Menu_6',$menu5,$product_object_key,$robotname,$Retailer_Random_String) if($menu5 ne '');
										}
										else
										{		
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
											$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
											$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
											$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
											$dbobject->SaveTag('Menu_5',$menu5,$product_object_key,$robotname,$Retailer_Random_String) if($menu5 ne '');
										}
										
										# Committing the transaction.
										$dbobject->commit();
									}
									$arr_count++;
								}
								undef @arr;
							}
						else{
								while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
								{
									my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
									$product_url=~s/([^>]*?)&cp\=[^>]*?$/$1/igs;
									
									# To insert product URL into table on checking the product is not available already
									my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Saving the tag information.
									if($menu01 ne '')
									{
										$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
										$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
										$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
										$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
										$dbobject->SaveTag('Menu_5',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
									}
									else
									{
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
										$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
										$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
										$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
									}
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
						
					}
				}
				if($menu2_block=~m/redir\:p\+([^>]*?)\"\s* href\=\"([^>]*?)\">(OUTERWEAR|ROOM)</is)
				{
					while($menu2_block=~m/redir\:p\+([^>]*?)\"\s* href\=\"([^>]*?)\">(OUTERWEAR|ROOM)</igs)
					{
						my $final_link="http://www.aeropostale.com$2&$1&view=all";
						my $menu3=lc($utilityobject->Trim($3));
						$final_link="http://www.aeropostale.com.$final_link" if($final_link!~m/^http/is);
						my $final_cont=$utilityobject->Lwp_Get($final_link);
						
						while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
						{
							my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
							$product_url=~s/([^>]*?)&cp\=[^>]*?$/$1/igs;
							
							# To insert product URL into table on checking the product is not available already
							my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
							
							# Saving the tag information.
							if($menu01 ne '')
							{
								$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
								$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
							}
							else
							{
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
							}
							
							# Committing the transaction.
							$dbobject->commit();
						}
					}
				}
				
			} # if none of the above is matches the deault product fetching loop will collect all the products from the present page
			else
			{
				while($menu2_block=~m/redir\:p\+([^>]*?)\"\s*href\=\"([^>]*?)\">([^>]*?)</igs)
				{
					my $final_link="http://www.aeropostale.com$2&$1&view=all";
					my $menu3=lc($utilityobject->Trim($3));
					# Skip if the VIEW ALL Menu
					next if($menu3=~m/VIEW\s*ALL/is);
					my $final_cont=$utilityobject->Lwp_Get($final_link);
					while($final_cont=~m/<h4>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)</igs)
					{
						my $product_url="http://www.aeropostale.com$1"; my $pdt_name=$2;
						$product_url=~s/([^>]*?)&cp\=[^>]*?$/$1/igs;
						
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						# Saving the tag information.
						if($menu01 ne '')
						{
							$dbobject->SaveTag('Menu_1',$menu01,$product_object_key,$robotname,$Retailer_Random_String) if($menu01 ne '');
							$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							$dbobject->SaveTag('Menu_4',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');							
						}
						else
						{
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
							$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
						}
						
						# Committing the transaction.
						$dbobject->commit();
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