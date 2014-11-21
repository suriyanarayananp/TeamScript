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
my $retailer_name='h&m-ge';
# $retailer_name =~ s/\-\-List\s*$//igs;
# $retailer_name = lc($retailer_name);
my $Retailer_Random_String='H&m';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
print "ip: $ip\n";
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
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,'h&m-ge','start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START','h&m-ge');

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Getting the content of the Home Page. 
my $content = $utilityobject->Lwp_Get("http://www.hm.com/de/"); 

my $robo_menu=$ARGV[0];

# Pattern match from Array one by one.(Eg. Menu1=> Ladies) 
while ( $content =~ m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>\s*<div>([\w\W]*?)<\/div>/igs )
{
	my $url1 = $1;
	my $menu1 = $utilityobject->Trim($2);  
	my $menu1_Block = $3; 
	
	$menu1_Block=$menu1_Block.'<strong';

	if($menu1!~m/$robo_menu/is)
	{
		next; 
	}
	
	next if($menu1=~m/Home/is); # Skipped as per the Assesment Sheet
	
	###if($menu1_Block =~ m/>\s*([^>]*?)\s*<\/strong><\/li>([\w\W]*?)<strong/is)  	
	while($menu1_Block =~ m/>\s*([^>]*?)\s*<\/strong><\/li>([\w\W]*?)<strong/igs)  		
	{
		my $menu11=$1;
		my $subcont2 = $2;
		print "Menu head:: $menu11\n";
		
		next if(($menu1=~m/Sale/is)&&($menu11=~m/Home/is)); # Skipped as per the Assesment Sheet
		
		# Pattern match to get URLs from the above block and it's Menu(Menu2=>NEW ARRIVALS).
		while($subcont2 =~ m/<li>\s*<a\s*href\=\"([^>]*?)\"[^>]*?>([^>]*?)<\/a><\/li>/igs)
		{
			my $url3 = $1;
			my $menu2 = $utilityobject->Trim($2);
			my $subcont3 = $utilityobject->Lwp_Get($url3); 
			
			
			# Pattern match to take filter header name and it's block like "Colour /Size / Concepts" to filter Products.
		
			while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>\s*(<ul>[\w\W]*?<\/ul>)\s*<\/div>/igs)
			{
				my $menu3 = $utilityobject->Trim($1); 
				my $subcont4 = $2;
				print "MENU3:: $menu3\n";
				# if($menu3=~m/Konzepte/is)
				# {
					# print "Koncepte TAG\n";
					# open(fh,">Concept_tag.html");
					# print fh "$subcont4";
					# close fh;
					#<STDIN>;
					###exit;
				# }
				
				next if($menu3 =~ m/Size|Price|Ratings|Größe/is); # Pattern match to skip if filter header like "Size/Price/Ratings".						
				
				# Pattern match to take Filter values and their URLs under corresponding Filter header.(Value: White/Red).						
				##while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"[^>]*?rel\=\"nofollow\">\s*<li\s*data\-metricsName[^>]*?alt\=\"([^>]*?)\">/igs)
				while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"[^>]*?rel\=\"nofollow\">\s*<li\s*data\-metricsName[^>]*?alt\=\"([^>]*?)\">|<a\s*href\=\"([^>]*?)\"[^>]*?rel\=\"nofollow\">\s*[\w\W]*?<\/div>\s*<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<\/li>/igs)
				{
					my $url4 = $1.$3;
					my $menu4 = $utilityobject->Trim($2.$4); # White/Red.
					$url4 = $url4.'&xhr=true';
					my $subcont5 = $utilityobject->Lwp_Get($url4); 
					
					print "MENU3:: $menu3 \t MENU4:: $menu4 ::: URL::: $url4\n";
					##<STDIN>;
					
					NEXTPage:
					# Pattern match to collect products.
					while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
					{
						my $purl = $1;
						print "Product URL:: $purl\n";
						next if($purl=~m/SIMILAR_TO_SD$/is); # Pattern match to skip URLs to take Exact product URLs from the corresponding Page.(Leads to Tag Issue otherwise).
						$purl =~ s/\?[^>]*?$//igs;
						print "Product URL:: $purl\n";
						my $product_object_key;
						if($totalHash{$purl} ne '')
						{
							$product_object_key = $totalHash{$purl};
						}
						else
						{
							$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
							$totalHash{$purl}=$product_object_key;
						}
						# Save the Tag information based on the Product ID and its tag values.
						unless($menu1=~m/^\s*$/is)
						{
							$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
						}
						unless($menu11=~m/^\s*$/is)
						{
							$dbobject->SaveTag('Menu_2',$menu11,$product_object_key,$robotname,$Retailer_Random_String);
						}
						unless($menu2=~m/^\s*$/is)
						{
							$dbobject->SaveTag('Menu_3',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
						}
						unless($menu4=~m/^\s*$/is)
						{
							$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
						}
						$dbobject->commit();
					}
					# Pattern match to get Next page URL.
					if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
					{
						my $next = $1;
						my $turl = $url4;
						$turl =~ s/\?([^>]*?)$//igs;
						$next = $turl.$next unless($next =~ m/^http/is);
						next if($next =~ m/\#/is);
						$subcont5 = $utilityobject->Lwp_Get($next); 
						goto NEXTPage;
					}
				}
			}
			
		}
	}
}

$logger->send("$robotname :: Instance Completed  :: $pid\n");
#################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$dbobject->commit();