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
my $Retailer_Random_String='Zap';
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
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Using the argument set the domain URLs'.
my %totalHash;
############ URL Collection ##############
# Using the argument set the Values'.
my ($menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $mainurl);
my $argcount = @ARGV;
print "Total Args :: $argcount\n";
if($argcount == 5)
{
	$menu1 = $ARGV[0];
	$menu2 = $ARGV[1];
	$menu3 = $ARGV[2];
	$menu4 = $ARGV[3];
	$mainurl = $ARGV[4];
}
elsif($argcount == 7)
{
	$menu1 = $ARGV[0];
	$menu2 = $ARGV[1];
	$menu3 = $ARGV[2];
	$menu4 = $ARGV[3];
	$menu5 = $ARGV[4];
	$menu6 = $ARGV[5];
	$mainurl = $ARGV[6];
}
else
{
	print "No Arguments (OR) Wrong Arguments\n";
	exit;
}
my $menucontent3 = $utilityobject->Lwp_Get($mainurl);
while($menucontent3	 =~ m/<h4\s*class\=\"stripeOuter\s*navOpen\">\s*<span>\s*<\/span>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/div>/igs)
{
	my $menu7 = $utilityobject->Trim($1);
	my $subcont3 = $2;
	next if($menu7 =~ m/Brand|Size|Price|Rating|Width|Height/is);
	while($subcont3 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
	{
		my $menuurl4 = $1;
		my $menu8 = $utilityobject->Trim($2);
		print "$menu1->$menu2->$menu3->$menu4->$menu5->$menu6->$menu7->$menu8\n";
		$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
		my $menucontent4 = $utilityobject->Lwp_Get($menuurl4); 
		my $lastid = $2 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
		my $lasturl = $1 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
		my $i=2;
		NEXTPage:
		while($menucontent4 =~ m/href\=\"([^>]*?)\"\s*class\=\"product[^>]*?\"\s*data\-style\-id\=\"[^>]*?\"\s*data\-product\-id\=\"([^>]*?)\"/igs) 
		{ 
			my $purl = $utilityobject->Trim($1);
			my $skuid = $utilityobject->Trim($2);
			$purl = "http://www.zappos.com".$purl unless($purl =~ m/^http/is);
			my $product_object_key;
			if($totalHash{$skuid} ne '')
			{
				print "Data Exists! -> $totalHash{$skuid}\n";
				$product_object_key = $totalHash{$skuid};
			}
			else
			{
				print "New Data\n";
				$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
				$totalHash{$skuid}=$product_object_key;
			}
			$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) unless($menu1 eq '');
			$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) unless($menu2 eq '');
			$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String) unless($menu3 eq '');
			$dbobject->SaveTag($menu5,$menu6,$product_object_key,$robotname,$Retailer_Random_String) unless($menu5 eq '');
			$dbobject->SaveTag($menu7,$menu8,$product_object_key,$robotname,$Retailer_Random_String) unless($menu7 eq '');
			$dbobject->commit();
		} 
		while ($i<=$lastid)
		{
			my $pc = $i;
			$pc--;
			$lasturl = "http://www.zappos.com".$lasturl unless($lasturl =~ m/^http/is);
			print "NEXTPAGE => $lasturl\n";
			$lasturl =~ s/\-page\d+/\-page$i/is;
			$lasturl =~ s/p\=\d+/p\=$pc/is;
			print $lasturl,"\n"; #exit;
			$menucontent4 = $utilityobject->Lwp_Get($lasturl);
			$i++;
			goto NEXTPage;
		}
	}
}
# To indicate script has completed in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Once script has complete send a msg to logger.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Committing the transaction.
$dbobject->commit();
