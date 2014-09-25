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
my $Retailer_Random_String='Coa';
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

# Getting home page content.
my $content = $utilityobject->Lwp_Get("http://www.coast-stores.com/?lng=en&ctry=GB&");
# open FH , ">home.html" or die "File not found\n";
# print FH $content;
# close FH;
my %hash_id;

############ URL Collection ##############

while($content=~m/\"\s*level_1\s*\"[^>]*?>(?:\s*<[^>]*?>\s*)*([^>]*?)<([\w\W]*?)<\/div>\s*<\/li>\s*(?:<li class\s*\=\s*\"\s*level_1\s*\"|<[^>]*?Search element[^>]*?>)/igs)  ###Newin ,Clothing, Etc. all Block
{	
	my $menu_1=$1;
	my $menu_1_block=$2;
	
	print "menu_1 $menu_1\n";
	
	while($menu_1_block=~m/<a[^>]*?class\s*\=\s*\"\s*level_2\s*\"\s*href\s*\=\"([^>]*?)\"[^>]*?>([^<]*?)</igs) ####Newin ,Clothing, Etc. sep Block.
	{
		my $menu_2_url=$1;
		my $menu_2=$utilityobject->Trim($2);
		my $menu_2=$utilityobject->Decode($menu_2);
		
		print "menu_2 $menu_2\n";
		
		&collect_product($menu_2_url,$menu_1,$menu_2,'','');
		
		my $menu_2_content = $utilityobject->Lwp_Get($menu_2_url);
		
		if($menu_2_content=~m/\"\s*filter_title\s*\"[^>]*?>\s*(Colour)\s*<([\w\W]*?)<\/ul>/is)
		{
			my $filter_header=$1;
			my $filter_block=$2;  
			
			print "filter_header $filter_header\n";			
			
			while($filter_block=~m/<a[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*"[^>]*?>\s*([^>]*?)\s*</igs)
			{
				my $filter_value_url=$1;
				my $filter_value=$2;
				$filter_value=~s/\s/\+/igs;
				
				my $menu_2_url_aj=$1 if($menu_2_url=~m/\/([^\/]*?)\/dept/is);
				
				print "filter_value $filter_value\n";			
				
				$filter_value_url="http://www.coast-stores.com/pws/AJProductFiltering.ice?layout=ajaxlist.layout&value="."$menu_2_url_aj"."&paId=wc_dept&filters=MASTER_COLOUR!".$filter_value."&page=0&loadCat=true";
				
				print "filter_value_url>> $filter_value_url\n";
				
				$filter_value=~s/\+[^<]*?$//igs;
				$filter_value=~s/([^<]*?)s$/$1/igs;
				my $filter_value_temp;
				
				# To Change color case.
				$filter_value = lc($filter_value);
				
				while($filter_value =~ m/([^>]*?)(?:\s+|$)/igs) # Splitting colour to get colour value to make case sensitive.
				{
					 if($filter_value_temp eq '')
					 {
					   $filter_value_temp = ucfirst($1);
					 }
					 else
					 {
					   $filter_value_temp = $filter_value_temp.' '.ucfirst($1);
					 }
				}
				
				print "filter_value $filter_value\n";			
				
				print "filter_value_url $filter_value_url\n";			
				
				&collect_product($filter_value_url,$menu_1,$menu_2,$filter_header,$filter_value_temp);				
			}
		}
	}
}

$logger->send("$robotname :: Instance Completed  :: $pid\n");
#################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$dbobject->commit();

sub collect_product()
{	
	my $List_Page_url=shift;
	my $menu_11=shift;
	my $menu_22=shift;
	my $filter_header1=shift;
	my $filter_value1=shift;
	
	print "menu: $menu_11\t$menu_22\t$filter_header1\t$filter_value1\n";
	
	my $List_Page_conetnt=$utilityobject->Lwp_Get($List_Page_url);
	my $count=0;
	
next_page1:
	while($List_Page_conetnt=~m/<p[^<]*?class\=\"product_title\"[^>]*?>\s*<a[^<]*?href\=\"([^<]*?)\"[^>]*?>/igs)
	{
		my $prod_url=$1;
		$prod_url =~ s/amp\;//g;
		
		$count++;
		
		my $product_object_key;
		my $prod_id=$1 if($prod_url=~m/product\s*\/\s*(\d+)\s*$/is);
		if($hash_id{$prod_id} eq '')
		{
			$product_object_key = $dbobject->SaveProduct($prod_url,$robotname,$retailer_id,$Retailer_Random_String);
			$hash_id{$prod_id}=$product_object_key;
		}
		$product_object_key=$hash_id{$prod_id};
		
		#Insert Product values
		$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
		
		unless($menu_22=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($filter_header1=~m/^\s*$/is)
		{
			$dbobject->SaveTag($filter_header1,$filter_value1,$product_object_key,$robotname,$Retailer_Random_String);
		}
		$dbobject->commit();
	}
	print "count: $count\n";
	
	if($List_Page_conetnt=~m/<a[^<]*?href\=\"([^<]*?)\">\s*Next\s*page\s*<\/a>/is)
	{
		my $next_url=$1;
		$List_Page_conetnt = $utilityobject->Lwp_Get($next_url);
		goto next_page1;
	}	
}
