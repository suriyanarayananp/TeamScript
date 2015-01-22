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
my $Retailer_Random_String='Mat';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;

# User Agent
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)"); ## UPON MARTIN__WGSN APPROVAL
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

my $url = 'http://www.matchesfashion.com/';
my $content =$utilityobject->Lwp_Get($url);

# Extracting Mens / Womens menu
while($content=~m/<h2>\s*<a\s*href\=\"([^>]*?)\"\s*class\=\"([^>]*?)\"\s*title\=/igs) 
{
	my $url=$1;
	my $menu0=Trim(uc($2));
	$menu0=~s/s$//is;
	
	# Skipping the menu 1 if it is not the passed argument
	next unless($menu0=~m/^\s*$ARGV[0]\s*$/is);
	
	# URL framing
	unless($url=~m/^\s*http\:/is)
	{
		$url='http://www.matchesfashion.com'.$url;
	}
	
	# Fetching the URL content
	my $content =$utilityobject->Lwp_Get($url);
	
	# Crawling Top first menu
	while($content=~m/\s+<a\s*href\=\"([^>]*?)\"\s*class\=\"menuTrigger[^>]*?\">([^>]*?)<\/a>/igs)
	{
		my $Menu1_url=$1;
		my $Menu1=Trim($2);
		
		# Skipping the top first menu if it is not the passed argument
		next unless($Menu1=~m/^\s*$ARGV[1]\s*$/is);
		
		# Skipping the top first menu if the menu is The Style Report
		next if($Menu1=~m/\s*The\s*Style\s*Report\s*/is);
		my $Menu1_text=$Menu1;
		
		# Forming the URL
		unless($Menu1_url=~m/^\s*http\:/is)
		{
			$Menu1_url='http://www.matchesfashion.com'.$Menu1_url;
		}
		
		# Temporary Hardcoding the Menu1 if the Menu is Holiday shop to extract the menu 1 content block
		$Menu1_text= 'STUDIOS' if($Menu1_text=~m/\s*HOLIDAY\s*SHOP\s*/is);	
		$Menu1_text=~s/\s+/\\s*/igs;
		
		&filter_navigation($Menu1_url,$menu0,$Menu1,"","");
		
		# Extracting the Menu 1 content block 
		if($content=~m/<\!\-\-\s*start\s*($Menu1_text)\s*\-\->([\w\W]*?)<\!\-\-\s*end\s*($Menu1_text)\s*\-\->/is)
		{
			my $Menu1_Block=$2;
			
			# Checking the condition to enter the with div tag
			if($Menu1_Block=~m/<div\s*class\=\"section[\w]+?\">([\w\W]*?)<\/div>/is)
			{
				# Enter the JUST IN 
				if($Menu1=~m/JUST\s*IN/is)
				{
					# Menu direct block
					while($Menu1_Block=~m/<ul\s*[\w\W]*?class\=\"[^>]*?\"([\w\W]*?)<\/ul>/igs)
					{
						my $Menu_direct_block=$1;
						my $Head_Menu1;
						
						# Top left menu header collection
						if($Menu_direct_block=~m/class\=\"subHead\">([^>]*?)(<\/span>|<\/a>)/is)
						{
							$Head_Menu1=$1; 
						}
						
						# Collecting the Sub menu and Sub menu URL for Top left
						if($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/is)
						{						
							while($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=Trim($2); # Menu 3 
								
								# Forming the URL
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigation
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}
						elsif($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/is)
						{
							while($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=Trim($2); # Menu 3
								
								# Forming the URL
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigation
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}							
					}
				}
				
				# Head menu block extraction
				if($Menu1_Block=~m/<ul\s*class\=\"list\-[\d]+?[^>]*?\"([\w\W]*?)<\/ul>/is)
				{
					while($Menu1_Block=~m/<ul\s*class\=\"list\-[\d]+?[^>]*?\"([\w\W]*?)<\/ul>/igs)
					{
						my $Menu_direct_block=$1;
						my $Head_Menu1;
						if($Menu_direct_block=~m/class\=\"subHead\">([^>]*?)(<\/span>|<\/a>)/is)
						{
							$Head_Menu1=$1; # Menu_3 Header
						}
						if($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/is)
						{	
							# Extraction of Sub menu URL and menu name
							while($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=Trim($2); # Menu 3
								
								# Framing the URL
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigation
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}
						elsif($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/is)
						{
							while($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=Trim($2);# Menu 3
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigations	
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}	
					}
				}
				elsif($Menu1_Block=~m/<div\s*class\=\"section[\w]+?\">([\w\W]*?)<\/div>/is) # section with div tag
				{
					while($Menu1_Block=~m/<div\s*class\=\"section[\w]+?\">([\w\W]*?)<\/div>/igs)
					{
						my $Menu_direct_block=$1;
						my $Head_Menu1;
						if($Menu_direct_block=~m/class\=\"subHead\">([^>]*?)(<\/span>|<\/a>)/is)
						{
							$Head_Menu1=$1; # Menu_3 Header
						}
						
						# Extraction of Sub menu URL and menu name
						if($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/is)
						{
							while($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=$utilityobject->Trim(Trim($2));# Menu 3
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigations	
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}
						elsif($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/is)
						{
							while($Menu_direct_block=~m/<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*[^>]*?\">([^>]*?)<\/a>/igs)
							{
								my $Sub_menu_url=$1;
								my $Sub_menu=$utilityobject->Trim(Trim($2));# Menu 3
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Calling the subroutine for filter navigations	
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
							}
						}					
					}
					
				}
			}
			elsif($Menu1_Block=~m/<ul\s*class\=\"section[\w]+?\">([\w\W]*?)<\/ul>/is) # Menu1 block Section with UL Tag
			{
				if($Menu1_Block=~m/<ul\s*class\=\"list\-[\d]+?[^>]*?\"([\w\W]*?)<\/ul>/is)
				{
					while($Menu1_Block=~m/<ul\s*class\=\"list\-[\d]+?[^>]*?\"([\w\W]*?)<\/ul>/igs)
					{
						my $Menu_direct_block=$1;
						my $Head_Menu1;
						if($Menu_direct_block=~m/class\=\"subHead\">([^>]*?)(<\/span>|<\/a>)/is)
						{
							$Head_Menu1=$1; # Menu_3 Header
						}	
						while($Menu_direct_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">([^>]*?)<\/a>/igs)
						{
							my $Sub_menu_url=$1;
							my $Sub_menu=$utilityobject->Trim(Trim($2)); # Menu 3
							unless($Sub_menu_url=~m/^\s*http\:/is)
							{
								$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
							}
							
							# Calling the subroutine for filter navigations
							&filter_navigation($Sub_menu_url,$menu0,$Menu1,$Head_Menu1,$Sub_menu);
						}				
					}
				}
				else
				{
					# Holiday Shop Menu navigation check point
					if($Menu1=~m/\s*HOLIDAY\s*SHOP\s*/is)
					{
						if($Menu1_Block=~m/<ul\s*class\=\"sectionC\">([\w\W]*?)<\/ul>/is)
						{
							my $Menu_direct_block=$1;
							if($Menu_direct_block=~m/<a\s*href\=\"([^>]*?)\"[^>]*?>/is)
							{
								my $Sub_navigate_url=$1; 
								
								# For men section, the URL will found from below regex		
								if($menu0=~m/^\s*men\s*$/is)
								{
									if($content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"menuTrigger\">\s*HOLIDAY\s*SHOP\s*<\/a>/is)
									{
										$Sub_navigate_url=$1;
									}
								}
								unless($Sub_navigate_url=~m/^\s*http\:/is)
								{
									$Sub_navigate_url='http://www.matchesfashion.com'.$Sub_navigate_url;
								}
								my $Sub_navigate_url_content = $utilityobject->Lwp_Get($Sub_navigate_url);		
								
								# Holiday Shop Menu navigation
								if($Sub_navigate_url_content=~m/<span>Holiday\s*Shop<\/span>[\w\W]*?<div\s*class\=\"panel\">([\w\W]*?)<\/ul>|Holiday\s*Shop\s*<\/a>\s*<\/li>\s*([\w\W]*?)<\/ul>/is)
								{
									my $holidat_shop_block=$1.$2;
									
									# For Women HOLIDAY SHOP URLs
									while($holidat_shop_block=~m/<a\s*href\=\s*\"([^>]*?)\"[^>]*?Product\s*Listings[^>]*?>([^>]*?)<\/a>/igs) 
									{	
										my $Sub_menu_url=$1;
										my $Sub_menu=Trim($2); # Menu 3
										unless($Sub_menu_url=~m/^\s*http\:/is)
										{
											$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
										}
										
										# Calling the subroutine for filter navigations
										&filter_navigation($Sub_menu_url,$menu0,$Menu1,"",$Sub_menu);
									}
									while($holidat_shop_block=~m/<a\s*href\=\s*\"([^>]*?)\">([^>]*?)<\/a>/igs) # For MEN HOLIDAY SHOP URLs
									{	
										my $Sub_menu_url=$1;
										my $Sub_menu=Trim($2); # Menu 3
										unless($Sub_menu_url=~m/^\s*http\:/is)
										{
											$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
										}
										
										# Calling the subroutine for filter navigations
										&filter_navigation($Sub_menu_url,$menu0,$Menu1,"",$Sub_menu);
									}
									
								}
								
							}	
						}						
					}
					
					# Style Steals Menu check point
					if($Menu1=~m/\s*STYLE\s*STEALS\s*/is)
					{	
						# Style Steals Menu URls collection
						while($Menu1_Block=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\">/igs)
						{						
							my $Sub_navigate_url=$1;
							
							# Forming the URL
							unless($Sub_navigate_url=~m/^\s*http\:/is)
							{
								$Sub_navigate_url='http://www.matchesfashion.com'.$Sub_navigate_url;
							}
							
							# Extracting the Sub menu URL content
							my $Sub_navigate_url_content = $utilityobject->Lwp_Get($Sub_navigate_url);		
							
							# Extracting the Sub menu URL and Sub menu name
							if($Sub_navigate_url_content=~m/<li\s*class\=\"active\">\s*<a\s*href\=\s*\"([^>]*?)\"[^>]*?\">([^>]*?)<\/a>\s*<\/li>/is)
							{	
								my $Sub_menu_url=$1;
								my $Sub_menu=Trim($2); # Menu 3
								
								# Forming the URL
								unless($Sub_menu_url=~m/^\s*http\:/is)
								{
									$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
								}
								
								# Extracting the Sub menu URL content
								my $Sub_menu_url_content = $utilityobject->Lwp_Get($Sub_menu_url);
								
								# Calling the subroutine for filter navigations
								&filter_navigation($Sub_menu_url,$menu0,$Menu1,"",$Sub_menu);
							}
							else
							{
								# Calling the subroutine for filter navigations
								&filter_navigation($Sub_navigate_url,$menu0,$Menu1,"","");
							}
						}
					}			
				}				
			}
		}
		else
		{	
			# Style steal menu collection if fails in IF block
			if($content=~m/<li\s*class\=\"menuStyleSteals\">\s*([\w\W]*?)\s*<\/li>/is)
			{
				my $style_cont_block=$1;
				if($style_cont_block=~m/<a\s*href="([^>]*?)\"\s*class\=\"menuTrigger\s*[^>]*?\">\s*([^>]*?)\s*<\/a>/is)
				{	
					my $Menu_url=$1;
					my $Menu1=$2;
					unless($Menu_url=~m/^\s*http\:/is)
					{
						$Menu_url='http://www.matchesfashion.com'.$Menu_url;
					}
					
					# Calling the subroutine for filter navigations		
					&filter_navigation($Menu_url,$menu0,$Menu1,"","");
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

# Filter navigation subroutine
sub filter_navigation
{
	my $Sub_menu_url=shift; # Main Menu url / Using as Menu_3 URL
	my $Menu0=shift;  # Menu 0 / Using as Menu_1
	my $Menu1=shift;  # Menu 1 / Using as Menu_2
	my $Menu2=shift;  # Menu 2 / Head Menu / Using as Menu_3 Header/ sometimes as Text Menu_3
	my $Menu3=shift;  # Menu 3 / Sub Menu / Using as Menu_3

	# Forming the URL
	unless($Sub_menu_url=~m/^\s*http\:/is)
	{
		$Sub_menu_url='http://www.matchesfashion.com'.$Sub_menu_url;
	}
	
	# Extracting the sub Menu URL content
	my $Sub_menu_url_content = $utilityobject->Lwp_Get($Sub_menu_url);

	# Product availability checking regex
	if($Sub_menu_url_content=~m/(<option\s*value\=\"\">\s*Items\s*per\s*page\s*<\/option>|<div\s*class\=\"products\-view\">\s*<strong>\s*DISPLAY\:\s*<\/strong>)/is)
	{
		# Calling the product collection sub-routine		
		&go_product($Sub_menu_url_content,$Menu0,$Menu1,$Menu2,$Menu3,"","","",$Sub_menu_url,$Sub_menu_url);
	}
	
	# Extraction of filter header and filter block
	while($Sub_menu_url_content=~m/<h4\s*class\=\"tab\">\s*<span>([^>]*?)<\/span>\s*<\/h4>([\w\W]*?)<\/ul>\s*<\/div>/igs)
	{
		my $filter_header_name=Trim($1); # Menu 4 Header
		my $filter_block=$2;
		my $exeute_flag=0;
		
		# checkpoint for entering the filter loop which is already selected
		if(($filter_block=~m/<li\s*class\=\"active\">/is)&&($filter_block=~m/<ul\s*class\=\"\">/is)&&($filter_block!~m/<li\s*class\=\"active\">\s*<a\s*href\=\s*\"[^>]*?>([^>]*?)<\/a>\s*<ul\s*class\=\"\">\s*<li\s*class\=\"active\">/is))
		{
			# Collecting the filter URL and Name
			if($filter_block=~m/<li\s*class\=\"active\">\s*<a\s*href\=\s*\"([^>]*?)\"[^>]*?\">([^>]*?)<\/a>/is)
			{
				my $filter_category_url=$1;
				my $filter_name=Trim($2); # Menu 4
				
				# Framing the URL
				unless($filter_category_url=~m/^\s*http\:/is)
				{
					$filter_category_url='http://www.matchesfashion.com'.$filter_category_url;
				}
				my $filter_category_url_content = $utilityobject->Lwp_Get($filter_category_url);
				
				# Extracting the sub filter content block
				if($filter_block=~m/<ul\s*class\=\"\">([\w\W]*?)<\/ul>/is)
				{
					my $sub_filter_block=$1;
					
					# skipping the active block
					next if($sub_filter_block=~m/<li\s*class\=\"active\">/is);
					
					# Collecting the sub filter URL and name.
					while($sub_filter_block=~m/<a\s*href\=\s*\"([^>]*?)\"[^>]*?\">([^>]*?)<\/a>/igs)
					{
						my $Sub_filter_url=$1;
						my $sub_filter_name=Trim($2); # Menu 5
						
						# Forming the URL
						unless($Sub_filter_url=~m/^\s*http\:/is)
						{
							$Sub_filter_url='http://www.matchesfashion.com'.$Sub_filter_url;
						}
						
						if(($sub_filter_name=~m/\s*Coats\s*/is)&&($Menu1=~m/\s*DESIGNERS\s*/is)&&($Menu3=~m/\s*Saint\s*Laurent\s*/is))
						{
							# To check the coats under saint laurent to Skip
						}
						else
						{
							my $Sub_filter_url_content = $utilityobject->Lwp_Get($Sub_filter_url);
							
							# Calling the product collection sub-routine
							&go_product($Sub_filter_url_content,$Menu0,$Menu1,$Menu2,$Menu3,$filter_header_name,$filter_name,$sub_filter_name,$Sub_filter_url,$Sub_filter_url);
						}							
					}
				}
			}									
		}
		elsif($filter_block=~m/<li\s*class\=\"active\">/is)
		{
			# Skipping active or selected scrolling_list
			next;
		}
		else
		{	
			# Skipping active or selected scrolling_list and assigning the execute loop
			$exeute_flag=1;
		}
		
		# Skipping the size loop
		if($filter_header_name=~m/\s*Size\s*/is)
		{
			next;
		}
	
		# if execute loop enabled, then filter block is available to navigate
		if($exeute_flag==1)
		{
			# Extracting the filter category name and URL
			while($filter_block=~m/<a\s*href\=\s*\"([^>]*?)\"[\w\W]*?\">([^>]*?)<\/a>/igs)
			{
				my $filter_category_url=$1;  
				my $filter_name=Trim($2); # Menu 4
				
				# Framing the URL
				unless($filter_category_url=~m/^\s*http\:/is)
				{
					$filter_category_url='http://www.matchesfashion.com'.$filter_category_url;
				}
					
				my $filter_category_url_content = $utilityobject->Lwp_Get($filter_category_url);
				
				if($filter_block=~m/<ul\s*class\=\"\">([\w\W]*?)<\/ul>/is)
				{
					my $sub_filter_block=$1;
					
					# Skipping the active filter block
					next if($sub_filter_block=~m/<li\s*class\=\"active\">/is);
					
					# Sub Filter name and URL from block
					while($sub_filter_block=~m/<a\s*href\=\s*\"([^>]*?)\"[^>]*?\">([^>]*?)<\/a>/igs)
					{
						my $Sub_filter_url=$1;
						my $sub_filter_name=Trim($2); # Menu 5		
						unless($Sub_filter_url=~m/^\s*http\:/is)
						{
							$Sub_filter_url='http://www.matchesfashion.com'.$Sub_filter_url;
						}
						my $Sub_filter_url_content = $utilityobject->Lwp_Get($Sub_filter_url);
						
						# Calling the product collection sub-routine
						&go_product($Sub_filter_url_content,$Menu0,$Menu1,$Menu2,$Menu3,$filter_header_name,$filter_name,$sub_filter_name,$Sub_filter_url,$Sub_filter_url);							
					}
				}
				else
				{
					# Calling the product collection sub-routine
					&go_product($filter_category_url_content,$Menu0,$Menu1,$Menu2,$Menu3,$filter_header_name,$filter_name,"",$filter_category_url,$filter_category_url);
				}					
			}
		}	
	}
}
		
# Subroutine for product collection
sub go_product
{
	my $product_listing_content=shift;	
	my $Menu0=shift;  # Menu_1
	my $Menu1=shift;  # Menu_2
	my $Menu_name1=shift; # Menu_3 Header
	my $sub_menu1=shift; # Menu_3
	my $menu31=shift; # Menu_4 Header
	my $menu4=shift; # Main Filter Value
	my $menu5=shift;  # Sub Filter Value 
	my $menu3_url=shift; 
	my $product_list_url=shift; # The URL need to use for product navigation
		
	# Framing the Incomplete URL
	unless($product_list_url=~m/^\s*http\:/is)
	{
		$product_list_url='http://www.matchesfashion.com'.$product_list_url;
	}
	
	# Framing the URL to set maximum product limit per page
	if($product_list_url=~m/^([^>]*?)(\?[^>]*?)$/is)
	{
		$product_list_url=$1.$2.'&pagesize=240';
			
	}
	else
	{
		$product_list_url=$product_list_url.'?pagesize=240';
	}
	
	# Pager start point
	page_again:

	my $product_listing_content = $utilityobject->Lwp_Get($product_list_url);
		
	# Extraction of the product block
	if($product_listing_content=~m/<div\s*class=\"products\">([\w\W]*?)<div\s*id\=\"footer\">/is)
	{
		my $prod_block=$1;
		while($prod_block=~m/<a\s*href\=\"(\/product\/[\d]+?)\">/igs)
		{
			my $product_url=$1;
			
			# Framing of the URL
			unless($product_url=~m/^\s*http\:/is)
			{
				$product_url='http://www.matchesfashion.com'.$product_url;		
			}
			
			# Collection of the product URL
			my $product_id;
			if($product_url=~m/^[^>]*?\/([\d]+?)$/is) # Unique ID Creation
			{
				$product_id=$1;
			}
			elsif($product_url=~m/^[^>]*?\/([\d]+?)\?[^>]*?$/is)
			{
				$product_id=$1;
			}
			
			# To insert product URL into table on checking the product is not available already
			my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
		
			# Saving the tag information.
			$dbobject->SaveTag('Menu_1',$Menu0,$product_object_key,$robotname,$Retailer_Random_String) if($Menu0 ne '');
			$dbobject->SaveTag('Menu_2',$Menu1,$product_object_key,$robotname,$Retailer_Random_String) if($Menu1 ne '');
		
			my $menu_flag4=0;
			
			# Menu 3
			if(($Menu_name1!~m/^\s*$/is)&&($sub_menu1!~m/^\s*$/is))
			{					
				$dbobject->SaveTag('Menu_3',$Menu_name1,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_4',$sub_menu1,$product_object_key,$robotname,$Retailer_Random_String);
				$menu_flag4=1;
			}
			elsif(($Menu_name1=~m/^\s*$/is)&&($sub_menu1!~m/^\s*$/is))
			{
				$Menu_name1='Menu_3';
				$dbobject->SaveTag($Menu_name1,$sub_menu1,$product_object_key,$robotname,$Retailer_Random_String);
				undef($Menu_name1);
			}
			elsif(($Menu_name1!~m/^\s*$/is)&&($sub_menu1=~m/^\s*$/is))
			{
				$dbobject->SaveTag('Menu_3',$Menu_name1,$product_object_key,$robotname,$Retailer_Random_String);
			}
			
			# Menu 4
			my $menu_flag=0;
			if(($menu31!~m/^\s*$/is)&&($menu4!~m/^\s*$/is))
			{
				$dbobject->SaveTag($menu31,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
				$menu_flag=1;
			}
			elsif(($menu31=~m/^\s*$/is)&&($menu4!~m/^\s*$/is)&&($menu_flag4!=1))
			{	
				$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
				$menu_flag=1;
			}
			elsif(($menu31=~m/^\s*$/is)&&($menu4!~m/^\s*$/is)&&($menu_flag4==1))
			{	
				$dbobject->SaveTag('Menu_5',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
				$menu_flag=1;
			}
			
			# Menu 5 and 6
			if(($menu4!~m/^\s*$/is)&&($menu5!~m/^\s*$/is))
			{
				$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}				
	
	# Extraction of the pager block
	if($product_listing_content=~m/<div\s*class\=\"pager\">([\w\W]*?)<\/div>/is)
	{
		my $pager_block=$1;			
		if($pager_block=~m/<a\s*href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
		{					
			$product_list_url=$1;					
			unless($product_list_url=~m/^\s*http\:/is)
			{
				$product_list_url='http://www.matchesfashion.com'.$product_list_url;						
			}
			
			# GOTO function to page_again label point
			goto page_again;
		}
	}
}

# Local trim function
sub Trim
{
	my $value1=shift;
	$value1=~s/\&\#8217\;/\'/igs;
	$value1=~s/\&\#8217/\'/igs;
	$value1=~s/\&\#10\;\s*\-/*/igs;
	$value1=~s/\&\#13\;\s*\-/*/igs;
	$value1=~s/\&quot\;/"/igs;
	$value1=~s/\&quot/"/igs;
	$value1=~s/<[^>]*?>/ /igs;
	$value1=~s/\&amp\;/&/igs;
	$value1=~s/\Â/ /igs;
	$value1=~s/\&nbsp\;/ /igs;
	$value1=~s/\&nbsp/ /igs;
	$value1=~s/\s+/ /igs;
	$value1=~s/^\s+|\s+$//igs;
	$value1=decode_entities($value1);
	utf8::decode($value1); 
	return($value1);	
}