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
my $Retailer_Random_String='MSU';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;
my %validate;

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
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy('m&s-uk');
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');
# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Using the argument set the domain URLs'.
my $url = "http://www.marksandspencer.com/";

# Fetch the content based on the domain URLs'.
my $cont = $utilityobject->Lwp_Get($url);
my %ids;

while($cont =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<div\s*id\=\"([^>]*?)\"\s*class\=\"mega\-inner\"\s*data\-cmspot\-id\=\"([^>]*?)\">/igs)
{
	my $key = $utilityobject->Trim($1);
	my $value = $utilityobject->Trim($3);
	$ids{$key}=$value;
}

my $navurl = "http://www.marksandspencer.com/MSTopNavTier3View?catalogId=10051&storeId=10151&langId=-24";

# Fetch the navcontent based on the domain URLs'.
my $content = $utilityobject->Lwp_Get($navurl);
foreach (keys %ids)
{
	my $menu1 = $_;
	next unless($menu1 =~ m/\b$ARGV[0]\b/is);
	while($content =~ m/<div\s*id\=\"$ids{$menu1}\"\s*class\=\"mega\-inner\">([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>\s*<\/div>/igs)
	{
		my $block1 = $1;
		while($block1 =~ m/class\=\"header\">\s*(?:<span[^>]*?>\s*)?\s*([^>]*?)(?:<\/span>\s*)?\s*<\/h2>([\w\W]*?)\s*(?:<li>\s*<h2\s*|<\/div>\s*<\/div>)/igs)
		{
			my $menu2 = $utilityobject->Trim($1);
			my $block2 = $2;
			# next unless($menu1 =~ m/Women/is && $menu2 =~ m/ACCESSORIES/is);
			
			while($block2 =~ m/href\=\"([^>]*?)\">\s*([\w\W]*?)\s*<\/a>/igs)
			{
				my $listurl = $1;
				my $menu3 = $utilityobject->Trim($2);
				# next unless($menu1 =~ m/Men/is && $menu2 =~ m/Clothing/is && $menu3 =~ m/Underwear/is);
				my $listcontent = $utilityobject->Lwp_Get($listurl);
				&URL_Collection($listcontent, $menu1, $menu2, $menu3, '', '', '');
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

sub URL_Collection()
{
	my ($menu_3_content, $menu_1, $menu_2, $menu_3, $menu_4, $menu_5, $menu_6) = @_;
	my $url_append;
	if($menu_3_content=~m/<form\s*class\=\"listing\-sort\"\s*id\=\"listing\-sort\-top\"\s*action\=\"([^>]*?)\"\s*data/is)
	{
		$url_append = $utilityobject->Decode($1);
	}
	while($menu_3_content =~ m/<label\s*class\=\"heading\s*subHead\"[^>]*?>\s*<span>\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/div>\s*<\/div>/igs)
	{
		my $filter = $utilityobject->Trim($1);						
		my $filter_block=$2;					
		$filter=~s/\&\#x28\;/\(/igs;
		$filter=~s/\&\#x29\;/\)/igs;
		next if($filter =~ m/Rating/is);
		while($filter_block=~m/<input\s*type\=\"checkbox\"[^>]*?name\=\"([^>]*?)\"\s*class\=\"checked\"\s*\/>\s*<label\s*class\=\"checkbox[^>]*?>\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
		{
			my $filter_pass=$1;
			my $filter_value=$2;
			my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
			$filter_url =~ s/\s+//igs;
			my $filter_content = $utilityobject->Lwp_Get($filter_url);
			NextPagenew1:
			while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
			{
				my $product_url = $utilityobject->Decode($1);
				$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
				
				&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
			}
			if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
			{
				my $page_no=$1;
				my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
				$filter_content = $utilityobject->Lwp_Get($next_page_url);
				goto NextPagenew1;
			}
		}
		## Only Color
		while($filter_block=~m/<input\s*type\=\"checkbox\"\s*[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*style[^>]*?>\s*<span\s*class\=\"filterOption\s*hidden\">\s*\&nbsp\;\s*([^>]*?)\s*<\/span>/igs)
		{
			my $filter_pass=$1;
			my $filter_value=$2;
			my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
			$filter_url =~ s/\s+//igs;
			my $filter_content=$utilityobject->Lwp_Get($filter_url);
			NextPagenew4:
			while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
			{
				my $product_url=$utilityobject->Decode($1);
				$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
				
				&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
			}
			if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
			{
				my $page_no=$1;
				my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
				$filter_content=$utilityobject->Lwp_Get($next_page_url);
				goto NextPagenew4;
			}
		}
		while($filter_block=~m/<input\s*type\=\"radio\"[^>]*?value\=\"([^>]*?)\"[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*class\=\"radio\-label\"\s*for\=\"radioId\-\d+\">\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
		{
			my $filter_pass=$2.'='.$1;
			my $filter_value=$3;
			# my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
			my $filter_url=$url_append.'&'.$filter_pass."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
			$filter_url =~ s/\s+//igs;
			my $filter_content=$utilityobject->Lwp_Get($filter_url);
			NextPagenew3:
			while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
			{
				my $product_url=$utilityobject->Decode($1);
				$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
				
				&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
			}
			if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
			{
				my $page_no=$1;
				my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
				$filter_content=$utilityobject->Lwp_Get($next_page_url);
				goto NextPagenew3;
			}
		}
	}
	if($menu_3_content =~ m/div\s*class\=\"head\">\s*<a\s*href\=\"\#\"\s*class\=\"heading\s*open\">\s*((?!Size|Price|Rating|Gender)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/fieldset>/is)
	{
		while($menu_3_content=~m/<div\s*class\=\"head\">\s*<a\s*href\=\"\#\"\s*class\=\"heading\s*open\">\s*((?!Size|Price|Rating|Gender)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/fieldset>/igs)
		{
			my $filter=$utilityobject->Trim($1);						
			my $filter_block=$2;					
			$filter=~s/\&\#x28\;/\(/igs;
			$filter=~s/\&\#x29\;/\)/igs;
			next if($filter =~ m/Rating/is);
			while($filter_block=~m/<input\s*type\=\"checkbox\"[^>]*?name\=\"([^>]*?)\"\s*class\=\"checked\"\s*\/>\s*<label\s*class\=\"checkbox[^>]*?>\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$1;
				my $filter_value=$2;
				my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				$filter_url =~ s/\s+//igs;
				my $filter_content = $utilityobject->Lwp_Get($filter_url);
				NextPage1:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url = $utilityobject->Decode($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
				}
				if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
				{
					my $page_no=$1;
					my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
					$filter_content=$utilityobject->Lwp_Get($next_page_url);
					goto NextPage1;
				}
			}
			## Only Color
			while($filter_block=~m/<input\s*type\=\"checkbox\"\s*[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*style[^>]*?>\s*<span\s*class\=\"filterOption\s*hidden\">\s*\&nbsp\;\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$1;
				my $filter_value=$2;
				my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				$filter_url =~ s/\s+//igs;
				my $filter_content=$utilityobject->Lwp_Get($filter_url);
				NextPage4:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url=$utilityobject->Decode($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
				}
				if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
				{
					my $page_no=$1;
					my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
					$filter_content=$utilityobject->Lwp_Get($next_page_url);
					goto NextPage4;
				}
			}
			while($filter_block=~m/<input\s*type\=\"radio\"[^>]*?value\=\"([^>]*?)\"[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*class\=\"radio\-label\"\s*for\=\"radioId\-\d+\">\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$2.'='.$1;
				my $filter_value=$3;
				# my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				my $filter_url=$url_append.'&'.$filter_pass."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				$filter_url =~ s/\s+//igs;
				my $filter_content=$utilityobject->Lwp_Get($filter_url);
				NextPage3:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url=$utilityobject->Decode($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
				}
				if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
				{
					my $page_no=$1;
					my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
					$filter_content=$utilityobject->Lwp_Get($next_page_url);
					goto NextPage3;
				}
			}
		}
	}
	else
	{
		NextPageAV:
		while($menu_3_content =~ m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
		{
			my $product_url=$utilityobject->Decode($1);
			$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
			&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,'','');
		}
		if($menu_3_content =~ m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
		{
			my $nexturl = $1;
			$nexturl = $url_append.'&pageChoice='.$nexturl;
			$menu_3_content=$utilityobject->Lwp_Get($nexturl);
			goto NextPageAV;
		}
	}
}

sub db_insert()
{
	my ($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue) = @_;
	# print "$menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue\n";
	my $product_object_key;
	$product_url = "http://www.marksandspencer.com".$product_url unless($product_url =~ m/^http/is);
	
	if($validate{$product_url} eq '')
	{ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
		$product_object_key=$dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String); # GENERATING UNIQUE PRODUCT ID
		$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
	}
	$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
	
	unless($menu1=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($menu2=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($menu3=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($menu4=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($menu5=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_5',$menu5,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($menu6=~m/^\s*$/is)
	{
		$dbobject->SaveTag('Menu_6',$menu6,$product_object_key,$robotname,$Retailer_Random_String);
	}
	unless($filtervalue=~m/^\s*$/is)
	{
		$dbobject->SaveTag($filter,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String);
	}
	$dbobject->commit();	
	
	if($product_url=~m/\/p\/ds/is)
	{
		&db_insert_multi_item($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue);
	}
}

sub db_insert_multi_item()
{
	my ($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue)=@_;
	
	my $product_url_content=$utilityobject->Lwp_Get($product_url); 
	my $product_object_key;
	
	while($product_url_content=~m/<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>[^>]*?<\/a>\s*<\/div>\s*<input[^>]*?>\s*<div[^>]*? class\s*\=\s*\"product\"[^>]*?>/igs)
	{
		my $product_url1=$1;
		$product_url1=$utilityobject->Trim($product_url1);
		$product_url1 = "http://www.marksandspencer.com".$product_url1 unless($product_url1 =~ m/^http/is);
		
		if($validate{$product_url1} eq '')
		{ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key = $dbobject->SaveProduct($product_url1,$robotname,$retailer_id,$Retailer_Random_String); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url1}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url1}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
		
		unless($menu1=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu2=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu3=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu4=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu5=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_5',$menu5,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($menu6=~m/^\s*$/is)
		{
			$dbobject->SaveTag('Menu_6',$menu6,$product_object_key,$robotname,$Retailer_Random_String);
		}
		unless($filtervalue=~m/^\s*$/is)
		{
			$dbobject->SaveTag($filter,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String);
		}
		$dbobject->commit();
	}
}