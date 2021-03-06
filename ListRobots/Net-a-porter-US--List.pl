#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl

# Required modules are initialized.
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings.
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Robotname is constructed from file name.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Nus';

# Execution ID is formed by combining Process ID and IP address.
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Creating user agent (Mozilla Firefox).
my $ua = LWP::UserAgent->new(show_progress=>1);
# $ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->agent('WGSN;+44 207 516 5099;datacollection@wgsn.com');
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the configuration file.
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini)
{
	# Die if reading the settings failed.
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog.
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

# Connect to AnorakDB package.
my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Connect to Utility package.
my $utilityobject = AnorakUtility->new($logger,$ua);

# Get Retailer_id & Proxy details.
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Set the proxy environment.
$utilityobject->SetEnv($ProxySetting);

# Saving start time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

$logger->send("$robotname :: Instance Started :: $pid\n");

# Retailer home page content.
my $home_url = 'http://www.net-a-porter.com'; # RETAILER HOME URL : NET-A-PORTER, US
my $url = 'http://www.net-a-porter.com/am/cmsContent/TopNavigation.nap?device=desktop&country=US&language=en';
my $source_page = $utilityobject->Lwp_Get($url);

while($source_page =~ m/\"[^<]*?(?:(Whats_New|Clothing\"\:|Bags\"\:|Shoes\"\:|Accessories\"\:|Lingerie\"\:|Sport\"\:|Beauty\"\:|Gifts\"\:))[^>]*?(?:<\/script>)?\\n\s*<\!\-\-\s*dropdown\s*content\s*\-\->([\w\W]*?<\/div>\\n\s*<\/div>\s*\\n)(?:\s*<\!\-\-\s*DEBUG\:[^>]*?\-\->\\n\s*\\n)?\s*<\/div>/igs)
{
	my $top_menu = $utilityobject->Trim($1); # Clothing.
	my $top_menu_block = $2;
	$top_menu =~ s/\"\:$//igs;
	$top_menu =~ s/whats_new/Whats New/igs;

	# Extracts menu 2 and menu 2 block from top menu block.
	while($top_menu_block =~ m/<div\s*class\=\\\"header\s*border\-bottom[^>]*?\">\s*((?!Designer|Brand)[^>]*?)\s*<\/div>\s*([\w\W]*?)<\/ul>\\n\s*<\/div>\\n\s*<\/div>/igs)
	{
		my $menu_2 = $1; # Shop by.
		my $menu_2_block = $2;		

		# Extracts menu 3 and it's corresponding url from menu 2 block (excluding "the trend report" and "all" from menu 2 block).
		while($menu_2_block =~ m/<a[^>]*?href\=\\\"([^>]*?)\\\"\s*>\s*((?!The\s*Trend\s*Report|All\s*)[^>]*?)\s*<\/a>/igs)
		{
			my $menu_3_url = $1;
			my $menu_3 = $utilityobject->Trim($2); # Blazers.			
			$menu_3_url = $home_url.$menu_3_url unless($menu_3_url=~m/^http/is);			

			next if($menu_3_url =~ m/AZdesigner/is); # Menu 3 url : az designer skipped.
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);						

			# Navigation: clothing -> shop by -> blazers.
			if($menu_3_page =~ m/<li\s*class\=\"\s*selected\s*\">/is)
			{
				my $flag = 0;
				while($menu_3_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"\?([^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $append_url = $1;
					my $filter_name = $utilityobject->Trim($2); # Colour.
					my $filter_value = $utilityobject->Trim($3); # White.						
					
					if($menu_3_url =~ m/level\d+filter\=/is)
					{
						$append_url = $1 if($append_url =~ m/^([^>]*?)\&level\d+Filter\=[^>]*?$/is);
					}
					my $filter_url = $menu_3_url.'&'.$append_url;
					$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
					$filter_url = $filter_url.'&npp=view_all' unless($filter_url=~m/npp\=/is);					
					$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
					my $filter_page = $utilityobject->Lwp_Get($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> blazers -> colour -> white).
					$flag = 1;
				}

				if($flag == 0)
				{
					while($menu_3_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?(colour)Filter\=[^\"]*?)\"\s*title\=\"[^\"]*?\">\s*<span\s*class\=\"filter\-checkbox\">\s*<\/span>\s*<span\s*class\=\"filter\-name\">([^<]*?)<\/span>/igs)
					{
						my $append_url = $1;
						my $filter_name = $utilityobject->Trim($2); # Colour.
						my $filter_value = $utilityobject->Trim($3); # White.						
						my $filter_url = $home_url.$append_url;
						
						$filter_url = $filter_url.'&npp=view_all' unless($filter_url=~m/npp\=/is);					
						$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> blazers -> colour -> white).
					}
				}
			}
			elsif($menu_3_page =~ m/<li\s*class\=\"open\s*selected\">/is) # Navigation: clothing -> shop by -> wedding.
			{
				# Navigation: clothing -> shop by -> wedding -> the bride.
				while($menu_3_page =~ m/<span>\s*<a[^>]*?href\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>\s*<\/span>\s*<ul>\s*([\w\W]*?)\s*<\/ul>/igs)
				{
					my $category = $1; # The bride.
					my $category_block = $2;
					
					# Navigation: clothing -> shop by -> wedding -> the bride -> dresses & separates.
					while($category_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $sub_category_url = $1;
						my $sub_category = $2; # Dresses & separates.
						my $sub_category_page = $utilityobject->Lwp_Get($sub_category_url);
						
						while($sub_category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $filter_url = $sub_category_url.$1;
							my $filter_name = $utilityobject->Trim($2); # Colour.
							my $filter_value = $utilityobject->Trim($3); # White.
							$filter_url = $1.$2 if($filter_url=~m/([^>]*?)\?SelItem\=\d+(?:\;\d+)?(\&colourFilter\=[^>]*?)\&[^>]*?$/is);
							$filter_url = $1.$2 if($filter_url=~m/([^>]*?)\?SelItem\=\d+(?:\;\d+)?\&[^>]*?(\&colourFilter\=[^>]*?)$/is);
							$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
							$filter_url = $filter_url.'&npp=view_all' unless($filter_url=~m/npp\=/is);
							$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
							my $filter_page = $utilityobject->Lwp_Get($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> wedding -> the bride -> dresses & separates -> colour -> white).
						}
					}
				}

				# Navigation: clothing -> shop by -> wedding -> mother of bride.
				while($menu_3_page =~ m/<li\s*class\=\"\">\s*<a\s*id\=\"\d+\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs)
				{
					my $category_url = $1;
					my $category = $2; # Mother of bride.
					my $category_page = $utilityobject->Lwp_Get($category_url);
					
					while($category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
					{
						my $filter_url = $category_url.$1;
						my $filter_name = $utilityobject->Trim($2); # Colour.
						my $filter_value = $utilityobject->Trim($3); # White.
						$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
						$filter_url = $filter_url.'&npp=view_all' unless($filter_url=~m/npp\=/is);
						$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> wedding -> mother of bride -> colour -> white).
					}
				}
			}
			else
			{
				if($menu_3_page !~ m/<li\s*class\=\"\">\s*<a\s*href\=\"[^\"]*?\"\s*data\-filter\=\"[^\"]*?\">/is)
				{
					# Entry when sub category is selected.
					if($menu_3_page =~ m/<li\s*class\=\"has\-children\s*selected\">\s*<a[^>]*?href\=\"([^>]*?)\">\s*((?!All)[^<]*?)\s*<\/a>/is)
					{
						# Navigation: lingerie -> shop by -> bras -> bras.
						while($menu_3_page =~ m/<li\s*class\=\"has\-children\s*selected\">\s*<a[^>]*?href\=\"([^>]*?)\">\s*((?!All)[^<]*?)\s*<\/a>/igs)
						{
							my $category_url = $1;
							$category_url = $home_url.$category_url unless($category_url=~m/^http/is);
							my $category = $utilityobject->Trim($2); # Activewear.
							my $category_page = $utilityobject->Lwp_Get($category_url);							
							
							if($category_page =~ m/<li\s*class\=\"\">\s*<a\s*href\=\"[^\"]*?\"\s*data\-filter\=\"[^\"]*?\">/is)
							{
								# Navigation: lingerie -> shop by -> bras -> bras -> dd plus bra.
								while($category_page =~ m/<li\s*class\=\"\">\s*<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs)
								{
									my $sub_category_url = $1;
									$sub_category_url = $home_url.$sub_category_url unless($sub_category_url =~ m/^http/is);
									my $sub_category = $utilityobject->Trim($2); # DD plus bra.
									my $sub_category_page = $utilityobject->Lwp_Get($sub_category_url);
									
									while($sub_category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
									{
										my $filter_url = $sub_category_url.$1;
										my $filter_name = $utilityobject->Trim($2); # Colour
										my $filter_value = $utilityobject->Trim($3); # White.
										$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
										$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
										$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
										$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
										my $filter_page=$utilityobject->Lwp_Get($filter_url);
										&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: lingerie -> shop by -> bras -> bras -> dd plus bra -> colour -> white).
									}
								}
							}
							else # Navigation: what's new -> shop by -> this week -> clothing.
							{
								while($category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
								{
									my $filter_url = $category_url.$1;
									my $filter_name = $utilityobject->Trim($2); # Colour.
									my $filter_value = $utilityobject->Trim($3); # White.
									$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
									$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
									$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
									$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
									my $filter_page=$utilityobject->Lwp_Get($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: what's new -> shop by -> this week -> clothing -> colour -> white).
								}
							}
						}
					}
					else
					{
						# Navigation: clothing -> shop by -> activewear -> activewear.						
						while($menu_3_page =~ m/<\/li>\s*<li\s*class\=\"[^\"]*?selected\">\s*<a\s*href\=\"([^\"]*?)\">\s*<span>\s*([^<]*?)\s*<\/span>/igs)
						{
							my $category_url = $1;
							my $category = $utilityobject->Trim($2); # Activewear.
							$category_url = $home_url.$category_url unless($category_url =~ m/^http/is);							
							my $category_page = $utilityobject->Lwp_Get($category_url);
							
							if($category_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"\?([^\"]*?)\"\s*title\=\"[^\"]*?\"\s*data\-filter\=\"([^\"]*?)\">/is)
							{
								# Navigation: clothing -> shop by -> activewear -> activewear -> tops.
								while($category_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"\?([^\"]*?)\"\s*title\=\"[^\"]*?\"\s*data\-filter\=\"([^\"]*?)\">/igs)
								{
									my $sub_category_url = $1;
									my $sub_category = $utilityobject->Trim($2); # Tops.
									$sub_category_url = $category_url.'?'.$sub_category_url unless($sub_category_url=~m/^http/is);
									$sub_category_url=~s/amp\;//igs;
									my $sub_category_page = $utilityobject->Lwp_Get($sub_category_url);
									
									while($sub_category_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span[^>]*?>\s*[^>]*?\s*<\/span>\s*(?:<[^>]*?>)\s*<span[^>]*?>\s*([^>]*?)\s*<\/span>/igs)
									{
										my $filter_url = $home_url.$1;
										my $filter_name = $utilityobject->Trim($2); # Colour.
										my $filter_value = $utilityobject->Trim($3); # White.
										$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
										$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
										$filter_url = $filter_url.'&npp=view_all' unless($filter_url=~m/npp\=/is);
										$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
										my $filter_page = $utilityobject->Lwp_Get($filter_url);
										&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> activewear -> activewear -> tops -> colour -> white).
									}
								}
							}
							else # Navigation: what's new -> shop by -> this week -> clothing.
							{
								while($category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
								{
									my $filter_url = $category_url.$1;
									my $filter_name = $utilityobject->Trim($2); # Colour.
									my $filter_value = $utilityobject->Trim($3); # White.
									$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
									$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
									$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
									$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
									my $filter_page=$utilityobject->Lwp_Get($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: what's new -> shop by -> this week -> clothing -> colour -> white).
								}
							}
						}
						
						# Loop for Accessories menu.
						while($menu_3_page =~ m/<li\s*class\=\"has\-children\">\s*<a\s*class\=\"filter_checkbox\"\s*href\=\"([^\"]*?)\">\s*([^<]*?)\s*<\/a>/igs)
						{
							my $category_url = $1;
							my $category = $utilityobject->Trim($2);
							$category_url = $home_url.$category_url unless($category_url =~ m/^http/is);							
							my $category_page = $utilityobject->Lwp_Get($category_url);
							my $flag = 0;
							while($category_page =~ m/<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs)
							{
								my $sub_category_url = $1;
								my $sub_category = $utilityobject->Trim($2);
								$sub_category_url = $home_url.$sub_category_url unless($sub_category_url =~ m/^http/is);							
								my $sub_category_page = $utilityobject->Lwp_Get($sub_category_url);

								while($sub_category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"\?([^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
								{
									my $filter_url = $sub_category_url.'&'.$1;
									my $filter_name = $utilityobject->Trim($2); # Colour.
									my $filter_value = $utilityobject->Trim($3); # White.
									$filter_url =~ s/^([^>]*?)\&(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
									$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
									$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
									$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
									my $filter_page=$utilityobject->Lwp_Get($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value);
								}
								$flag = 1;
							}
							if($flag == 0)
							{
								while($category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
								{
									my $filter_url = $category_url.$1;
									my $filter_name = $utilityobject->Trim($2); # Colour.
									my $filter_value = $utilityobject->Trim($3); # White.
									$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
									$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
									$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
									$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
									my $filter_page=$utilityobject->Lwp_Get($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value);
								}
							}
						}						
					}
				}
				else
				{
					while($menu_3_page =~ m/<li\s*class\=\"\">\s*<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs) # Navigation: clothing -> shop by -> shorts -> denim.
					{
						my $sub_category_url = $1;
						$sub_category_url = $home_url.$sub_category_url unless($sub_category_url=~m/^http/is);
						my $sub_category = $utilityobject->Trim($2); # Denim.
						my $sub_category_page = $utilityobject->Lwp_Get($sub_category_url);
						
						while($sub_category_page =~ m/<a\s*class\=\"filter_name\"\s*href\=\"\?([^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $filter_url = $sub_category_url.'&'.$1;
							my $filter_name = $utilityobject->Trim($2); # Colour.
							my $filter_value = $utilityobject->Trim($3); # Blue.
							$filter_url =~ s/^([^>]*?)\?(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
							$filter_url =~ s/^([^>]*?)\&(colourFilter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;
							$filter_url =~ s/\&npp\=60/\&npp\=view_all/igs;
							$filter_url = $filter_url.'&npp=view_all' unless($filter_url =~ m/npp\=/is);
							$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
							my $filter_page = $utilityobject->Lwp_Get($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'',$sub_category,$filter_name,$filter_value); # Transports product_url, top_menu, menu_2, menu_3, filter and filter value to product_insert module for inserting tags into db (navigation: clothing -> shop by -> shorts -> denim -> colour -> blue).
						}
					}
				}
			}			
		}
	}
}

# Products under sale menu.
if($source_page =~ m/(Sale)\s*top\s*nav\"\:\"\\n\\n\\n\s*<\!\-\-\s*dropdown\s*content\s*\-\->([\w\W]*?<\/div>\\n\s*<\/div>\s*\\n)(?:\s*<\!\-\-\s*DEBUG\:[^>]*?\-\->\\n\s*\\n)?\s*<\/div>/is){
	my $top_menu = $utilityobject->Trim($1); # Sale.
	my $top_menu_block = $2;
	
	if($top_menu_block =~ m/<div\s*class\=\\\"header\s*border\-bottom[^>]*?\">\s*((?!Designer|Brand)[^>]*?)\s*<\/div>\s*([\w\W]*?)<\/ul>\\n\s*<\/div>\\n\s*<\/div>/is){
		my $menu_2 = $1; # Shop sale by category.
		my $menu_2_block = $2;
		
		while($menu_2_block =~ m/<a[^>]*?href\=\\\"([^>]*?)\\\"\s*>\s*((?!The\s*Trend\s*Report|\s*All\s*Categories|Sale\s*Designers)[^>]*?)\s*<\/a>/igs){
			my $menu_3_url = $1;
			my $menu_3 = $utilityobject->Trim($2); # Dresses.
			$menu_3_url = $home_url.$menu_3_url unless($menu_3_url =~ m/^http/is);
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
			
			if($menu_3 =~ m/^All/is){
				if($menu_3_page =~ m/<ul\s*id\=\"subnav\"[^>]*?>\s*([\w\W]*?)\s*<\/ul>/is){
					my $menu_3_block = $1;
					
					while($menu_3_block =~ m/<a\s*href\=\"([^>]*?)\">\s*<span>([^<]*?)<\/span>\s*<\/a>/igs){
						my $menu_4_url = $1;
						my $menu_4 = $2;
						$menu_4_url = $home_url.$menu_4_url unless($menu_4_url =~ m/^http/is);
						my $menu_4_page = $utilityobject->Lwp_Get($menu_4_url);
						
						while($menu_4_page=~m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?(colour)Filter\=[^\"]*?)\"\s*title\=\"[^\"]*?\">\s*<span\s*class\=\"filter\-checkbox\">\s*<\/span>\s*<span\s*class\=\"filter\-name\">([^<]*?)<\/span>/igs)
						{
							my $append_url = $1.'&npp=view_all';
							my $filter_name = $utilityobject->Trim($2); # Colour.
							my $filter_value = $utilityobject->Trim($3); # White.						
							
							my $filter_url = $home_url.$append_url;
							$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
							my $filter_page = $utilityobject->Lwp_Get($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,'',$filter_name,$filter_value);
						}
					
						while($menu_4_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?)\"\s*title\=\"([^\"]*?)\"\s*data\-filter/igs){
							my $menu_5_url = $1.'&npp=view_all';
							my $menu_5 = $2;
							$menu_5_url = $menu_4_url.$menu_5_url unless($menu_5_url =~ m/^http/is);
							my $menu_5_page = $utilityobject->Lwp_Get($menu_5_url);
							&Product_Insert($menu_5_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5,'','');
						}
					}
				}
			}
			else{
				while($menu_3_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?(colour)Filter\=[^\"]*?)\"\s*title\=\"[^\"]*?\">\s*<span\s*class\=\"filter\-checkbox\">\s*<\/span>\s*<span\s*class\=\"filter\-name\">([^<]*?)<\/span>/igs)
				{
					my $append_url = $1.'&npp=view_all';
					my $filter_name = $utilityobject->Trim($2); # Colour.
					my $filter_value = $utilityobject->Trim($3); # White.						
					
					my $filter_url = $menu_3_url.'?'.$append_url;
					$filter_url =~ s/\/Shop\//\/us\/en\/Shop\//igs if($filter_url !~ m/us\/en/is);
					my $filter_page = $utilityobject->Lwp_Get($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value);
				}

				while($menu_3_page =~ m/<a\s*class\=\"filter\-item\"\s*href\=\"([^>]*?)\"\s*title\=\"([^\"]*?)\"\s*data\-filter/igs){
					my $menu_4_url = $1.'&npp=view_all';
					my $menu_4 = $2;
					$menu_4_url = $menu_3_url.$menu_4_url unless($menu_4_url =~ m/^http/is);
					my $menu_4_page = $utilityobject->Lwp_Get($menu_4_url);
					&Product_Insert($menu_4_page,$top_menu,$menu_2,$menu_3,$menu_4,'','','');
				}
			}
		}
	}
}
undef $source_page;

# URL collection.
sub Product_Insert()
{
	my $page = shift;
	my $top_menu = shift;
	my $menu_2 = shift;
	my $menu_3 = shift;
	my $category = shift;
	my $sub_category = shift;
	my $filter = shift;
	my $filter_value = shift;	
	
	# Pattern match of url from list page.
	while($page =~ m/<div\s*class\=\"description\">\s*<a\s*href\=\"([^<]*?(\d+))[^>]*?\"\s*title\=\"[^\"]*?\"[^>]*?>/igs)
	{
		my $product_url = $home_url.$1;
		my $product_object_key;
		
		my $product = $1 if($product_url =~ m/\/(\d+)$/is);
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product} eq '')
		{			
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$totalHash{$product} = $product_object_key;
		}
		else
		{
			$product_object_key = $totalHash{$product}; # Using existing product_id if the hash table contains this url.
		}
		
		# Storing menus into database.
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');		
		$dbobject->SaveTag('category',$category,$product_object_key,$robotname,$Retailer_Random_String) if($category ne '');
		$dbobject->SaveTag('sub category',$sub_category,$product_object_key,$robotname,$Retailer_Random_String) if($sub_category ne '');
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
}

# End of List collection.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit the Transaction.
$dbobject->commit();