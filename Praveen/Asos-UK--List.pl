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
my $Retailer_Random_String='Auk';

# Execution ID is formed by combining Process ID and IP address.
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Creating user agent (Mozilla Firefox).
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
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
my $home_url = 'http://www.asos.com';
my $source_page = $utilityobject->Lwp_Get($home_url);
$source_page =~ s/(<dl\s*class\=\"section\">)/\^\$\^ $1/igs;

# Top menu extraction : women & men.
while($source_page =~ m/<li\s*class\=\"floor_\d+\s*\">\s*<a\s*class\=\"[^>]*?\"\s*href\=\"[^>]*?\">\s*<span>\s*($ARGV[0])\s*<\/span>\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/li>/igs)
{
	my $top_menu = $utilityobject->Trim($1); # Women.
	my $top_menu_block = $2;
	
	# Navigation : women -> shop by product.
	while($top_menu_block =~ m/<dt>\s*($ARGV[1])\s*<\/dt>\s*<dd>\s*<ul\s*class\=\"items\">\s*([\w\W]*?)\s*\^\$\^/igs)
	{
		my $menu_2 = $utilityobject->Trim($1); # Shop by product.
		my $menu_2_block = $2;
		
		# Navigation : women -> shop by product -> dresses.
		while($menu_2_block =~ m/<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $menu_3_url = $1;
			my $menu_3 = $utilityobject->Trim($2); # Dresses.
			next if($menu_3 =~ m/Magazine|Premium\s*Brands/is);					
			$menu_3_url = $home_url.$menu_3_url unless($menu_3_url =~ m/^http/is);
			$menu_3_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
			$menu_3_url = $menu_3_url.'&pgesize=200';
			my $menu_3_page = $utilityobject->Lwp_Get($menu_3_url);
			my $no_filter_page = $menu_3_page;
			
			if($menu_3!~m/\s*SALE\s*|\s*OUTLET\s*|Beauty|A\s*To\s*Z\s*Of\s*Brands/is)
			{
				&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3); # Navigation : women -> shop by product -> dresses.
				
				# Navigation : women -> shop by product -> dresses -> colour.
				while($menu_3_page =~ m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs)
				{
					my $filter_name = $utilityobject->Trim($1);
					my $filter_block = $2;
					
					# Navigation : women -> shop by product -> dresses -> colour -> white.
					while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs)
					{
						my $filter_url = $1;
						my $filter_value = $utilityobject->Trim($2);
						$filter_url = $home_url.$filter_url unless($filter_url =~ m/^http/is);
						$filter_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
						$filter_url = $filter_url.'&pgesize=200';
						my $filter_page = $utilityobject->Lwp_Get($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value); # Navigation : women -> shop by product -> dresses -> colour -> white.
					}
				}
			}
			elsif($menu_3 =~ m/Beauty/is) # Entry for menu 3 : beauty.
			{
				# Navigation : women -> shop by product -> beauty -> face.
                while($menu_3_page =~ m/<h2\s*class\=\"[^>]*?\">\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/h2>/igs)
				{
                    my $menu_4_url = $1;
                    my $menu_4 = $2; # Face.
                    $menu_4_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;           
                    $menu_4_url = $menu_4_url.'&pgesize=200';
                    my $menu_4_page = $utilityobject->Lwp_Get($menu_4_url);
                    my $no_filter_page = $menu_4_page;
					&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4); # Navigation : women -> shop by product -> beauty -> face.

					# Navigation : women -> shop by product -> beauty -> face -> face.
                    while($menu_4_page =~ m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs)
					{
                        my $filter_name = $1; # Face.
                        my $filter_block = $2;
						
						# Navigation : women -> shop by product -> beauty -> face -> face -> cleansing & toning.
                        while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs)
						{
                            my $filter_url = $1;
                            my $filter_value = $2; # Cleansing & toning.
                            $filter_url = $home_url.$filter_url unless($filter_url =~ m/^http/is);
                            $filter_url =~ s/(\&pgesize\=)36/\&pgesize\=200/igs;
                            $filter_url = $filter_url.'&pgesize=200';
                            my $filter_page = $utilityobject->Lwp_Get($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,'',$filter_name,$filter_value); # Navigation : women -> shop by product -> beauty -> face -> face -> cleansing & toning.
                        }
                    }
                }
            }
			elsif($menu_3 =~ m/A\s*To\s*Z\s*Of\s*Brands/is) # Entry for menu 3 : a to z of brands.
			{
				# Navigation : women -> shop by product -> a to z of brands.
				while($menu_3_page =~ m/<div\s*id\=\"letter_[^>]*?\"\s*class\=\"letter\">\s*<h2>\s*([^>]*?)\s*<\/h2>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>/igs)
				{
					my $menu_3_block = $2;
					
					# Navigation : women -> shop by product -> a to z of brands -> a question of.
					while($menu_3_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*(?:<strong>\s*)?([^>]*?)(?:\s*<\/strong>)?\s*<\/a>\s*<\/li>(?!\s*\-\-\>)/igs)
					{
						my $menu_4_url = $1;
						my $menu_4 = $2; # A question of.
						$menu_4_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;			
						$menu_4_url = $menu_4_url.'&pgesize=200';
						my $menu_4_page = $utilityobject->Lwp_Get($menu_4_url);
						my $no_filter_page = $menu_4_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4); # Navigation : women -> shop by product -> a to z of brands -> a question of.

						# Navigation : women -> shop by product -> a to z of brands -> a question of -> colour.
						while($menu_4_page =~ m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs)
						{
							my $filter_name = $1;
							my $filter_block = $2;
							
							# Navigation : women -> shop by product -> a to z of brands -> a question of -> colour -> white.
							while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs)
							{
								my $filter_url = $1;
								my $filter_value = $2;
								$filter_url = $home_url.$filter_url unless($filter_url =~ m/^http/is);
								$filter_url =~ s/(\&pgesize\=)36/\&pgesize\=200/igs;
								$filter_url = $filter_url.'&pgesize=200';
								my $filter_page = $utilityobject->Lwp_Get($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,'',$filter_name,$filter_value); # Navigation : women -> shop by product -> a to z of brands -> a question of -> colour -> white.
							}
						}
					}
				}
			}
			else
			{
				# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories.
				while($menu_3_page =~ m/<h2\s*class\=\"title\">\s*([^>]*?)\s*<\/h2>\s*([\w\W]*?)\s*<\/ul>/igs)
				{
					my $menu_4 = $utilityobject->Trim($1); # Shop by categories.
					my $menu_4_block = $2;
					
					# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> dresses(all).
					while($menu_4_block =~ m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs)
					{
						my $menu_5_url = $1;
						my $menu_5 = $utilityobject->Trim($2); # Dresses(all).
						next if($menu_5 =~ m/Magazine|Premium\s*Brands|A\s*To\s*Z\s*Of\s*Brands/is);
						$menu_5_url = $home_url.$menu_5_url unless($menu_5_url =~ m/^http/is);
						$menu_5_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
						$menu_5_url = $menu_5_url.'&pgesize=200';
						my $menu_5_page = $utilityobject->Lwp_Get($menu_5_url);
						my $no_filter_page = $menu_5_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5); # Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> dresses(all).
						
						# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> dresses(all) -> colour.
						while($menu_5_page =~ m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs)
						{
							my $filter_name = $utilityobject->Trim($1);
							my $filter_block = $2;
							
							# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> dresses(all) -> colour -> white.
							while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs)
							{
								my $filter_url = $1;
								my $filter_value = $utilityobject->Trim($2);
								$filter_url = $home_url.$filter_url unless($filter_url =~ m/^http/is);
								$filter_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
								$filter_url = $filter_url.'&pgesize=200';
								my $filter_page = $utilityobject->Lwp_Get($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5,$filter_name,$filter_value); # Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> dresses(all) -> colour -> white.
							}
						}
					}
				}
				
				# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories.
				while($menu_3_page =~ m/<div\s*class\=\"rightcol\">\s*<ul>\s*([\w\W]*?)\s*<\/ul>/igs)
				{
					my $menu_4_block = $1;
					my $menu_4 = 'Shop by Category';
					
					# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> shoes.
					while($menu_4_block =~ m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs)
					{
						my $menu_5_url = $1;
						my $menu_5 = $utilityobject->Trim($2); # Shoes.
						next if($menu_5 =~ m/Magazine|Premium\s*Brands|A\s*To\s*Z\s*Of\s*Brands/is);
						$menu_5_url = $home_url.$menu_5_url unless($menu_5_url =~ m/^http/is);
						$menu_5_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
						$menu_5_url = $menu_5_url.'&pgesize=200';
						my $menu_5_page = $utilityobject->Lwp_Get($menu_5_url);
						my $no_filter_page = $menu_5_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5); # Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> shoes.
						
						# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> shoes -> colour.
						while($menu_5_page =~ m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs)
						{
							my $filter_name = $utilityobject->Trim($1);
							my $filter_block = $2;
							
							# Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> shoes -> colour -> black.
							while($filter_block =~ m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs)
							{
								my $filter_url = $1;
								my $filter_value = $utilityobject->Trim($2);
								$filter_url = $home_url.$filter_url unless($filter_url =~ m/^http/is);
								$filter_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
								$filter_url = $filter_url.'&pgesize=200';
								my $filter_page = $utilityobject->Lwp_Get($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5,$filter_name,$filter_value); # Navigation : women -> shop by product -> sale - upto 50% off -> shop by categories -> shoes -> colour -> black.
							}
						}
					}
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
	my $menu_4 = shift;
	my $menu_5 = shift;
	my $filter = shift;
	my $filter_value = shift;
	
	next_page:
	# Pattern match of url from list page.
	while($page =~ m/<div\s*class\=\"categoryImageDiv\"[^>]*?>\s*<a[^>]*?href\=\"([^>]*?)\">/igs)
	{
		my $product_url = $1;
		$product_url = 'http://www.asos.com/pgeproduct.aspx'.$1 if($product_url =~ m/(\?iid\=\d+)/is);
		next if($product_url =~ m/\?sgid\=[0-9]+/is);
		my $product_object_key;
		
		# Checking whether product URL already stored in the database. If exist then existing ObjectKey is re-initialized to the URL.
		if($totalHash{$product_url} eq '')
		{			
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$totalHash{$product_url} = $product_object_key;
		}
		$product_object_key = $totalHash{$product_url}; # Using existing product_id if the hash table contains this url.
		
		$dbobject->SaveTag('Menu_1',$top_menu,$product_object_key,$robotname,$Retailer_Random_String) if($top_menu ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');
		$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
		$dbobject->SaveTag('Menu_4',$menu_4,$product_object_key,$robotname,$Retailer_Random_String) if($menu_4 ne '');
		$dbobject->SaveTag('Menu_5',$menu_5,$product_object_key,$robotname,$Retailer_Random_String) if($menu_5 ne '');
		$dbobject->SaveTag($filter,$filter_value,$product_object_key,$robotname,$Retailer_Random_String) if(($filter ne '') && ($filter_value ne ''));
		$dbobject->commit();
	}
	
	# Pattern of next page.
	if($page =~ m/<a[^<]*?href\=\'([^<]*?)\'>\s*Next/is)
	{
		my $next_url = $1;
		$next_url =~ s/\&pgesize\=36/\&pgesize\=200/igs;
		$page = $utilityobject->Lwp_Get($next_url);
		goto next_page;
	}
}

# End of List collection.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Saving end time in dashboard.
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Commit the Transaction.
$dbobject->commit();