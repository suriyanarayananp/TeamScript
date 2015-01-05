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
my $Retailer_Random_String='por';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %hash_id;
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

# Getting home page content.
my $url = 'http://www.portmans.com.au/shop/en/portmans';
my $content = $utilityobject->Lwp_Get($url);
my %totalHash; 
# Pattern matching getting the top menus with block eg: New Arrivals, Tops etc.,
while($content =~ m/href\=\'([^>]*?)\'\s*>\s*([^>]*?)<\/a>\s*<div\s*class\=\"do\-submenu\">([\w\W]*?)<\/div>\s*<\/div>/igs)
{	
	my $menu1url = $1;
	my $menu1 = $utilityobject->Trim($2); # New Arrivals, Top (Main Menu)
	my $block = $3; # Main Menu block
	next if($menu1 =~ m/Gift|Lookbooks/is);
	my $m1content = $utilityobject->Lwp_Get($menu1url);
	while($block =~ m/href\=\'([^>]*?)\'[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
	{
		my $menu2url = $utilityobject->Trim($1); # Menu2 URLs
		my $menu2 = $utilityobject->Trim($2); # Menu2 : New Clothing, accessories etc.,
		my $m2content = $utilityobject->Lwp_Get($menu2url);
		
		if($m2content =~ m/<li\s*class\=\"do\-tier3\"\s*>\s*<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*</is)
		{
			while($m2content =~ m/<li\s*class\=\"do\-tier3\"\s*>\s*<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*</igs)
			{
				my $menu3url = $utilityobject->Trim($1); # Menu3 URLs
				my $menu3 = $utilityobject->Trim($2); # Menu3 : Jewlery -> Earings -> Rings etc.,
				my $m3content = $utilityobject->Lwp_Get($menu3url);
				
				NextPagev1:
				while($m3content =~ m/href\=\"([^>]*?)\"[^>]*?class\=\"itemhover\">\s*<span\s*class\=\"do\-title\">/igs)
				{
					my $product_url = $1;
					my $product_object_key;
					if($totalHash{$product_url} ne '')
					{
						print "Data Exists! -> $totalHash{$product_url}\n";
						$product_object_key = $totalHash{$product_url};
					}
					else
					{
						print "New Data\n";
						$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						$totalHash{$product_url}=$product_object_key;
					}
					print "LOOP 2 => $menu1->$menu2->$menu3\n";
					# Insert Tag values.
					$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
					$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
					$dbobject->commit();
				}
				if($m3content =~ m/goToResultPage\(\'([^>]*?)\'[^>]*?id\=\"WC_CatalogSearchResultDisplay_link_8\"/is)
				{
					my $nextpage = $utilityobject->Trim($1);
					$nextpage =~ s/\s+//igs;
					$m3content = $utilityobject->Lwp_Get($nextpage);
					goto NextPagev1;
				}
			}
		}
		else
		{
			NextPage:
		
			while($m2content =~ m/href\=\"([^>]*?)\"[^>]*?class\=\"itemhover\">\s*<span\s*class\=\"do\-title\">/igs)
			{
				my $product_url = $1;
				my $product_object_key;
				if($totalHash{$product_url} ne '')
				{
					print "Data Exists! -> $totalHash{$product_url}\n";
					$product_object_key = $totalHash{$product_url};
				}
				else
				{
					print "New Data\n";
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$totalHash{$product_url}=$product_object_key;
				}
				print "LOOP 1 => $menu1->$menu2\n";
				# Insert Tag values.
				$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
				$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
				$dbobject->commit();
			}
			if($m2content =~ m/goToResultPage\(\'([^>]*?)\'[^>]*?id\=\"WC_CatalogSearchResultDisplay_link_8\"/is)
			{
				my $nextpage = $utilityobject->Trim($1);
				$nextpage =~ s/\s+//igs;
				$m2content = $utilityobject->Lwp_Get($nextpage);
				goto NextPage;
			}
		}
		
	}
	## Colour
	my $filertag = 'Colour';
	while($m1content =~ m/\'Colour\'\)\;\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*</igs)
	{
		my $filterurl = $1;
		my $filtervalue = $2;
		my $fcontent = $utilityobject->Lwp_Get($filterurl);
		
		NextPageC:
		
		while($fcontent =~ m/href\=\"([^>]*?)\"[^>]*?class\=\"itemhover\">\s*<span\s*class\=\"do\-title\">/igs)
		{
			my $product_url = $1;
			my $product_object_key;
			if($totalHash{$product_url} ne '')
			{
				print "Data Exists! -> $totalHash{$product_url}\n";
				$product_object_key = $totalHash{$product_url};
			}
			else
			{
				print "New Data\n";
				$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				$totalHash{$product_url}=$product_object_key;
			}
			print "LOOP 2 => $menu1->$filertag->$filtervalue\n";
			# Insert Tag values.
			$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
			$dbobject->SaveTag($filertag,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
			$dbobject->commit();
		}
		if($fcontent =~ m/goToResultPage\(\'([^>]*?)\'[^>]*?id\=\"WC_CatalogSearchResultDisplay_link_8\"/is)
		{
			my $nextpage = $utilityobject->Trim($1);
			$nextpage =~ s/\s+//igs;
			$fcontent = $utilityobject->Lwp_Get($nextpage);
			goto NextPageC;
		}		
	}
}
$logger->send("$robotname :: Instance Completed  :: $pid\n");
################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################
$dbobject->commit();