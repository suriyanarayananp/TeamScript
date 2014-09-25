#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
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

my $url = 'http://www.walmart.com';
my $content = $utilityobject->Lwp_Get($url);


# Main Menu Regex
my @main_menu=('class\=\"leftNavTitle\s*clearfix\"><div>\s*(Clothing\s*\,\s*Shoes\s*\&(?:amp\;)?\s*Jewelry)\s*<\/div><b\s*class\=sprite_leftNav><\/b><\/div><div\s*class\=leftNavBox>([\w\W]*?)<div\s*class\=\"leftNavTitle\s*clearfix\">','class\=\"leftNavTitle\s*clearfix\"><div>\s*(Pharmacy\s*\,\s*Health\s*[^>]*?)\s*<\/div><b\s*class\=sprite_leftNav><\/b><\/div><div\s*class\=leftNavBox>([\w\W]*?)<div\s*class\=\"leftNavTitle\s*clearfix\">','class\=\"leftNavTitle\s*clearfix\"><div>\s*(Baby\s*\&amp\;\s*Kids\s*[^>]*?)\s*<\/div><b\s*class\=sprite_leftNav><\/b><\/div><div\s*class\=leftNavBox>([\w\W]*?)<div\s*class\=\"leftNavTitle\s*clearfix\">');

# Rotating the main menu regex
foreach my $regex (@main_menu)
{
	# Extraction of the Menu1 and Menu1 content
	if($content=~m/$regex/is)
	{
		my $Menu1=Trim($1); ### MENU 1
		my $Menu1_sub_content=$2; 
				
		# Extraction of First Main Category
		while($Menu1_sub_content=~m/<div\s*class\=boxColumn>([\w\W]*?)<\/div>/igs)
		{
			my $vertical_block1=$1; # Clothing , Shoes & Jewelry Block
			$vertical_block1=$vertical_block1.' LinkBOXEND';
			$vertical_block1=~s/\s*class\=mainCategory\s*title\=/ LinkBOXEND class=mainCategory title=/igs;

			# Extraction of main category name and main category block block
			while($vertical_block1=~m/class\=mainCategory\s*title\=[^>]*?>([^>]*?)<\/a>([\w\W]*?)LinkBOXEND/igs) 
			{
				my $main_category_name=Trim($1); 
				my $main_category_block=$2;

				# Skipping the Menu 2 if the ARGUMENTS ARE NOT PASSED
				next unless($main_category_name=~m/\s*$ARGV[0]\s*/is); ### MENU 2 Passing the Arguments to GO IN  ### Eg: CLothing, Featured Shops
				
				# COllecting the First part category URL and First Part Name
				while($main_category_block=~m/<a\s*href\=\"([^>]*?)\"\s*title\=[^>]*?>([^>]*?)<\/a>/igs)### First Level of Navigation ###
				{
					my $first_part_category_url=$1;
					my $first_part_name=Trim($2); ### Menu 3 Here ###  Womens, Womens plus
					
					# Assigning the variable in TEMP variable
					my $first_part_name_temp=$first_part_name;

					# Skipping the Menu 3 if the ARGUMENTS ARE NOT PASSED
					unless($first_part_name_temp=~m/^\s*$ARGV[1]\s*$/is)
					{
						next;
					}
					
					# Framing the URL unless the http is available in URL
					unless($first_part_category_url=~m/^\s*http\:/is)
					{
						$first_part_category_url='http://www.walmart.com/'.$first_part_category_url;
					}
					
					my $first_part_category_url_content=$utilityobject->Lwp_Get($first_part_category_url);
					
					my $Normal_menu_flag=0;
					
					# Extraction of Filter menu name / boxed category under LHM
					if($first_part_category_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is)
					{
						my $menu2_part_name=Trim($1); 
						my $menu2_block=$2;
											
						$Normal_menu_flag=1;
						
						# Extraction of Menu3 URL and Menu3 Name
						while($menu2_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
						{
							my $menu3_url=$1;
							my $menu3_name=Trim($2);
							
							# adding the http, if not framed
							unless($menu3_url=~m/^\s*http\:/is)
							{
								$menu3_url='http://www.walmart.com/'.$menu3_url;
							}
														
							my $menu3_url_content=$utilityobject->Lwp_Get($menu3_url);
							
							# Checking condition to naviagate Intimates Menu
							if(($menu3_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))
							{
								my $Intimates_content = $menu3_url_content;
								
								# Menu4 part name and Block filter
								while($Intimates_content=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
								{
									my $Menu4_part_name=Trim($1);
									my $block_filter=$2;
									
									# Category URL collection from the filter block and Category name as Menu 4
									while($block_filter=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
									{
										my $Category_url1=$1;
										my $menu_4=Trim($2);	
										
										$menu_4=~s/<[^>]*?>/ /igs;
										$menu_4=~s/&nbsp/ /igs;
										$menu_4=~s/\s+/ /igs;
										$menu_4=~s/^\s+|\s+$//igs;

										# Adding the http, if not framed 
										unless($Category_url1=~m/^\s*http\:/is)
										{
											$Category_url1='http://www.walmart.com'.$Category_url1;
										}
										
										my $menu4_url_content=$utilityobject->Lwp_Get($Category_url1);
										
										# Calling the go_LHM1 Left hand menu collection subroutine
										&go_LHM1($menu4_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu3_name,$Menu4_part_name,$menu_4,"","",$menu3_url);
									}
								}
							}
							else
							{	
								# Calling the go_LHM1 Left hand menu collection subroutine
								&go_LHM1($menu3_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu3_name,"","","","",$menu3_url);
							}													
						}
												
						# Extraction of Boxed Category content & Featured Shops, Specialty Sizes, Shoes & Accessories, Special Offers, TO avoid the recurring navigation, Checking, if first Loop Executed
						if($Normal_menu_flag==0) 
						{
							# Extraction of the Menu 2 part name and menu 2 block
							while($first_part_category_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/igs)
							{
								my $menu2_part_name=Trim($1);
								my $menu2_block=$2;
								
								# Skipping if the Menu 2 part name not passed as Argument
								next unless($menu2_part_name=~m/^\s*$ARGV[0]\s*$/is);
								
								# Skipping the Learn More Menu
								if($menu2_part_name=~m/^\s*Learn\s*More\s*$/is)
								{
									next;
								}
								
								# Extraction of the Menu2 URL
								while($menu2_block=~m/<li><a\s*[^>]*?href\=\"([^>]*?)\">([^>]*?)<\/a>\s*<\/li>/igs)
								{
									my $menu2_url=$1; 
									my $menu2_name=Trim($2); #### As Menu 4 Name
									
									# Adding the http, if not framed 
									unless($menu2_url=~m/^\s*http\:/is)
									{
										$menu2_url='http://www.walmart.com/'.$menu2_url;
									}
									
									# Navigating to Boxed category
									my $menu3_url_content=$utilityobject->Lwp_Get($menu2_url);
									
									# Additional Navigation type to "All departments" navigation for Filters under Jwellery and watches content & Bags and Lagguage content under LHM
									if($menu3_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is) ### Data have another more navigations ####
									{
										my $menu21_part_name=Trim($1);
										my $menu21_block=$2;
										
										# Extraction of Menu 4 Sub block 
										while($menu21_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
										{											
											my $menu31_url=$1;  
											my $menu31_name=Trim($2);
											
											# Skipping the Learn More 
											if($menu21_part_name=~m/^\s*Learn\s*More\s*$/is) ### TO avoid Special Offers category
											{
												next;
											}
											
											# Adding the http, if not framed in URL
											unless($menu31_url=~m/^\s*http\:/is)
											{
												$menu31_url='http://www.walmart.com/'.$menu31_url;
											}
			
											my $menu31_url_content=$utilityobject->Lwp_Get($menu31_url);
											
											# Intimates Category naviagtion
											if(($menu31_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))
											{						
												my $Intimates_content1 = $menu31_url_content;

												# Extraction of Sub-menu header under Menu 4 and its Block
												while($Intimates_content1=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
												{
													my $Menu41_part_name=Trim($1);
													my $block_filter1=$2;
													
													# Extraction of Sub-menu under Menu 4 and URL
													while($block_filter1=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
													{
														my $Category_url11=$1;
														my $menu_41=Trim($2);														
														$menu_41=~s/<[^>]*?>/ /igs;
														$menu_41=~s/&nbsp/ /igs;
														$menu_41=~s/\s+/ /igs;
														$menu_41=~s/^\s+|\s+$//igs;
														
														# Adding the http, if not framed in URL
														unless($Category_url11=~m/^\s*http\:/is)
														{
															$Category_url11='http://www.walmart.com'.$Category_url11;
														}
														
														my $menu41_url_content=$utilityobject->Lwp_Get($Category_url11);

														# Calling the go_LHM1 Left hand menu collection subroutine
														&go_LHM1($menu41_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu21_part_name,$menu31_name,$Menu41_part_name,$menu_41,$menu31_url);
													}
												}
											}
											else
											{	
												# Calling the go_LHM1 Left hand menu collection subroutine
												&go_LHM1($menu31_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu21_part_name,$menu31_name,"","",$menu31_url);
											}									
										}
									}
									else 
									{
										# Pattern checking for navigation of Menu3 URL content
										if($menu3_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/is)
										{
											# One down catgory of the boxed category with Header
											while($menu3_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/igs)
											{
												my $add1menu2_part_name=Trim($1); # As Menu 3 part Name
												my $add1menu2_block=$2;
												
												# skipping the unwanted category header
												if($add1menu2_part_name=~m/(^\s*Shop\s*More\s*|^\s*Shop\s*all\s*|^\s*Learn\s*More\s*$)/is)
												{
													next;
												}
												
												# One down catgory of the boxed category with category name and URL
												while($add1menu2_block=~m/<li><a\s*[^>]*?href\=\"([^>]*?)\">([^>]*?)<\/a>\s*<\/li>/igs)
												{
													my $add1menu2_url=$1; 
													my $add1menu2_name=Trim($2); # As Menu 3 Name
													
#													# Added to avoid navigating to these bulk product categories
													if($add1menu2_name=~m/(^\s*Shop\s*More\s*|^\s*Shop\s*all\s*)/is)
													{
														next;
													}
													
													# Adding the http, if not framed in URL
													unless($add1menu2_url=~m/^\s*http\:/is)
													{
														$add1menu2_url='http://www.walmart.com/'.$add1menu2_url;
													}
													
													my $menu3_url_content=$utilityobject->Lwp_Get($add1menu2_url);
										
													# Extraction of boxed category navigation / COllection of the Menu3 Header
													while($menu3_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/igs)
													{
														my $add1menu23_part_name=Trim($1);
														my $add1menu23_block=$2;
														
														if($add1menu23_part_name=~m/^\s*Learn\s*More\s*$/is) ### TO avoid SpecialOffers category
														{
															next;
														}	
														
														# Extraction of menu 3
														while($add1menu23_block=~m/<li><a\s*[^>]*?href\=\"([^>]*?)\">([^>]*?)<\/a>\s*<\/li>/igs)
														{
															my $add1menu23_url=$1; 
															my $add1menu23_name=Trim($2); 
																								
															unless($add1menu23_url=~m/^\s*http\:/is)
															{
																$add1menu23_url='http://www.walmart.com/'.$add1menu23_url;
															}
															
															my $menu321_url_content=$utilityobject->Lwp_Get($add1menu23_url);

															# Additional Navigation to all departments navigation under LHM / Menu 2
															if($menu321_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is) ### Data have another more navigations ----- IT STOPPED HERE #####
															{
																my $add1menu21_part_name=Trim($1);
																my $add1menu21_block=$2;				
																
																# Extraction of Menu 3 by navigation to LHM Menu
																while($add1menu21_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
																{
																	my $add1menu31_url=$1;
																	my $add1menu31_name=Trim($2);
																	
																	# Skipping the Learn More Menu
																	if($add1menu21_part_name=~m/^\s*Learn\s*More\s*$/is)
																	{
																		next;
																	}
																																		
																	unless($add1menu31_url=~m/^\s*http\:/is)
																	{
																		$add1menu31_url='http://www.walmart.com/'.$add1menu31_url;
																	}

																	my $menu31_url_content=$utilityobject->Lwp_Get($add1menu31_url);
																
																	# Navigating to Intimates Menu under menu 2 (Women)
																	if(($add1menu31_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))
																	{
																		my $Intimates_content1 = $menu31_url_content;
																		
																		while($Intimates_content1=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
																		{
																			my $Menu41_part_name=Trim($1);
																			my $block_filter1=$2;
																			
																			# Collecting the Category URL and Category Name from Filter Block content
																			while($block_filter1=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
																			{
																				my $Category_url11=$1;
																				my $menu_41=Trim($2);
																				
																				$menu_41=~s/<[^>]*?>/ /igs;
																				$menu_41=~s/&nbsp/ /igs;
																				$menu_41=~s/\s+/ /igs;
																				$menu_41=~s/^\s+|\s+$//igs;

																				unless($Category_url11=~m/^\s*http\:/is)
																				{
																					$Category_url11='http://www.walmart.com'.$Category_url11;
																				}
																				
																				my $menu41_url_content=$utilityobject->Lwp_Get($Category_url11);
																				
																				# Calling the go_LHM1 Function to naviagte additional Left hand menu
																				&go_LHM1($menu41_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$add1menu21_part_name,$add1menu31_name,$Menu41_part_name,$menu_41,$add1menu31_url); #### Add 2 more 
																			}
																		}
																	}
																	else
																	{	
																		# Calling the go_LHM1 Function to naviagte additional Left hand menu
																		&go_LHM($menu31_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$add1menu2_part_name,$add1menu2_name,$add1menu23_part_name,$add1menu23_name,$add1menu21_part_name,$add1menu31_name,$add1menu31_url,0);
																	}
																}
															}
															else
															{
																# Calling the go_LHM1 Function to naviagte additional Left hand menu
																&go_LHM1($menu321_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$add1menu2_part_name,$add1menu2_name,$add1menu23_part_name,$add1menu23_name,$menu2_url);

															}
														}
													}
												
													# Collection of Menu 3 header under the Boxed category from Menu 3 URL Content
													if($menu3_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is) ### Data have another more navigations ----- IT STOPPED HERE #####
													{
														my $menu23_part_name=Trim($1);
														my $menu23_block=$2;				
														
														# Collection of the Menu 3 URL and Menu3
														while($menu23_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs) ### URL Collection
														{															
															my $menu32_url=$1;
															my $menu32_name=Trim($2);

															if($menu23_part_name=~m/^\s*Learn\s*More\s*$/is) ### TO avoid Special Offers category
															{
																next;
															}
															unless($menu32_url=~m/^\s*http\:/is)
															{
																$menu32_url='http://www.walmart.com/'.$menu32_url;
															}

															my $menu32_url_content=$utilityobject->Lwp_Get($menu32_url);

															# Check point for Intimates Menu 3 and navigate to Intimate Menu with Intimate matching Regex pattern														
															if(($menu32_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))	####NOT NEEDED HERE ### Changes Done here
															{										
																my $Intimates_content1 = $menu32_url_content;
																# Collecting Menu 4 header and Filter block for Menu 4
																while($Intimates_content1=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
																{
																	my $Menu41_part_name=Trim($1);
																	my $block_filter1=$2;
																	
																	# Collection of Category URL and Menu 4
																	while($block_filter1=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
																	{
																		my $Category_url11=$1;
																		my $menu_41=Trim($2);
																		
																		$menu_41=~s/<[^>]*?>/ /igs;
																		$menu_41=~s/&nbsp/ /igs;
																		$menu_41=~s/\s+/ /igs;
																		$menu_41=~s/^\s+|\s+$//igs;

																		unless($Category_url11=~m/^\s*http\:/is)
																		{
																			$Category_url11='http://www.walmart.com'.$Category_url11;
																		}
																		
																		my $menu41_url_content=$utilityobject->Lwp_Get($Category_url11);

																		# Calling the go_LHM1 function to naviagte additional Left hand menu
																		&go_LHM1($menu41_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu23_part_name,$menu32_name,$Menu41_part_name,$menu_41,$Category_url11);
																	}
																}
															}
															else
															{	
																# Calling the go_LHM1 function to naviagte additional Left hand menu
																&go_LHM1($menu32_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$add1menu2_part_name,$add1menu2_name,$menu23_part_name,$menu32_name,$menu32_url); ### Change Here
															}
														}
													}
													else
													{
														# Calling the go_LHM1 function to naviagte additional Left hand menu
														&go_LHM1($menu3_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$add1menu2_part_name,$add1menu2_name,"","",$menu2_url);
													}
												}
											}
										}
										else
										{	# Calling the go_LHM1 function to naviagte additional Left hand menu
											&go_LHM1($menu3_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,"","","","",$menu2_url); ##### Here Bags and Lagguage goes in

										}

									}
								}
							}
						}					
					}  # Else if for Jwellery watches menu
					elsif($first_part_category_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/is) ### Added ELse for Rejected Conditions ### ###  NEEED TO MOVE FROM HERE ### IF NO REMOVE IT
					{
						# Boxed category navigation under LHM and collection of Menu 2 Header & Block
						while($first_part_category_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/igs) ## Second down category
						{
							my $menu2_part_name=Trim($1);
							my $menu2_block=$2;
							
							# Skipping the Learn More
							if($menu2_part_name=~m/^\s*Learn\s*More\s*$/is)
							{
								next;
							}	
								
							# Extraction of the Menu 2 URL and menu 2 name			
							while($menu2_block=~m/<li><a\s*[^>]*?href\=\"([^>]*?)\">([^>]*?)<\/a>\s*<\/li>/igs)
							{
								my $menu2_url=$1; 
								my $menu2_name=Trim($2);
																	
								unless($menu2_url=~m/^\s*http\:/is)
								{
									$menu2_url='http://www.walmart.com/'.$menu2_url;
								}
								
								my $menu3_url_content=$utilityobject->Lwp_Get($menu2_url);
	
								# Extraction of Menu 2 header and Menu 2 Block from Level 3 navigation
								while($menu3_url_content=~m/<div\s*class\s*=\"Header\">\s*([^>]*?)<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>\s*<\/div>/igs) ## Second down category
								{
									my $menu23_part_name=Trim($1);
									my $menu23_block=$2;
									
									# Skipping the learn more
									if($menu23_part_name=~m/^\s*Learn\s*More\s*$/is)
									{
										next;
									}
									
									# Extraction of the Menu2 name and Menu2 URL
									while($menu23_block=~m/<li><a\s*[^>]*?href\=\"([^>]*?)\">([^>]*?)<\/a>\s*<\/li>/igs)
									{
										my $menu23_url=$1; 
										my $menu23_name=Trim($2);
																			
										unless($menu23_url=~m/^\s*http\:/is)
										{
											$menu23_url='http://www.walmart.com/'.$menu23_url;
										}
										
										my $menu321_url_content=$utilityobject->Lwp_Get($menu23_url);

										# Navigation to all departments and extraction of category header and category block from next level navigation if the 
										if($menu321_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is) ### Data have another more navigations ----- IT STOPPED HERE #####
										{
											my $menu21_part_name=Trim($1);
											my $menu21_block=$2;
											
											# Extraction of Menu 3 URL and Menu 3 name
											while($menu21_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
											{												
												my $menu31_url=$1; 
												my $menu31_name=Trim($2);
												
												# Skipping the Learn more
												if($menu21_part_name=~m/^\s*Learn\s*More\s*$/is)
												{
													next;
												}
												
												unless($menu31_url=~m/^\s*http\:/is)
												{
													$menu31_url='http://www.walmart.com/'.$menu31_url;
												}

												my $menu31_url_content=$utilityobject->Lwp_Get($menu31_url);
												
												# Intimates menu navigation
												if(($menu31_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))	### Changes Done here
												{
													my $Intimates_content1 = $menu31_url_content;

													# Extraction of the Menu 4 Header and filter block
													while($Intimates_content1=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
													{
														my $Menu41_part_name=Trim($1);
														my $block_filter1=$2;

														# Extraction of the category URL and Category Name	
														while($block_filter1=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
														{
															my $Category_url11=$1;
															my $menu_41=Trim($2);
															
															$menu_41=~s/<[^>]*?>/ /igs;
															$menu_41=~s/&nbsp/ /igs;
															$menu_41=~s/\s+/ /igs;
															$menu_41=~s/^\s+|\s+$//igs;

															unless($Category_url11=~m/^\s*http\:/is)
															{
																$Category_url11='http://www.walmart.com'.$Category_url11;
															}
															
															my $menu41_url_content=$utilityobject->Lwp_Get($Category_url11);
															
															# Calling the go_LHM1 function to naviagte additional Left hand menu 
															&go_LHM1($menu41_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu21_part_name,$menu31_name,$Menu41_part_name,$menu_41,$menu31_url);
														}
													}
												}
												else
												{	
													# Calling the go_LHM1 function to naviagte additional Left hand menu 
													&go_LHM1($menu31_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu21_part_name,$menu31_name,"","",$menu31_url);
												}																							
											}
										}
										else
										{
											# Calling the go_LHM1 function to naviagte additional Left hand menu 
											&go_LHM1($menu321_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu23_part_name,$menu23_name,"","",$menu2_url);
										}
									}
								}
											
								# Boxed category naviagtion under the Menu 2/ Extraction of Menu 3 Header
								if($menu3_url_content=~m/<div\s*id\=\"SRNode_root\"><[^>]*?>([^>]*?)<\/a><\/div>[\w\W]*?<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\!\-\-\s*end\:\s*not\s*empty\s*navDataList\s*\-\->/is) ### Data have another more navigations ----- IT STOPPED HERE #####
								{
									my $menu23_part_name=Trim($1);
									my $menu23_block=$2;
									
									# Extraction of the Menu 3 block and Menu 3 name
									while($menu23_block=~m/<a\s*class[^>]*?href\=\"([^>]*?)\"\s*[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
									{										
										my $menu32_url=$1;
										my $menu32_name=Trim($2);
									
										if($menu23_part_name=~m/^\s*Learn\s*More\s*$/is) 
										{
											next;
										}
										
										unless($menu32_url=~m/^\s*http\:/is)
										{
											$menu32_url='http://www.walmart.com/'.$menu32_url;
										}

										my $menu32_url_content=$utilityobject->Lwp_Get($menu32_url);
										
										# Intimates navigation under Women's
										if(($menu32_name=~m/^\s*Intimates[^>]*?$/is)&&($first_part_name=~m/^\s*Women\'s\s*$/is))
										{
											my $Intimates_content1 = $menu32_url_content;
										
											#  Extraction of the Menu 4 and Filter block
											while($Intimates_content1=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
											{
												my $Menu41_part_name=Trim($1);
												my $block_filter1=$2;
												
												# Extraction of the category URL and menu 4
												while($block_filter1=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
												{
													my $Category_url11=$1;
													my $menu_41=Trim($2);
													
													$menu_41=~s/<[^>]*?>/ /igs;
													$menu_41=~s/&nbsp/ /igs;
													$menu_41=~s/\s+/ /igs;
													$menu_41=~s/^\s+|\s+$//igs;

													unless($Category_url11=~m/^\s*http\:/is)
													{
														$Category_url11='http://www.walmart.com'.$Category_url11;
													}
													
													my $menu41_url_content=$utilityobject->Lwp_Get($Category_url11);
													
													# Calling the go_LHM1 function to naviagte additional Left hand menu 
													&go_LHM1($menu41_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu23_part_name,$menu32_name,$Menu41_part_name,$menu_41,$Category_url11);	 ### Chanaged here 	
												}
											}
										}
										else
										{	
											# Calling the go_LHM1 function to naviagte additional Left hand menu 
											&go_LHM1($menu32_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,$menu23_part_name,$menu32_name,"","",$menu32_url); ### Chanaged here 
										}
									}
								}
								else
								{
									# Calling the go_LHM1 function to naviagte additional Left hand menu 
									&go_LHM1($menu3_url_content,$Menu1,$main_category_name,$first_part_name,$menu2_part_name,$menu2_name,"","","","",$menu2_url);
								}
							}
						}						
					}
					else
					{	
						# Calling the go_LHM1 function to naviagte additional Left hand menu 
						&go_LHM1($first_part_category_url_content,$Menu1,$main_category_name,$first_part_name,"","","","","","",$first_part_category_url);
					}					
				} 
			}
		}
	}
	else
	{
		print "\nMenu1 regex not match";
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

# Left hand menu navigations Subroutine
sub go_LHM1
{
	my $menu3_url_content=shift; 
	my $menu_1=shift;
	my $main_category_name1=shift;
	my $menu_2=shift;
	my $menu_3_header=shift;
	my $menu_3=shift;
	my $menu_4_header=shift;
	my $menu_4=shift;
	my $menu_41_header=shift;
	my $menu_41=shift;
	my $menu_3_url=shift;
	
	my $list_page_url;
	my $Walmart_brand_flag=0;
	
	# Added to navigate only the walmart.com products	
	if($menu3_url_content=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?Retailer\s*[^>]*?)<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/is)
	{
		my $retailer_block=$2;
		
		if($retailer_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*(Walmart\.com[^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/is)
		{
			my $walmart_brand=$1;
			unless($walmart_brand=~m/^\s*http\:/is)
			{
				$walmart_brand='http://www.walmart.com'.$walmart_brand;
			}
			$menu3_url_content=$utilityobject->Lwp_Get($walmart_brand);
			$Walmart_brand_flag=1;
		}
	}
	
	next_page6:
					
	while($menu3_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
	{
		my $product_url=$1;
		
		unless($product_url=~m/^\s*http\:/is)
		{
			$product_url='http://www.walmart.com'.$product_url;
		}
			
		my $product_id;
		if($product_url=~m/^[^>]*?\/([\d]+)$/is)
		{
			$product_id=$1;
		}
		elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
		{
			$product_id=$1;
		}
		
		# To insert product URL into table on checking the product is not available already		
		my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
		
		# Saving the tag information.
		$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
		$dbobject->SaveTag('Menu_2',$main_category_name1,$product_object_key,$robotname,$Retailer_Random_String);
		$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
		
		if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
		{
			$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
		}
		if(($menu_4_header!~m/^\s*$/is)&&($menu_4!~m/^\s*$/is))
		{
			$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
		}
		if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
		{
			$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		# Commiting the dbobject
		$dbobject->commit();
	}						
		
	if($menu3_url_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
	{
		$list_page_url=$1;
		
		unless($list_page_url=~m/^\s*http\:/is)
		{
			$list_page_url='http://www.walmart.com'.$list_page_url;
		}
		
		$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
		goto next_page6;
	}
	elsif($menu3_url_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
	{
		$list_page_url=$1;
		unless($list_page_url=~m/^\s*http\:/is)
		{
			$list_page_url='http://www.walmart.com'.$list_page_url;
		}
				
		$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
		goto next_page6;
	}	
	

	# To stop navigating to main categories again to avoid unwanted looping
	if(($menu_3_header=~m/^\s*Special\s*Offers\s*/is)&&($menu_3=~m/\s*Clearance\s*/is))
	{
		goto listing_direct;
	}	
	
	# Navigation of featured shop basic menu only
	if($menu3_url_content!~m/<div\s*class\=\"BodyLBold\s*SRModTitle[^>]*?>Refine\s*Results<\/div>/is) 
	{
		# Collection of Menu 5 and Block
		while($menu3_url_content=~m/<div\s*class\=\"yuimenuitemlabel\s*browseInOuter\">([\w\W]*?)<\/div>/igs)
		{
			my $Menu6_name=Trim($1);
			my $Menu6_navigation_block=$2;
			
			# Collection of Menu 3 URL and Menu 3 name in Level 3
			if($Menu6_navigation_block=~m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^<]*?)\s*</is) 
			{				
				my $menu32_url=$1;
				my $menu32_name=Trim($2);
				
				unless($menu32_url=~m/^\s*http\:/is)
				{
					$menu32_url='http://www.walmart.com/'.$menu32_url;
				}

				my $menu32_url_content=$utilityobject->Lwp_Get($menu32_url);

				# Intimates menu navigation
				if(($menu32_name=~m/^\s*Intimates[^>]*?$/is)&&($menu_2=~m/^\s*Women\'s\s*$/is))
				{
					my $Intimates_content2 = $menu32_url_content;

					# Menu 4 header and filter block	
					while($Intimates_content2=~m/<div\s*class\=\"Header\">\s*([^>]*?)\s*<\/div>\s*<ul\s*class\=\"NoBullet\">([\w\W]*?)<\/ul>/igs)
					{
						my $Menu42_part_name=Trim($1);
						my $block_filter2=$2;
						
						# Extraction of the Category URL and Menu 4
						while($block_filter2=~m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $Category_url12=$1;
							my $menu_42=Trim($2);
							
							$menu_42=~s/<[^>]*?>/ /igs;
							$menu_42=~s/&nbsp/ /igs;
							$menu_42=~s/\s+/ /igs;
							$menu_42=~s/^\s+|\s+$//igs;
							
							unless($Category_url12=~m/^\s*http\:/is)
							{
								$Category_url12='http://www.walmart.com'.$Category_url12;
							}
							
							my $menu42_url_content=$utilityobject->Lwp_Get($Category_url12);
							
							# Calling the go_LHM function to naviagte additional Left hand menu
							&go_LHM($menu42_url_content,$menu_1,$main_category_name1,$menu_2,$menu_3_header,$menu_3,$menu_4_header,$menu_4,$menu_41_header,$menu_41,$Menu6_name,$menu32_name,$Menu42_part_name,$menu_42,$menu32_url,$Walmart_brand_flag);													
						}
					}
				}
				else
				{	
					# Calling the go_LHM function to naviagte additional Left hand menu
					&go_LHM($menu32_url_content,$menu_1,$main_category_name1,$menu_2,$menu_3_header,$menu_3,$menu_4_header,$menu_4,$menu_41_header,$menu_41,$Menu6_name,$menu32_name,"","",$menu32_url,$Walmart_brand_flag);					
				}			
			}	
		} 
	}
		
	goto listing_direct; # Bypassing Results\s*by\s*Department

	# Simple Menu navigation /  Extraction of department Header and block
	if($menu3_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle\">\s*(Results\s*by\s*Department)\s*<\/div>([\w\W]*?)<\/ul>\s*<\/div>/is)
	{	
		my $Department_header=Trim($1);
		my $Department_block=$2;
		
		# Extraction of Department URL and department name
		while($Department_block=~m/<a[^>]*?\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*(?:<strong>[^>]*?<\/strong>)?<\/a>\s*<\/li>/igs)
		{
			my $Department_url=$1;
			my $Department_name=Trim($2);
			
			unless($Department_url=~m/^\s*http\:/is)
			{
				$Department_url='http://www.walmart.com'.$Department_url;
			}
					
			my $Department_url_content=$utilityobject->Lwp_Get($Department_url);
			
			# To navigate directly to Filters and products page
			if($Department_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle[^>]*?>Refine\s*Results<\/div>([\w\W]*?)<\/html>/is)
			{
				my $Refine_Results_block=$1;
				
				# Extraction of Filter header name and block
				while($Refine_Results_block=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?)\s*<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/igs)
				{
					my $filter_head_name=Trim($1); 
					my $filter_block=$2;
					
					# Skipping the Search filters
					if($filter_block=~m/(class\=\"AdvSearchFilter[^>]*?_selected|AdvSearchListing\s*selectedFilter)/is)
					{
						next;
					}
					
					# Skippinf the Size, Price, Customer rating, clothing size and Retailer
					if($filter_head_name=~m/^\s*Size\s*|^\s*Price\s*|^\s*Customer\s*Rating\s*|^\s*Clothing\s*Size\s*|^\s*Pant\s*Size\s*|^\s*Retailer\s*/is)#### Letting the Brand to Go
					{
						next;
					}
					
					# Collection of filter URL and filter name
					while($filter_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*([^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/igs) ### Regex changed to match all the Blocks including Color Blocks
					{
						my $filter_url=$1;
						my $filter_name=Trim($2);

						$filter_name=~s/\s*;|\s*;\s*$/ /igs;
						$filter_name=~s/\([\d]+?\)/ /igs;
						$filter_name=~s/\s+/ /igs;
						$filter_name=~s/^\s+|\s+$//igs;
						
						# skipping the Filter, if matching with menu 3 or menu 4, which mean the menu is selected or navigated
						if(($filter_name=~m/^\s*$menu_3\s*$/is)||($filter_name=~m/^\s*$menu_4\s*$/is))
						{
							next;
						}
						
						# Skipping the unwanted filter name
						if(($filter_name=~m/^\s*see\s*fewer\s*|^see\s*[^>]*?more\s*/is)&&($filter_head_name=~m/^\s*color\s*/is))
						{
							next;
						}
						
						unless($filter_url=~m/^\s*http\:/is)
						{
							$filter_url='http://www.walmart.com'.$filter_url;
						}

						next_page:
						
						my $filter_url_content=$utilityobject->Lwp_Get($filter_url);

						# Collecting the Product URL
						while($filter_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
						{
							my $product_url=$1;
							
							unless($product_url=~m/^\s*http\:/is)
							{
								$product_url='http://www.walmart.com'.$product_url;
							}
							
							# Extraction of Product ID
							my $product_id;
							if($product_url=~m/^[^>]*?\/([\d]+)$/is) 
							{
								$product_id=$1;
							}
							elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
							{
								$product_id=$1;
							}

							# To insert product URL into table on checking the product is not available already
							my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);

							# Saving the tag information.
							$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
							$dbobject->SaveTag('Menu_2',$main_category_name1,$product_object_key,$robotname,$Retailer_Random_String);
							$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
							
							if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
							{								
								$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($menu_4_header!~m/^\s*$/is)&&($menu_4!~m/^\s*$/is))
							{
								$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
							{
								$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
							}
							
							if($Department_name!~m/^\s*$/is)
							{
								$dbobject->SaveTag('Menu_5',$Department_name,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($filter_head_name!~m/^\s*$/is)&&($filter_name!~m/^\s*$/is))
							{
								$dbobject->SaveTag($filter_head_name,$filter_name,$product_object_key,$robotname,$Retailer_Random_String);
							}
							
							# Committing the transaction.
							$dbobject->commit();
						}						
						my $list_page_content=$filter_url_content;
							
						if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
						{
							$list_page_url=$1;
							unless($list_page_url=~m/^\s*http\:/is)
							{
								$list_page_url='http://www.walmart.com'.$list_page_url;
							}
							$filter_url=$list_page_url;
							goto next_page;
						}
						elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
						{
							$list_page_url=$1;
							unless($list_page_url=~m/^\s*http\:/is)
							{
								$list_page_url='http://www.walmart.com'.$list_page_url;
							}
							$filter_url=$list_page_url;
							
							goto next_page;
						}							
					}
				}					
			}
		}
	}
	else
	{
		listing_direct:
		# Isolating the Block for filters
		if($menu3_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle[^>]*?>\s*Refine\s*Results\s*<\/div>([\w\W]*?)<\/html>/is)
		{
			my $Refine_Results_block=$1; 
			
			# Extraction of the Header for Filters and filter block
			while($Refine_Results_block=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?)\s*<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/igs)
			{
				my $filter_head_name=Trim($1); 
				my $filter_block=$2;
	
				if($filter_block=~m/(class\=\"AdvSearchFilter[^>]*?_selected|AdvSearchListing\s*selectedFilter)/is) ### It needs to be removed and the $filterheadname should come into products
				{
					next;
				}
				 
				# Skipping the Size, Price 
				if($filter_head_name=~m/^\s*Size\s*|^\s*Price\s*|^\s*Customer\s*Rating\s*|^\s*Clothing\s*Size\s*|^\s*Pant\s*Size\s*|^\s*Retailer\s*/is)
				{
					next;
				}
				
				while($filter_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*([^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/igs) ### Regex changed to match all the Blocks including Color Blocks
				{
					my $filter_url=$1;
					my $filter_name=Trim($2);
					
					$filter_name=~s/\s*;|\s*;\s*$/ /igs;
					$filter_name=~s/\([\d]+?\)/ /igs;
					$filter_name=~s/\s+/ /igs;
					$filter_name=~s/^\s+|\s+$//igs;
					
					if($filter_name=~m/^\s*$menu_3\s*$/is)
					{
						next;
					}
					
					if(($filter_name=~m/^\s*see\s*fewer\s*|^see\s*[^>]*?more\s*/is)&&($filter_head_name=~m/^\s*color\s*/is))
					{
						next;
					}
					
					unless($filter_url=~m/^\s*http\:/is)
					{
						$filter_url='http://www.walmart.com'.$filter_url;
					}
					
					next_page1:
					
					my $filter_url_content=$utilityobject->Lwp_Get($filter_url);
					
					# Collection of product URL
					while($filter_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
					{
						my $product_url=$1;
						
						unless($product_url=~m/^\s*http\:/is)
						{
							$product_url='http://www.walmart.com'.$product_url;
						}
						
						# Extraction of the Product ID
						my $product_id;
						if($product_url=~m/^[^>]*?\/([\d]+)$/is)  ### Unique ID Creation
						{
							$product_id=$1;
						}
						elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
						{
							$product_id=$1;
						}
						
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						# Saving the tag information.						
						$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_2',$main_category_name1,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
						if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
						{
							$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
						}
						if($menu_4 ne '')
						{
							$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
						}
						if($menu_41_header ne '')
						{
							$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
						}								
						
						if(($filter_head_name!~m/^\s*$/is)&&($filter_name!~m/^\s*$/is))
						{
							$dbobject->SaveTag($filter_head_name,$filter_name,$product_object_key,$robotname,$Retailer_Random_String);
						}
						
						# Committing the transaction.
						$dbobject->commit();
					}
					my $list_page_content=$filter_url_content;
					if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
					{
						$list_page_url=$1;
						unless($list_page_url=~m/^\s*http\:/is)
						{
							$list_page_url='http://www.walmart.com'.$list_page_url;
						}
						$filter_url=$list_page_url;
						goto next_page1;
					}
					elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
					{
						$list_page_url=$1;
						unless($list_page_url=~m/^\s*http\:/is)
						{
							$list_page_url='http://www.walmart.com'.$list_page_url;
						}
											
						$filter_url=$list_page_url;
						goto next_page1;
					}							
				}
			}			
		}
		else
		{				
			next_page5:
			
			# Extraction of Product URL
			while($menu3_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
			{
				my $product_url=$1;
				
				unless($product_url=~m/^\s*http\:/is)
				{
					$product_url='http://www.walmart.com'.$product_url;
				}
				
				# Extraction of product ID
				my $product_id;
				if($product_url=~m/^[^>]*?\/([\d]+)$/is)  ### Unique ID Creation
				{
					$product_id=$1;
				}
				elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
				{
					$product_id=$1;
				}
				
				# To insert product URL into table on checking the product is not available already
				my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				
				# Saving the tag information.
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_2',$main_category_name1,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
				if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
				{
					$dbobject->SaveTag($menu_3_header,$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
				}
				if(($menu_4_header!~m/^\s*$/is)&&($menu_4!~m/^\s*$/is))
				{
					$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
				}
				if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
				{
					$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				# Committing the transaction.
				$dbobject->commit();
			}
			
			# Next page navigations
			my $list_page_content=$menu3_url_content;
			if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
			{
				$list_page_url=$1;
				unless($list_page_url=~m/^\s*http\:/is)
				{
					$list_page_url='http://www.walmart.com'.$list_page_url;
				}
								
				$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
				goto next_page5;
			}
			elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
			{
				$list_page_url=$1;
				unless($list_page_url=~m/^\s*http\:/is)
				{
					$list_page_url='http://www.walmart.com'.$list_page_url;
				}
				
				$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
				goto next_page5;	
			}
		}
	}
}

# Value Cleaning Module
sub Trim
{
	my $value=shift;
	$value=~s/<[^>]*?>//igs;
	$value=~s/\&amp\;/&/igs;
	$value=~s/\&amp/&/igs;
	$value=~s/\&nbsp/ /igs;
	$value=~s/\&nbsp\;/ /igs;	
	$value=~s/\s+/ /igs;
	$value=~s/^\s+|\s+$//igs;
	$value=decode_entities($value);
	utf8::decode($value); 	
	return($value);	
}

# Calling LHM (Filter) Module type 2
sub go_LHM
{
	my $menu3_url_content=shift;
	my $menu_1=shift;
	my $menu_11=shift;
	my $menu_2=shift;
	my $menu_3_header=shift;
	my $menu_3=shift;
	my $menu_4_header=shift;
	my $menu_4=shift;
	my $menu_41_header=shift;
	my $menu_41=shift;
	my $menu_42_header=shift;
	my $menu_42=shift;
	my $menu_3_url=shift;
	my $Walmart_brand_flag1=shift; 
	my $list_page_url;

	# Added to navigate only the walmart.com products
	if($Walmart_brand_flag1!=1)
	{
		if($menu3_url_content=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?Retailer\s*[^>]*?)<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/is)
		{
			my $retailer_block=$2;		
			if($retailer_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*(Walmart\.com[^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/is)
			{
				my $walmart_brand=$1;
				unless($walmart_brand=~m/^\s*http\:/is)
				{
					$walmart_brand='http://www.walmart.com'.$walmart_brand;
				}
				$menu3_url_content=$utilityobject->Lwp_Get($walmart_brand);			
			}
		}
	}
		
	next_page7:		
		
	while($menu3_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
	{
		my $product_url=$1;
		
		unless($product_url=~m/^\s*http\:/is)
		{
			$product_url='http://www.walmart.com'.$product_url;
		}
		
		# Extraction of Product ID
		my $product_id;
		if($product_url=~m/^[^>]*?\/([\d]+)$/is) 
		{
			$product_id=$1;
		}
		elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
		{
			$product_id=$1;
		}
		
		# To insert product URL into table on checking the product is not available already
		my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
		
		# Saving the tag information.
		$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
		$dbobject->SaveTag('Menu_2',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
		$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);

		if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
		{
			$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
		}
		if(($menu_4_header!~m/^\s*$/is)&&($menu_4!~m/^\s*$/is))
		{
			$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
		}
		if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
		{
			$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
		}
		if(($menu_42_header!~m/^\s*$/is)&&($menu_42!~m/^\s*$/is))
		{
			$dbobject->SaveTag($menu_42_header,$menu_42,$product_object_key,$robotname,$Retailer_Random_String);
		}
		
		# Committing the transaction.		
		$dbobject->commit();
	}
	
	if($menu3_url_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
	{
		$list_page_url=$1;
		unless($list_page_url=~m/^\s*http\:/is)
		{
			$list_page_url='http://www.walmart.com'.$list_page_url;
		}
		
		$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
		goto next_page7;
	}
	elsif($menu3_url_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
	{
		$list_page_url=$1;
		unless($list_page_url=~m/^\s*http\:/is)
		{
			$list_page_url='http://www.walmart.com'.$list_page_url;
		}
				
		$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
		goto next_page7;	
	}
	
	# To stop navigating to the Top LHM , when the Menu header is Special Offers and Clearence
	if(($menu_3_header=~m/^\s*Special\s*Offers\s*/is)&&($menu_3=~m/\s*Clearance\s*/is))
	{
		goto listing_direct1;
	}
	
	goto listing_direct1;  # Bypassing Results\s*by\s*Department
	if($menu3_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle\">\s*(Results\s*by\s*Department)\s*<\/div>([\w\W]*?)<\/ul>\s*<\/div>/is)
	{
		my $Department_header=Trim($1);
		my $Department_block=$2;
		
		while($Department_block=~m/<a[^>]*?\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*(?:<strong>[^>]*?<\/strong>)?<\/a>\s*<\/li>/igs)
		{
			my $Department_url=$1;
			my $Department_name=Trim($2);
			
			unless($Department_url=~m/^\s*http\:/is)
			{
				$Department_url='http://www.walmart.com'.$Department_url;
			}
					
			my $Department_url_content=$utilityobject->Lwp_Get($Department_url);
			
			# Navigating to Department Filter Results
			if($Department_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle[^>]*?>Refine\s*Results<\/div>([\w\W]*?)<\/html>/is)
			{
				my $Refine_Results_block=$1;
				
				# Extraction of the filter header
				while($Refine_Results_block=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?)\s*<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/igs)
				{
					my $filter_head_name=Trim($1);
					my $filter_block=$2;
					
					if($filter_block=~m/(class\=\"AdvSearchFilter[^>]*?_selected|AdvSearchListing\s*selectedFilter)/is)
					{
						next;
					}
						
					if($filter_head_name=~m/^\s*Size\s*|^\s*Price\s*|^\s*Customer\s*Rating\s*|^\s*Clothing\s*Size\s*|^\s*Pant\s*Size\s*|^\s*Retailer\s*/is)
					{
						next;
					}
					
					# Extraction of the filter url and name
					while($filter_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*([^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/igs) ### Regex changed to match all the Blocks including Color Blocks
					{
						my $filter_url=$1;
						my $filter_name=Trim($2);
						
						$filter_name=~s/\s*;|\s*;\s*$/ /igs;
						$filter_name=~s/\([\d]+?\)/ /igs;
						$filter_name=~s/\s+/ /igs;
						$filter_name=~s/^\s+|\s+$//igs;
						
						# Skipping the menu 3 and menu 4
						if(($filter_name=~m/^\s*$menu_3\s*$/is)||($filter_name=~m/^\s*$menu_4\s*$/is))
						{
							next;
						}

						# skipping the unwanted filter name
						if(($filter_name=~m/^\s*see\s*fewer\s*|^see\s*[^>]*?more\s*/is)&&($filter_head_name=~m/^\s*color\s*/is))
						{
							next;
						}

						unless($filter_url=~m/^\s*http\:/is)
						{
							$filter_url='http://www.walmart.com'.$filter_url;
						}

						next_page2:
						
						my $filter_url_content=$utilityobject->Lwp_Get($filter_url); 

						# Extration of the product URL 
						while($filter_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
						{
							my $product_url=$1;
							
							unless($product_url=~m/^\s*http\:/is)
							{
								$product_url='http://www.walmart.com'.$product_url;
							}
							
							# Extraction of the product id from product URL
							my $product_id;
							if($product_url=~m/^[^>]*?\/([\d]+)$/is)  ### Unique ID Creation
							{
								$product_id=$1;
							}
							elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
							{
								$product_id=$1;
							}
							
							# To insert product URL into table on checking the product is not available already
							my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
							
							# Saving the tag information.
							$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
							$dbobject->SaveTag('Menu_2',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
							$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
							
							if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
							{
								$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String); 
							}
							if(($menu_4_header!~m/^\s*$/is)&&($menu_4!~m/^\s*$/is))
							{
								$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
							{
								$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($menu_42_header!~m/^\s*$/is)&&($menu_42!~m/^\s*$/is))
							{
								$dbobject->SaveTag($menu_42_header,$menu_42,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if($Department_name!~m/^\s*$/is)
							{
								$dbobject->SaveTag('Menu_5',$Department_name,$product_object_key,$robotname,$Retailer_Random_String);
							}
							if(($filter_head_name!~m/^\s*$/is)&&($filter_name!~m/^\s*$/is))
							{
								$dbobject->SaveTag($filter_head_name,$filter_name,$product_object_key,$robotname,$Retailer_Random_String);
							}
							
							# Committing the transaction.
							$dbobject->commit();
						}
						
						my $list_page_content=$filter_url_content;
						
						if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
						{
							$list_page_url=$1;
							unless($list_page_url=~m/^\s*http\:/is)
							{
								$list_page_url='http://www.walmart.com'.$list_page_url;
							}
							$filter_url=$list_page_url;
							goto next_page2;
						}
						elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
						{
							$list_page_url=$1;
							unless($list_page_url=~m/^\s*http\:/is)
							{
								$list_page_url='http://www.walmart.com'.$list_page_url;
							}
							$filter_url=$list_page_url;
							
							goto next_page2;	
						}
					}
				}					
			}
		}
	}
	else
	{	
		listing_direct1:
		# Extraction of the Filter Block
		if($menu3_url_content=~m/<div\s*class\=\"BodyLBold\s*SRModTitle[^>]*?>Refine\s*Results<\/div>([\w\W]*?)<\/html>/is)
		{
			my $Refine_Results_block=$1; 
			# Extraction of filter header and its sub block from filter block
			while($Refine_Results_block=~m/<h6\s*class\=\"AdvSearchSubhead">\s*<[^>]*?>\s*<[^>]*?>([^>]*?)\s*<\/a>\s*<\/h6>([\w\W]*?)<\/ul>\s*<\/div>/igs)
			{
				my $filter_head_name=Trim($1); 
				my $filter_block=$2;
				
				# Exclude the search box pattern matching
				if($filter_block=~m/(class\=\"AdvSearchFilter[^>]*?_selected|AdvSearchListing\s*selectedFilter)/is)
				{
					next;
				}
				# Skipping the Size/ price/ Rating
				if($filter_head_name=~m/^\s*Size\s*|^\s*Price\s*|^\s*Customer\s*Rating\s*|^\s*Clothing\s*Size\s*|^\s*Pant\s*Size\s*|^\s*Retailer\s*/is)
				{
					next;
				}
				
				# Extraction of filter url and filter name
				while($filter_block=~m/<a\s*href\=\"([^>]*?)\"[\w\W]*?\">(?:<img[^>]*?>)?\s*([^>]*?)\s*(?:<span\s*class\=\"count\">[^>]*?<\/span>)?\s*<\/a>/igs) ### Regex changed to match all the Blocks including Color Blocks
				{
					my $filter_url=$1;
					my $filter_name=Trim($2);
					
					$filter_name=~s/\s*;|\s*;\s*$/ /igs;
					$filter_name=~s/\([\d]+?\)/ /igs;
					$filter_name=~s/\s+/ /igs;
					$filter_name=~s/^\s+|\s+$//igs;
					
					# Skipping if the filter name equals menu 3, which means Looping again to menu 3
					if($filter_name=~m/^\s*$menu_3\s*$/is)
					{
						next;
					}
						
					# Skipping the unwanted all products listing menu
					if(($filter_name=~m/^\s*see\s*fewer\s*|^see\s*[^>]*?more\s*/is)&&($filter_head_name=~m/^\s*color\s*/is))
					{
						next;
					}
					
					unless($filter_url=~m/^\s*http\:/is)
					{
						$filter_url='http://www.walmart.com'.$filter_url;
					}
							
					
					next_page3:
					
					# Extracting the Source from the URL
					my $filter_url_content=$utilityobject->Lwp_Get($filter_url);
					
					# Extraction of the product URL	
					while($filter_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
					{
						my $product_url=$1;
						
						# Framing the URL with HTTP
						unless($product_url=~m/^\s*http\:/is)
						{
							$product_url='http://www.walmart.com'.$product_url;
						}
		
						# COllection of the product ID from Product URL
						my $product_id;
						if($product_url=~m/^[^>]*?\/([\d]+)$/is)  ### Unique ID Creation
						{
							$product_id=$1;
						}
						elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
						{
							$product_id=$1;
						}
		
						# To insert product URL into table on checking the product is not available already
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						# Saving the tag information.
						$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_2',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
		
						if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is)) ## Menu_4
						{
							$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
						}
						if($menu_4!~m/^\s*$/is)
						{
							$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
						}
						if($menu_41_header!~m/^\s*$/is)
						{
							$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
						}														
						if(($filter_head_name!~m/^\s*$/is)&&($filter_name!~m/^\s*$/is))
						{
							$dbobject->SaveTag($filter_head_name,$filter_name,$product_object_key,$robotname,$Retailer_Random_String);
						}
						
						# Committing the transaction.
						$dbobject->commit();
					}
					
					# Next page navigation
					my $list_page_content=$filter_url_content;
					if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
					{
						$list_page_url=$1;
						unless($list_page_url=~m/^\s*http\:/is)
						{
							$list_page_url='http://www.walmart.com'.$list_page_url;
						}
						$filter_url=$list_page_url;
						goto next_page3;
					}
					elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
					{
						$list_page_url=$1;
						unless($list_page_url=~m/^\s*http\:/is)
						{
							$list_page_url='http://www.walmart.com'.$list_page_url;
						}
						$filter_url=$list_page_url;
						
						goto next_page3;	
					}		
				}
			}
		}
		else
		{				
			next_page4:
			# Extraction of the product URL		
			while($menu3_url_content=~m/<a\s*class\=\"prodLink\s*ListItemLink\"\s*href\=\"([^>]*?)\"/igs)
			{
				my $product_url=$1;
				
				# Framing the URL with HTTP
				unless($product_url=~m/^\s*http\:/is)
				{
					$product_url='http://www.walmart.com'.$product_url;
				}
				
				# COllection of the product ID from Product URL
				my $product_id;
				if($product_url=~m/^[^>]*?\/([\d]+)$/is)
				{
					$product_id=$1;
				}
				elsif($product_url=~m/^[^>]*?\/([\d]+)\?[^>]*?$/is)
				{
					$product_id=$1;
				}

				# To insert product URL into table on checking the product is not available already 
				my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				
				# Saving the tag information.
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);				
				$dbobject->SaveTag('Menu_2',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_3',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);

				if(($menu_3_header!~m/^\s*$/is)&&($menu_3!~m/^\s*$/is))
				{					
					$dbobject->SaveTag('Menu_4',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				if(($menu_4!~m/^\s*$/is)&&($menu_4_header!~m/^\s*$/is))
				{
					$dbobject->SaveTag($menu_4_header,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
				}
				if(($menu_41_header!~m/^\s*$/is)&&($menu_41!~m/^\s*$/is))
				{
					$dbobject->SaveTag($menu_41_header,$menu_41,$product_object_key,$robotname,$Retailer_Random_String);
				}								
				
				# Committing the transaction.
				$dbobject->commit();
			}
			
			# Next page navigation
			my $list_page_content=$menu3_url_content;
			if($list_page_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*Next\s*<\/a>/is)
			{
				$list_page_url=$1;
				unless($list_page_url=~m/^\s*http\:/is)
				{
					$list_page_url='http://www.walmart.com'.$list_page_url;
				}
				
				$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
				goto next_page4;
			}
			elsif($list_page_content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"jump\s*next\">\s*Next\s*<div\s*class/is)
			{
				$list_page_url=$1;
				unless($list_page_url=~m/^\s*http\:/is)
				{
					$list_page_url='http://www.walmart.com'.$list_page_url;
				}
				
				$menu3_url_content=$utilityobject->Lwp_Get($list_page_url);
				goto next_page4;	
			}								
		}
	}
	
	# undefining the flags used
	undef($Walmart_brand_flag1);
}
