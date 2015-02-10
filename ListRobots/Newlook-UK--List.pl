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
my $Retailer_Random_String='New';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Setting the UserAgent.
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent('WGSN;+44 207 516 5099;datacollection@wgsn.com');
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
my $content = $utilityobject->Lwp_Get("http://www.newlook.com"); 
while($content =~ m/<li\s*id\=\"li\d+\"\s*><a\s*href\=\"([^>]*?)">\s*<h2[^>]*?>\s*([^>]*?)\s*<\/h2>/igs) 
{ 
    my $caturl = $1; 
	my $menu1 = $utilityobject->Trim($2); 
	next unless($menu1 =~ m/$ARGV[0]/is);
	$caturl='http://www.newlook.com'.$caturl unless($caturl=~m/^\s*http\:/is);
	my $menucontent = $utilityobject->Lwp_Get($caturl); 
    if(($menu1 =~ m/$ARGV[0]/is) and ($menu1 !~ m/maternity|Size|New\s*in/is))
    { 
		while($menucontent =~ m/h4>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/ul>/igs) 
        { 
			my $menu2 = $utilityobject->Trim($1);  #Womens New IN
			my $tempcont = $2;            
			# next if($menu2 =~ m/View\s*all/is);  #skip View All
			while($tempcont =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
			{
				my $caturl2 = $1;
				my $menu3 = $utilityobject->Trim($2); #View All Clothing Footwear
				$caturl2 = 'http://www.newlook.com'.$caturl2 unless($caturl2 =~ m/^\s*http\:/is);
				#next if($menu3 =~ m/View\s*all/is);  #skip View All
				my $menucontent2 = $utilityobject->Lwp_Get($caturl2); 
				while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
				{
					my $menu4 = $utilityobject->Trim($1); #Type
					my $tempcont2 = $2;
					if($menucontent2 =~ m/breadcrumbRemoveText/is)
					{
						next if($menu4 =~ m/Type|Height|Style/is);
					}
					next if($menu4 =~ m/Size|Price|Rating/is);
					while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu5 = $utilityobject->Trim($2); #Tops
						$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
						my $menucontent3 = $utilityobject->Lwp_Get($caturl3);
						NEXT:
						while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
						{
							my $product_url = $1;
							$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
							my ($product_object_key, $pids);
							if($product_url =~ m/_([\d+]{7})/is)
							{
								$pids = $1;
							}
							if($totalHash{$pids} ne '')
							{
								$product_object_key = $totalHash{$pids};
							}
							else
							{
								$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
								$totalHash{$pids}=$product_object_key;
							}
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) unless($menu1 eq '');
							$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) unless($menu2 eq '');
							$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) unless($menu3 eq '');
							$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String) unless($menu4 eq '');
							$dbobject->commit();
						}
						if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
						{
							my $next = $1;
							$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
							$menucontent3 = $utilityobject->Lwp_Get($next); 
							goto NEXT;
						}
					}
				}
			}
        }
    }
	elsif(($menu1 =~ m/$ARGV[0]/is) and ($menu1 =~ m/maternity|New\s*In|Size/is))
	{
		if($menucontent =~ m/<h2[^>]*?>\s*$menu1\s*<\/h2>([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $subcont = $1;
			while($subcont =~ m/<div\s*class\=\"column\">\s*<ul\s*>\s*<li\s*>\s*([^>]*?)\s*<\/li>([\w\W]*?)(?:<\/ul>|<li\s*class\=\"seperator\")/igs)
			{
				my $menu2 = $utilityobject->Trim($1);
				my $subcont2 = $2;
				while($subcont2 =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $caturl2 = $1; 
					my $menu3 = $utilityobject->Trim($2); 
					$caturl2='http://www.newlook.com'.$caturl2 unless($caturl2=~m/^\s*http\:/is);
					my $menucontent2 = $utilityobject->Lwp_Get($caturl2); 
					while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
					{
						my $menu4 = $utilityobject->Trim($1); #Type
						my $tempcont2 = $2;
						next if($menu4 =~ m/Size|Price|Rating/is);
						while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
						{
							my $caturl3 = $1;
							my $menu5 = $utilityobject->Trim($2); #Tops
							$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
							my $menucontent3 = $utilityobject->Lwp_Get($caturl3); 
							NEXT2:
							while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
							{
								my $product_url = $1;
								$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
								my ($product_object_key, $pids);
								if($product_url =~ m/_([\d+]{7})/is)
								{
									$pids = $1;
								}
								if($totalHash{$pids} ne '')
								{
									$product_object_key = $totalHash{$pids};
								}
								else
								{
									$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
									$totalHash{$pids}=$product_object_key;
								}
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) unless($menu1 eq '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) unless($menu2 eq '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) unless($menu3 eq '');
								$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String) unless($menu4 eq '');
								$dbobject->commit();
							}
							if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
							{
								my $next = $1;
								$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
								$menucontent3 = $utilityobject->Lwp_Get($next); 
								goto NEXT2;
							}
						}
					}
				}
			}
			while($subcont =~ m/\"seperator\"[^>]*?>(?:<span[^>]*?>)?\s*([^>]*?)\s*(?:<\/span>\s*)?<\/li>\s*([\w\W]*?)(?:<\/ul>|<li\s*class\=)/igs)## SAle
			{
				my $menu2 = $utilityobject->Trim($1);
				my $subcont2 = $2;
				while($subcont2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{
					my $caturl2 = $1; 
					my $menu3 = $utilityobject->Trim($2); 
					$caturl2='http://www.newlook.com'.$caturl2 unless($caturl2=~m/^\s*http\:/is);
					my $menucontent2 = $utilityobject->Lwp_Get($caturl2); 
					while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
					{
						my $menu4 = $utilityobject->Trim($1); #Type
						my $tempcont2 = $2;
						next if($menu4 =~ m/Size|Price|Rating/is);
						while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
						{
							my $caturl3 = $1;
							my $menu5 = $utilityobject->Trim($2); #Tops
							$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
							my $menucontent3 = $utilityobject->Lwp_Get($caturl3); 
							NEXT2:
							while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
							{
								my $product_url = $1;
								$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
								my ($product_object_key, $pids);
								if($product_url =~ m/_([\d+]{7})/is)
								{
									$pids = $1;
								}
								if($totalHash{$pids} ne '')
								{
									$product_object_key = $totalHash{$pids};
								}
								else
								{
									$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
									$totalHash{$pids}=$product_object_key;
								}
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) unless($menu1 eq '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) unless($menu2 eq '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) unless($menu3 eq '');
								$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String) unless($menu4 eq '');
								$dbobject->commit();
							}
							if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
							{
								my $next = $1;
								$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
								$menucontent3 = $utilityobject->Lwp_Get($next); 
								goto NEXT2;
							}
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