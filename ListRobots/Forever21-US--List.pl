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
my $Retailer_Random_String='For';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;

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
# Getting Content of the home page
my $url="http://www.forever21.com/Product/Main.aspx?br=f21";
my $content = $utilityobject->Lwp_Get("$url");

# Array to take topmenu and it's url. 
my @regex_array=('<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(NEW\s*ARRIVALS)\s*<\/a>\s*<div','<div\s*class\s*\=\s*\"\s*women\s*dropdown\s*\"\s*>\s*<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\"\s*class\s*\=\s*\"\s*dropdown\-toggle\s*\"\s*>\s*(Women)\s*<','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(CLOTHING)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(ACCESSORIES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(SHOES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(LOVE\s*21)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(PLUS\s*SIZES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(MEN)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(GIRLS)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(SALE\s*(?:\&\s*DEALS)?)\s*<\/a>\s*<div'); 

my $robo_menu=$ARGV[0];

# Declaring all required variables.
my ($temp,$temp1,$temp2,$temp3,%hash_id);

# Getting each main or top menu one by one from Array.(Menu1=>NEW ARRIVALS,WOMEN, MEN,etc.).
foreach my $regex(@regex_array)
{
	# Pattern match to take topmenu and it's url.
	if ( $content =~m/$regex/is )
	{
		my $urlcontent =$1;
		my $menu_1=$utilityobject->Trim($2);  
		
		# print "menu_1 $menu_1\n";
		
		# Pattern match as topMenu Women do not have Corresponing url hence assigning main url
		if(($menu_1 eq "Women")&&($urlcontent eq "#")) 
		{
			$urlcontent=$url;
		}
		
		my $content1 = $utilityobject->Lwp_Get($urlcontent);
		
		# Pattern substitution helpful in taking block.
		$content1=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
		
		# Pattern match to collect products under "NEW ARRIVALS".
		if(($menu_1=~m/$robo_menu/is)&&($robo_menu=~m/NEW\s*ARRIVALS/is))
		{
			# Looping through to take header,url and menu under "New Arrivals".
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
			{
				my $menu_2_cat_new=$1;  # LHM Main Heding2=>Eg:Features (All menu1 have).
				my $url_2_new=$2;       # Menu2 url.
				my $menu_2_new=$3;      # Menu2=>Style Deals,Not So Basic in New Arrivals.
				
				# print "menu_2_cat_new $menu_2_cat_new\t $menu_2_new\n";
				
				# To temporarily store menu2's header to pass the header again while passing menu2 next time through a function.
				if($menu_2_cat_new)
				{
					$temp=$menu_2_cat_new;
				}
				else
				{
					$menu_2_cat_new=$temp;
				}
			
				# Function call to collect products under the corresponding menu.
				&GetProduct($url_2_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'','','','','');
				
				my $content2_new = $utilityobject->Lwp_Get($url_2_new);
					
				# Pattern substitution helpful in taking block.
				$content2_new=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
				
				# Pattern match navigate to the Menu "Premium Beauty"(Menu2=> Scenario 1=>New Arrivals,Premium Beauty).
				if($menu_2_new=~m/Premium\s*Beauty/is)  
				{
					# Pattern match to take header,url and menu under "Premium Beauty".
					while($content2_new=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg\">\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
					{
						my $menu_3_cat_new=$1;  #LHM Main Heding3=>Features (All menu1 have)
						my $url_3_new=$2;       #Menu3 url.  
						my $menu_3_new=$3;      #Menu3=>Style Deals,Not So Basic.
						
						# To temporarily store menu2's header to pass the header again while passing menu2 next time through a function.
						if($menu_3_cat_new)
						{
							$temp1=$menu_3_cat_new;
						}
						else
						{
							$menu_3_cat_new=$temp1;
						}
						
						# Function call to collect products under the corresponding menus & the category url.
						&GetProduct($url_3_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,'','','');
						
						my $content3_new = $utilityobject->Lwp_Get($url_3_new);
						
						# Pattern match to collect Products under Menu3=>"Style Deals".(Have no block).
						if($menu_3_new=~m/Style\s*Deals/is)
						{
							# Pattern match to take block under Menu=>"Style Deals".
							while($content3_new=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)# under$5 in Style Deals.
							{
								my $url_4_NewStyle=$1;
								my $menu_4_Style=$2;
						
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_4_NewStyle,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_Style,'','');  
							}
						}
						elsif($content3_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	# Pattern match to collect products if subcategory is available(Sub-Category1).
						{
							my $blk1=$1;
					
							while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)# Menu under$5 in Style Deals,Denim-Basics.
							{
								my $url_4_new=$1;
								my $menu_4_new=$2;
								
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_4_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,'','');
							
								my $content4_new = $utilityobject->Lwp_Get($url_4_new);
									
								# Pattern match to get the block to navigate through next submenu(Sub-Category2).
								if($content4_new=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_4_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)
								{
									my $blk2=$1;
									
									# Pattern match to get menu and it's url from the navigated block.
									while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
									{
										my $url_5_new=$1;
										my $menu_5_new=$2;
										
										# Function call to collect products under the corresponding menus & the category url.
										&GetProduct($url_5_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,$menu_5_new,'');
									
										my $content5_new = $utilityobject->Lwp_Get($url_5_new);
										
										# Pattern match to get the block to navigate through next submenu(Sub-Category3).
										if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_5_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is) 
										{
											my $blk3=$1;
											
											# Pattern match to get menu and it's url from the navigated block.
											while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
											{
												my $url_6_new=$1;
												my $menu_6_new=$2;
										
												# Function call to collect products under the corresponding menus & the category url.
												&GetProduct($url_6_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,$menu_5_new,$menu_6_new);
											}
										}
									}
								}
							}
						}
						# Pattern match to avoid looping issue.
						if($menu_3_new=~m/Capsule\s*2\.1/is)
						{
						   $content2_new='';
						}
					}
				}
				else   #Menu2=> Scenario 2=>If not Premium Beauty.
				{
					# Pattern to match with the menu "Style Deals".
					if($menu_2_new=~m/Style\s*Deals/is)
					{
						# Pattern match to take submenu under "Style Deals".(under$5 in Style Deals).
						while($content2_new=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
						{
							my $url_3_Style1=$1;
							my $menu_3_style1=$2;
					
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_3_Style1,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_style1,'','','');
						}
					}
					elsif($content2_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	# Pattern match to get the block to navigate through next submenu.(Sub-Category1).
					{
						my $blk1=$1;
				
						# Pattern match to get menu and it's url from the navigated block.
						while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
						{
							my $url_3_new=$1;
							my $menu_3_new=$2;
							
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_3_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,'','','');
						
							my $content3_new = $utilityobject->Lwp_Get($url_3_new);
							
							# # Pattern match to get the block to navigate through next submenu.(Sub-Category2).
							if($content3_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)
							{
								my $blk2=$1;
								
								# Pattern match to get menu and it's url from the navigated block.
								while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
								{
									my $url_4_new=$1;
									my $menu_4_new=$2;
									
									# Function call to collect products under the corresponding menu.
									&GetProduct($url_4_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,'','');
								
									my $content4_new = $utilityobject->Lwp_Get($url_4_new);
								
									# Pattern match to get the block to navigate through next submenu(Sub-Category3).
									if($content4_new=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_4_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	
									{
										my $blk3=$1;
										
										# Pattern match to get menu and it's url from the navigated block.
										while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
										{
											my $url_5_new=$1;
											my $menu_5_new=$2;
									
											# Function call to collect products under the corresponding menus & the category url.
											&GetProduct($url_5_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,$menu_5_new,'');
											
											my $content5_new = $utilityobject->Lwp_Get($url_5_new);
									
											# Pattern match to get the block to navigate through next submenu(Sub-Category4).
											if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_5_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	
											{
												my $blk3=$1;
												
												# Pattern match to get menu and it's url from the navigated block.
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
												{
													my $url_6_new=$1;
													my $menu_6_new=$2;
											
													# Function call to collect products under the corresponding menus & the category url.
													&GetProduct($url_6_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,$menu_5_new,$menu_6_new);
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
		elsif(($menu_1=~m/$robo_menu/is)&&($menu_1 eq "Women"))  #Pattern match to navigate under "Menu1=>Women".
		{
			# Pattern match to take "Main Block" (TopMenu do not have separate url hence taking Blocks from Top Menu).
			if($content1=~m/<a[^>]*?href\s*\=\s*\"[^>]*?\"[^>]*?class\s*\=\s*\"\s*dropdown\s*\-\s*toggle\s*\"[^>]*?>\s*(Women)\s*<([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
			{
				my $blk_Women=$&; 
				
				#Scenario 1: Pattern match to check whether submenus available.(Url Pattern). 
				if($blk_Women=~m/<a[^>]*?class\s*\=\s*\"\s*direct\s*\"\s*href\s*\=\s*\"([^>]*?)\s*\"\s*>([^<]*?)</is) 
				{
					# Pattern match to take submenu and it's url from the above block.(Menu1=>Women,Menu2=>Clothing,Love 21,Accessories).
					while($blk_Women=~m/<a[^>]*?class\s*\=\s*\"\s*direct\s*\"\s*href\s*\=\s*\"([^>]*?)\s*\"\s*>([^<]*?)</igs)
					{
						my $url_2_women=$1;
						my $menu_2_women=$utilityobject->Trim($2);
						# print "menu_2_women $menu_2_women\n";
						
						my $content2_Women = $utilityobject->Lwp_Get($url_2_women);
						
						if($menu_2_women=~m/(?:CLOTHING|LOVE21|ACCESSORIES)/is) #Pattern match to take products if submenu under women is "clothing or Love21 or accessories".(Scenario 1).
						{
							# Pattern substitution helpful in taking block.
							$content2_Women=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
							
							# Pattern match to take sub-menu and it's url.
							while($content2_Women=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
							{
								my $menu_3_cat_wom=$1;  # LHM Main Heding3 =>Features (All menu1 have).
								my $url_3_wom=$2;       # Menu3 url.  
								my $menu_3_wom=$3;      # Menu3=>Style Deals,Not So Basic.
								
								print "menu_3_cat_wom $menu_3_cat_wom $menu_3_wom\n";
								
								# To temporarily store menu2's header to pass the header again while passing menu2 next time through a function.
								if($menu_3_cat_wom)
								{
									$temp3=$menu_3_cat_wom;
								}
								else
								{
									$menu_3_cat_wom=$temp3;
								}
								
								# Function call to collect products under the corresponding menu.
								&GetProduct($url_3_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,'','','');
								
								my $content3_wom = $utilityobject->Lwp_Get($url_3_wom);
								
								# Pattern match to take products under "Style Deals".
								if(($menu_3_wom=~m/Style\s*Deals/is)&&($menu_3_wom!~m/Capsule/is))
								{
									# Pattern match to get menu and it's url from Style deals (Menu4=>under$5 in Style Deals)
									while($content3_wom=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
									{
										my $url_4_womStyle=$1;
										my $menu_4_womStyle=$2;
								
										# Function call to collect products under the corresponding menus & the category url.
										&GetProduct($url_4_womStyle,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_womStyle,'','');
									}
								}
								elsif($content3_wom=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	# Pattern match to get the block to navigate through next submenu.(Sub-Category1).
								{
									my $blk1=$1;
									
									# Pattern match to get menu and it's url from the navigated block.
									while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)##Denim-Basics
									{
										my $url_4_wom=$1;
										my $menu_4_wom=$2;
										
										# Function call to collect products under the corresponding menus & the category url.
										&GetProduct($url_4_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,'','');
										
										my $content4_wom = $utilityobject->Lwp_Get($url_4_wom);
											
										# Pattern match to get the block to navigate through next submenu.(Sub-Category2).	
										if($content4_wom=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	
										{
											my $blk2=$1;
											
											# Pattern match to get menu and it's url from the navigated block.
											while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
											{
												my $url_5_wom=$1;
												my $menu_5_wom=$2;
												
												# Function call to collect products under the corresponding menus & the category url.
												&GetProduct($url_5_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,$menu_5_wom,'');
												
												my $content5_wom = $utilityobject->Lwp_Get($url_5_wom);
												
												# Pattern match to get the block to navigate through next submenu.(Sub-Category3).
												if($content5_wom=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)
												{
													my $blk3=$1;
													
													# Pattern match to get menu and it's url from the navigated block.
													while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
													{
														my $url_6_wom=$1;
														my $menu_6_wom=$2;
														
														# Function call to collect products under the corresponding menus & the category url.
														&GetProduct($url_6_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,$menu_5_wom,$menu_6_wom);
													}
												}
											}
										}
									}
								}
							}
						}
						else  # If Main Heading under women is "not Clothing or Love21 or Accessories" (Scenario 2).
						{	
							
							# Pattern match to get the block to navigate through next submenu.(Sub-Category1).
							if($content2_Women=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2_women\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)
							{
								my $blk1=$1;
						
								# Pattern match to get menu and it's url from the navigated block.
								while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)##Denim-Basics
								{
									my $url_3_wom=$1;
									my $menu_3_wom=$2;
									
									# Function call to collect products under the corresponding menus & the category url.
									&GetProduct($url_3_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,'','','');
								
									my $content4_wom = $utilityobject->Lwp_Get($url_3_wom);
										
									# Pattern match to get the block to navigate through next submenu.(Sub-Category2).
									if($content4_wom=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*$menu_3_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)
									{
										my $blk2=$1;
										
										# Pattern match to get menu and it's url from the navigated block.
										while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
										{
											my $url_4_wom=$1;
											my $menu_4_wom=$2;
											
											# Function call to collect products under the corresponding menus & the category url.
											&GetProduct($url_4_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,$menu_4_wom,'','');
											
											my $content5_wom = $utilityobject->Lwp_Get($url_4_wom);
												
											# Pattern match to get the block to navigate through next submenu.(Sub-Category3).
											if($content5_wom=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	
											{
												my $blk3=$1;
												
												# Pattern match to get menu and it's url from the navigated block.
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
												{
													my $url_5_wom=$1;
													my $menu_5_wom=$2;
													
													# Function call to collect products under the corresponding menus & the category url.
													&GetProduct($url_5_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,$menu_4_wom,$menu_5_wom,'');
												}
											}
										}
									}
								}
							}
							else # Page's do not have Subcategorys.
							{
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_2_women,'',$menu_1,'',$menu_2_women,'','','','','');
							}
						}
					}
				}
				if($blk_Women=~m/<div[^>]*?>\s*(Features)\s*<([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is) #Scenario 2: Pattern match to check whether block & it's menu available.(Block Pattern). # Scenario 2=>Features.
				{
					my $menu_2_womenFeat=$1;
					my $FeatureBlock=$2;
					
					# Looping through to get the next sub-menu and it's url.
					while($FeatureBlock=~m/<a[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>([^>]*?)</igs)
					{
						my $url_2_womenFeat=$1;
						my $menu_3_womenFeat=$utilityobject->Trim($2); # Shop By Style.
						
						my $content4_womFeat = $utilityobject->Lwp_Get($url_2_womenFeat);
					
						# Pattern match to check whether menu3 is "Style Deals".
						if($menu_2_womenFeat=~m/Style\s*Deals/is)
						{
							# Pattern match to next submenu and it's url(under$5 in "Style Deals").
							while($content4_womFeat=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
							{
								my $url_3_womfeatStyle=$1;
								my $menu_3_womfeatStyle=$2;
						
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_3_womfeatStyle,'',$menu_1,'',$menu_2_womenFeat,'',$menu_3_womenFeat,$menu_3_womfeatStyle,'','');
							}
						}
						else # If menu is not "Style Deals".
						{
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_2_womenFeat,'',$menu_1,'',$menu_2_womenFeat,'',$menu_3_womenFeat,'','','');
						}
					}
				}
			}
		}
		elsif(($menu_1=~m/$robo_menu/is)&&($robo_menu=~m/SALE\s*(?:&(?:amp\;)?\s*DEALS)?/is))  # Pattern match to check whether Menu1 is Sale & Deals.
		{
			# Looping through to take header,url and menu under "Sale & Deals".
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
			{
				my $menu_2_cat_sal=$1;  # LHM Main Heading2 =>Shop All Sale,Shop By Category.
				my $url_2_sal=$2;       # Menu2 url.   
				my $menu_2_sal=$3;      # Menu2=>Style deals,Dresses.
				
				# print "menu_2_sal $menu_2_cat_sal $menu_2_sal\n";
				
				# To temporarily store menu2's header to pass the header again while passing menu2 next time through a function.
				if($menu_2_cat_sal)
				{
					$temp2=$menu_2_cat_sal;
				}
				else
				{
					$menu_2_cat_sal=$temp2;
				}
			
				my $content2_sal = $utilityobject->Lwp_Get($url_2_sal);
				
				# Pattern substitution helpful in taking block.
				$content2_sal=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
				
				# Pattern match to navigate through the submenu "Shop All Sale".
				if($menu_2_cat_sal=~m/Shop\s*All\s*Sale/is) 
				{
					# Pattern match to navigate through the submenu if menu1=>Sale,menu2=>"Shop All Sale",menu3=>Women.
					if($menu_2_sal=~m/Women/is)
					{
						# Pattern match to take header,url and menu under menu1=>"Sale", menu2=>"Shop all sale", menu3=>women.
						while($content2_sal=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
						{
							my $menu_3_cat_sal=$1;  # LHM Main Heading3=>Women>>Shop By Category.
							my $url_3_sal=$2;       # Menu3 url.
							my $menu_3_sal=$3;      # Menu3=>Dresses.
							
							# To temporarily store menu3's header to pass the header again while passing menu2 next time through a function.
							if($menu_3_cat_sal)
							{
								$temp1=$menu_3_cat_sal;
							}
							else
							{
								$menu_3_cat_sal=$temp1;
							}
							
							# Pattern matchh to avoid repeated process of product collection.
							if($menu_3_cat_sal!~m/(?:\s*Shop\s*By\s*Category\s*|Features)/is)
							{
								next;
							}
							
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_3_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,'','','');
							
							my $content3_sal = $utilityobject->Lwp_Get($url_3_sal);
							
							# Scenario 1: Pattern match to check whether next navigation available.
							if($content3_sal=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>/is)
							{
								# Pattern match to get next submenu and it's url.
								while($content3_sal=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>\s*([^<]*?)\s*<([\w\W]*?)<hr[^>]*?>\s*<\/td>\s*<\/tr>\s*<\/table>/igs)
								{
									my $menusubsal_4=$1;
									my $subblksal4=$2;
									
									# Function call to collect products under the corresponding menus & the category url.
									&GetProduct('',$subblksal4,$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menusubsal_4,'','');
								}
							}
							elsif($content3_sal=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_3_sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	# Scenario2: # Pattern match to get the block to navigate through next submenu.(Sub-category1).
							{
								my $blk1=$1;
						
								# Pattern match to get menu and it's url from the navigated block.
								while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs) 
								{
									my $url_4_sal=$1;
									my $menu_4_Sal=$2;
									
									# Function call to collect products under the corresponding menus & the category url.
									&GetProduct($url_4_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,'','');
								
									my $content4_sal = $utilityobject->Lwp_Get($url_4_sal);
										
									# Pattern match to get the block to navigate through next submenu.(Sub-category2).
									if($content4_sal=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_Sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)
									{
										my $blk2=$1;
										
										# Pattern match to get menu and it's url from the navigated block.
										while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
										{
											my $url_5_Sal=$1;
											my $menu_5_sal=$2;
											
											# Function call to collect products under the corresponding menus & the category url.
											&GetProduct($url_5_Sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,$menu_5_sal,'');
										
											my $content5_new = $utilityobject->Lwp_Get($url_5_Sal);
										
											# Pattern match to get the block to navigate through next submenu.(Sub-category3).
											if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5_sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	
											{
												my $blk3=$1;
												
												# Pattern match to get menu and it's url from the navigated block.
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
												{
													my $url_6_sal=$1;
													my $menu_6_sal=$2;
											
													# Function call to collect products under the corresponding menus & the category url.
													&GetProduct($url_6_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,$menu_5_sal,$menu_6_sal);
												}
											}
										}
									}
								}
							}
							elsif($menu_3_sal=~m/Style\s*Deals/is) # Scenario3: Pattern match to check whether the menu3 is "Style Deals".
							{
								
								# Looping through the menus under "Style Deals" (Eg.under$5 in Style Deals).
								while($content3_sal=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
								{
									my $url_4_NewStyle=$1;
									my $menu_4_Style=$2;
									
									# Function call to collect products under the corresponding menus & the category url.
									&GetProduct($url_4_NewStyle,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Style,'','');  
								}
							}
						}
					}
					else   # To navigate through the submenu if menu1=>Sale,menu2=>"Shop All Sale",menu3=>Men or  Girls.
					{
						# Pattern match to get the url,menu,block to navigate through next submenu.
						if($content2_sal=~m/0px\;\s*(?:\"|\')\s*>\s*<a[^>]*?href\s*\=\s*(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<font[^>]*?>\s*(Sale)\s*<([\w\W]*?)(?:<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>|<\/dl>)/is)
						{
							my $url_3_sal=$1;
							my $menu_3_sal=$2;
							my $menu_3_sal_blk=$3;
							
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_3_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_3_sal,'','','');
							
							# Pattern match to get menu and it's url from the navigated block.
							while($menu_3_sal_blk=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
							{
								my $url_4_sal=$1;
								my $menu_4_Sal=$2;
								
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_4_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_3_sal,$menu_4_Sal,'','');
							}
						}
						else
						{
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_2_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'','','','','');
						}
					}
				}
				else
				{
					# Pattern match to check whether menu2 is "Style Deals"
					if($menu_2_sal=~m/Style\s*Deals/is)   ###Style Deals
					{
						# Looping through to take next sub-menu and it's url (menu3=>under$5 in menu2=>Style Deals).
						while($content2_sal=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
						{
							my $url_4_SalStyle1=$1;
							my $menu_4_SalStyle1=$2;
					
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_4_SalStyle1,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_4_SalStyle1,'','','');  
						}
					}
					else
					{
						# Function call to collect products under the corresponding menus & the category url.
						&GetProduct($url_2_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'','','','','');
					}
				}
			}
		}
		elsif($menu_1=~m/$robo_menu/is)  # Pattern match to collect products under menu1=>"Other Than Women, Sale, New arrivals".
		{
			# Looping through to take header,url and menu to collect products from other topmenus.
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg([^>]*?)\">\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs) 
			{
				my $menu_2_cat=$1;  # LHM Main Heading 2=>Features (All menu1 have).
				my $url_2=$2;       # Menu2 url.
				my $subcatflag=$3;  # Flag to to avoid looping issue.
				my $menu_2=$4;      # Menu2.
				
				# print "menu_2_cat $menu_2_cat $menu_2\n";
				
				# To temporarily store menu2's header to pass the header again while passing menu2 next time through a function.
				if($menu_2_cat)
				{
					$temp2=$menu_2_cat;
				}
				else
				{
					$menu_2_cat=$temp2;
				}
				
				# Function call to collect products under the corresponding menus & the category url.
				&GetProduct($url_2,'',$menu_1,$menu_2_cat,$menu_2,'','','','','');
				
				my $content2 = $utilityobject->Lwp_Get($url_2);
				
				# Scenario1: Pattern match to check if subcategory has the class with "items_name".
				if(($content2=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>/is)&&(($menu_2!~m/Style Deals/is)))
				{
					# Looping through if subcategory has the class with "items_name".
					while($content2=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>\s*([^<]*?)\s*<([\w\W]*?)<hr[^>]*?>\s*<\/td>\s*<\/tr>\s*<\/table>/igs)
					{
						my $menusub_3=$1;
						my $subblk3=$2;
						
						# Function call to collect products under the corresponding menus & the category url.
						&GetProduct('',$subblk3,$menu_1,$menu_2_cat,$menu_2,'',$menusub_3,'','','');
					}
				}
				elsif($content2=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	# # Pattern match to get the block to navigate through next submenu. (Sub-category1)
				{
					my $blk1=$1;
					
					# Pattern match to get menu and it's url from the navigated block.
					while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
					{
						my $url_3=$1;
						my $menu_3=$2;
						
						# Function call to collect products under the corresponding menus & the category url.
						&GetProduct($url_3,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,'','','');
						
						my $content3 = $utilityobject->Lwp_Get($url_3);
						
						# Pattern match to get the block to navigate through next submenu(Sub-category 2).
						if($content3=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	
						{
							my $blk2=$1;
							
							# Pattern match to get menu and it's url from the navigated block.
							while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
							{
								my $url_4=$1;
								my $menu_4=$2;
								
								# Function call to collect products under the corresponding menus & the category url.
								&GetProduct($url_4,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,'','');
							
								my $content4 = $utilityobject->Lwp_Get($url_4);
							
								# Pattern match to get the block to navigate through next submenu.(Sub-category3).
								if($content4=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)
								{	
									my $blk4=$1;
									
									# Pattern match to get menu and it's url from the navigated block.
									while($blk4=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
									{
										my $url_5=$1;
										my $menu_5=$2;

										# Function call to collect products under the corresponding menus & the category url.
										&GetProduct($url_5,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,$menu_5,'');
										
										my $content5 = &$utilityobject->Lwp_Get($url_5);
										
										# Pattern match to get the block to navigate through next submenu.(Sub-category4).
										if($content5=~m/<dt[^>]*?30px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*30px\s*\;\s*\"[^>]*?>/is)	
										{
											my $blk5=$1;											
											
											# Pattern match to get menu and it's url from the navigated block.
											while($blk5=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
											{
												my $url_6=$1;
												my $menu_6=$2;
												
												# Function call to collect products under the corresponding menus & the category url.
												&GetProduct($url_6,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,$menu_5,$menu_6);
											}
										}
									}
								}
							}
						}								
					}
				}
				elsif(($menu_2=~m/Style\s*Deals/is)&&(!$subcatflag)) # Pattern match to check whether menu is "Style Deals" and if flag not set.
				{
					# Looping through to get menus and url's under "Style Deals".(under$5 in Style Deals).
					while($content2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
					{
						my $url_3_Sty=$1;  
						my $menu_3_Sty=$2;
				
						# Function call to collect products under the corresponding menus & the category url.
						&GetProduct($url_3_Sty,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3_Sty,'','','');
					}
				}
			}
		}
		else # Menus other than the given Topmenus.
		{
			next;
		}
	}	
}
			
sub GetProduct() # Function definition to collect Products.
{
	my $main_url=shift;  
	my $subblock=shift;
	my $menu_11=shift;
	my $menu_2_cat2=shift;
	my $menu_22=shift;
	my $menu_3_cat3=shift;
	my $menu_33=shift;
	my $menu_44=shift;
	my $menu_55=shift;
	my $menu_66=shift;
	
	# print "menus: $menu_11\t2:$menu_2_cat2\t$menu_22\t3:$menu_3_cat3\t$menu_33\t4:$menu_44\t5:$menu_55\t6:$menu_66\n";
	
	# Scenario1: Check whether block taken.(Eg.In SALE topmenu).
	if($subblock ne '')
	{
		# Pattern match to collect products.
		while($subblock=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/igs)
		{
			my $product_url=$1;
			my ($product_id,$product_object_key);
			
			# Pattern match to take product ID from url to remove duplicates.
			if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
			{
				$product_id=$1;
			}
			$product_url=~s/\&VariantID=[\w\W]*//is; # Pattern substitution to limit the url's size.
			
			# Insert Product values.
			if($hash_id{$product_id} eq  '')
			{
				$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				$hash_id{$product_id}=$product_object_key;
			}
			else
			{
				$product_object_key=$hash_id{$product_id};
			}
			
			# Save the Tag information based on the Product ID and its tag values.
			$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
			if($menu_2_cat2)
			{
				$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			else
			{
				$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			
			unless($menu_33 eq '')
			{
				if($menu_3_cat3)
				{
					$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
				}
				else
				{
					$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
				}
			}
			unless($menu_44 eq '')
			{
				$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_55 eq '')
			{
				$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_66 eq '')
			{
				$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}
	else # If subblock not available.
	{
		
		my $main_url1="$main_url"."&pagesize=100"; # Appending url to collect more product urls.
		
		my $main_url_content;
		
		my $staus=$utilityobject->GetCode($main_url1);  # Getting status to check whether appended url is having information.
		
		# Pattern match to check whether appended url is having code "200".(Is page have complete information).
		if($staus=~m/200/is)
		{
			$main_url_content=$utilityobject->Lwp_Get($main_url1);
		}
		else # If page doesn't have complete information get the page information of the actual url.
		{
			$main_url_content=$utilityobject->Lwp_Get($main_url);
		}

	next_page:

		# Pattern match to check whether product urls can be collected in this scenario.	
		if($main_url_content=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/is)
		{
			# Pattern match to collect product urls.
			while($main_url_content=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/igs)
			{
				my $product_url=$1;
				my ($product_id,$product_object_key);
				
				# Pattern match to take product ID from url to remove duplicates.
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is; # Pattern substitution to limit the url's size.
				
				# Insert Product values.
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
				# Save the Tag information based on the Product ID and its tag values.
				$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				if($menu_2_cat2)
				{
					$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				else
				{
					$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
					else
					{
						$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
				}
				unless($menu_44 eq '')
				{
					$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_55 eq '')
				{
					$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_66 eq '')
				{
					$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
				}
				$dbobject->commit();
			}
		}
		elsif($main_url_content=~m/<iframe\s*src\=\s*(?:\"|\')([^<]*?)(?:\"|\')[^<]*?>/is) # # Pattern match to check whether product urls can be collected in this scenario, If Product Page having Images (Eg: "http://www.forever21.com/looks/F21_main.aspx?br=21men")
		{
			# "Inside Frame"
			my $main_url_content_url1=$1;
			
			my $main_url_content_url1="http://www.forever21.com".$main_url_content_url1 unless($main_url_content_url1=~m/^http/is);
			
			my $main_url1_content=$utilityobject->Lwp_Get($main_url_content_url1);
			
			while($main_url1_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')\s*javascript[^\(]*?\((?:\'|\")([^>]*?)(?:\'|\")[^>]*?\)\s*[^>]*?>/igs)
			{
				my $product_url=$1;
				$product_url=~s/amp;//igs;					
				
				my $product_url="http://www.forever21.com".$product_url unless($product_url=~m/^http/is);
				
				my ($product_id,$product_object_key);
				
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is;
				
				# Insert Product values.
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
				# Save the Tag information based on the Product ID and its tag values.
				$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				if($menu_2_cat2)
				{
					$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				else
				{
					$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
					else
					{
						$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
				}
				unless($menu_44 eq '')
				{
					$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_55 eq '')
				{
					$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_66 eq '')
				{
					$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
				}
				$dbobject->commit();
			}
		}
		# Pattern match to take next page url.
		if($main_url_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*NextPage[^>]*?(?:\"|\')[^>]*?>/is)
		{
			$main_url=$1;
			
			$main_url='http://www.forever21.com/Product/Category.aspx'.$main_url unless($main_url=~m/^\s*http\:/is);
			
			$main_url_content = $utilityobject->Lwp_Get($main_url);
			goto next_page;
		}
	}
}

# To indicate script has completed in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Once script has complete send a msg to logger.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Committing the transaction.
$dbobject->commit();