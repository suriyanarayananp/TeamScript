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
my $Retailer_Random_String='Abe';
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
# my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
my $retailer_id = '56de30f0f151413bf26f37b0c211f13749c7214';
my $ProxySetting = 'http://frawspcpx.cloud.trendinglines.co.uk:3129';
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Using the argument set the domain URLs'.
my $sourceurl;
if($ARGV[0] eq 'kids')
{
	$sourceurl = "http://www.abercrombiekids.com";
}
else
{
	$sourceurl = "http://www.abercrombie.com";
}

my $content = $utilityobject->Lwp_Get($sourceurl);

# Navigate for each main menu.
while($content =~ m/href\=\"([^>]*?)\">\s*<h2[^>]*?nav\-description\">\s*([^>]*?)\s*<\/h2>/igs)
{
	my $caturl = $1;
	my $menu1 = $utilityobject->Trim($2);
	$caturl = $sourceurl.$caturl unless($caturl =~ m/^http/is);
	my $subcontent = $utilityobject->Lwp_Get($caturl); 
	
	# Getting the LHM block.
	if($subcontent =~ m/<ul\s*class\=\"primary\">([\w\W]*?)<\/ul>/is)
	{
		my $subcont = $1;
		
		# Navigate through each sub menu.
		while($subcont =~ m/href\=\"([^>]*?)\"\s*>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $caturl2 = $1;
			my $menu2 = $utilityobject->Trim($2);
			$caturl2 = $sourceurl.$caturl2 unless($caturl2 =~ m/^http/is);
			my $subcontent2 = $utilityobject->Lwp_Get($caturl2);
			
			# Pattern matching for Sale/Clearance.
			if($menu2 =~ m/Sale|Clearance/is)
			{
				# Getting the sub menu block.
				if($subcontent2 =~ m/>\s*$menu2\s*<\/a>\s*<ul\s*class\=\"secondary\">([\w\W]*?)\s*(?:<\/ul>\s*<\/div>|<li\s*id\=\"cat\-anf_division)/is)
				{
					my $subcont2 = $1;
					
					# Navigate through each sub menu under Sale/Clearance.
					while($subcont2 =~ m/End:\s*Filter\s*Ability to Block Sub Categories\s*\-\->\s*<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu3 = $utilityobject->Trim($2);
						$caturl3 = $sourceurl.$caturl3 unless($caturl3 =~ m/^http/is);
						my $menucontent3 = $utilityobject->Lwp_Get($caturl3);
						
						# Check if the sub-menu having any child category.
						if($menucontent3=~m/class\=\"current\s*selected[^>]*?>\s*<[^>]*?>\s*$menu3\s*<\/a>\s*<ul([\w\W]*?)<\/ul>\s*<\/li>/is)
						{
							my $block = $1;
							
							# Getting the product page URLs from the block.
							while($block =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*</igs)
							{
								my $menuurl_1 = $1;
								my $menu4 = $utilityobject->Trim($2);
								$menuurl_1 = $sourceurl.$menuurl_1 unless($menuurl_1 =~ m/^http/is);
								my $menucontent_1 = $utilityobject->Lwp_Get($menuurl_1);
								
								# Collecting the Product URLs. 
								while($menucontent_1 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"/igs)
								{
									my $purl = $1;
									my $productid = $2;
									$purl = $sourceurl.$purl unless($purl =~ m/^http/is);
									
									if($sourceurl =~ m/abercrombiekids/is)
									{
										&Product_Info($purl, $productid, 'Abercrombie Kids', $menu1, $menu2, $menu3, $menu4);
									}
									else
									{
										&Product_Info($purl, $productid, $menu1, $menu2, $menu3, $menu4);
									}
								}
							}
						}
						else
						{
							# If sub-menu doesn't have any child category then Collect the Product URLs.
							while($menucontent3 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"/igs)
							{
								my $purl = $1;
								my $productid = $2;
								$purl = $sourceurl.$purl unless($purl =~ m/^http/is);
								
								if($sourceurl =~ m/abercrombiekids/is)
								{
									&Product_Info($purl, $productid, 'Abercrombie Kids', $menu1, $menu2, $menu3);
								}
								else
								{
									&Product_Info($purl, $productid, $menu1, $menu2, $menu3);
								}
							}
						}
					}
				}
			}
			elsif($subcontent2 =~ m/href\=\"([^>]*?)\"\s*class\=\"product\-link\"/is)
			{
				# If menu2 doesn't have any sub category.
				while($subcontent2 =~ m/href\=\"([^>]*?)\"\s*class\=\"product\-link\"/igs)
				{
					my $purl = $1;
					$purl = $sourceurl.$purl unless($purl =~ m/^http/is);
					
					# Insert Product_List table based on values collected for the product.
					my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
					if($sourceurl =~ m/abercrombiekids/is)
					{
						# Save the tag information if menu1 is non-empty.
						$dbobject->SaveTag('Menu_1','Abercrombie Kids',$product_object_key,$robotname,$Retailer_Random_String);
						unless($menu1=~m/^\s*$/is)
						{
							# Save the tag information if menu1 is non-empty.
							$dbobject->SaveTag('Menu_2',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
						}
						unless($menu2=~m/^\s*$/is)
						{
							# Save the tag information if menu2 is non-empty.
							$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String,);
						}
					}
					else
					{
						unless($menu1=~m/^\s*$/is)
						{
							# Save the tag information if menu1 is non-empty.
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
						}
						unless($menu2=~m/^\s*$/is)
						{
							# Save the tag information if menu2 is non-empty.
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String,);
						}
					}
					
					# Committing the transaction.
					$dbobject->commit();
				}
			}
			elsif($subcontent2 =~ m/<div\s*id\=\"category\-nav\-wrap\">([\w\W]*?)<div id="category-content"/is)
			{
				# If Menu2 having sub category.
				my $subcont3 = $1;
				if($subcont3 =~ m/<ul\s*class\=\"secondary\">([\w\W]*?)<\/ul>/is)
				{
					my $subcont2 = $1;
					
					# Getting the product page URLs from the block.
					while($subcont2 =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu3 = $utilityobject->Trim($2);
						$caturl3 = $sourceurl.$caturl3 unless($caturl3 =~ m/^http/is);
						my $subcontent3 = $utilityobject->Lwp_Get($caturl3); 
						
						# Collecting the Product URLs.
						while($subcontent3 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"/igs)
						{
							my $purl = $1;
							my $productid = $2;
							$purl = $sourceurl.$purl unless($purl =~ m/^http/is);
							if($sourceurl =~ m/abercrombiekids/is)
							{
								&Product_Info($purl, $productid, 'Abercrombie Kids', $menu1, $menu2, $menu3);
							}
							else
							{
								&Product_Info($purl, $productid, $menu1, $menu2, $menu3);
							}
						}
					}
				}
				else
				{
					# If menu2 doesn't have any sub category.
					while($subcontent2 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"/igs)
					{
						my $purl = $1;
						my $productid = $2;
						$purl = $sourceurl.$purl unless($purl =~ m/^http/is);
						if($sourceurl =~ m/abercrombiekids/is)
						{
							&Product_Info($purl, $productid, 'Abercrombie Kids', $menu1, $menu2);
						}
						else
						{
							&Product_Info($purl, $productid, $menu1, $menu2);
						}
					}
				}
			}
		}
	}
}

# To indicate script has completed in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Once script has complete send a msg to logger.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Committing the transaction.
$dbobject->commit();

sub Product_Info()
{
	my ($purl, $productid, $menu1, $menu2, $menu3, $menu4, $menu5) = @_;
	my $product_object_key;
	# Check the product duplication using productID in Hash.
	if(defined $totalHash{$productid})
	{
		# If Product is exists getting the ObjectKey from Hash.
		$product_object_key = $totalHash{$productid};
	}
	else
	{
		# If its a new product get the ObjectKey from SaveProduct and assign into Hash.
		# Insert Product_List table based on values collected for the product.
		$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
		$totalHash{$productid}=$product_object_key;
	}
	if($purl =~ m/abercrombiekids/is)
	{
		unless($menu1=~m/^\s*$/is)
		{
			# Save the tag information if menu1 is non-empty.
			$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu2=~m/^\s*$/is)
		{
			# Save the tag information if menu2 is non-empty.
			$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu3=~m/^\s*$/is)
		{
			# Save the tag information if menu3 is non-empty.
			$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu4=~m/^\s*$/is)
		{
			# Save the tag information if menu4 is non-empty.
			$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu5=~m/^\s*$/is)
		{
			# Save the tag information if menu5 is non-empty.
			$dbobject->SaveTag('Category',$menu5,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	else
	{
		unless($menu1=~m/^\s*$/is)
		{
			# Save the tag information if menu1 is non-empty.
			$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu2=~m/^\s*$/is)
		{
			# Save the tag information if menu2 is non-empty.
			$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu3=~m/^\s*$/is)
		{
			# Save the tag information if menu3 is non-empty.
			$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu4=~m/^\s*$/is)
		{
			# Save the tag information if menu4 is non-empty.
			$dbobject->SaveTag('Category',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
		}
	
	}
	# Committing the transaction.
	$dbobject->commit();
	
	# Undef variables.
	$product_object_key=$purl=$productid=$menu1=$menu2=$menu3=$menu4=$menu5=undef;
}