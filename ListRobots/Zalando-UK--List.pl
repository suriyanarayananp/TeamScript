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
my $Retailer_Random_String='Zal';
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
############ URL Collection ##############   
my $content = $utilityobject->Lwp_Get("https://www.zalando.co.uk/"); 
   $content = $utilityobject->Lwp_Get($ARGV[0]); 
my $menu1 = $ARGV[1];
my $menu2 = $ARGV[2];
my $menu3 = $ARGV[3];
my $menu4 = $ARGV[4];
if(@ARGV == 5)
{
	while($content =~ m/class\=\"fLabel\"\s*[^>]*?>\s*([^>]*?)\s*<\/span>([\w\W]*?)value\=\"(?:close|Apply)\"[^>]*?>\s*(?:<\/form>\s*)?<\/div>\s*<\/div>/igs)
	{
		my $menu5 = $utilityobject->Trim($1);
		my $cont5 = $2;
		next if($menu5 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand/is);
		while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\">|href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
		{
			my $catlink5 = $1.$3.$5;
			my $menu6 = $utilityobject->Trim($2.$4.$6);
			$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = $utilityobject->Lwp_Get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu5,$menu6,$cont6);
		}
	}
	
}
elsif($content =~ m/class\=\"parentCat\">\s*<span\s*class\=\"isActive\s*[^>]*?>\s*(?:<b>\s*<\/b>)?\s*([^>]*?)\s*<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>/is)
{
	my $menu3  = $utilityobject->Trim($1);
	my $cont2_sub = $2;
	while($cont2_sub =~ m/href\=\"([^>]*?)\"[^>]*?>\s*(?:<b>\s*<\/b>\s*)?([^>]*?)\s*</igs)
	{
		my $catlink3 = $1;
		my $menu4 = $utilityobject->Trim($2); #Menu4 -> Bra  {Swimming Trunks}
		$catlink3 = "https://www.zalando.co.uk/".$catlink3 unless($catlink3 =~ m/^http/is);
		my $subcontent = $utilityobject->Lwp_Get($catlink3);
		if($subcontent =~ m/class\=\"parentCat\">\s*<span\s*class\=\"isActive\s*[^>]*?>\s*(?:<b>\s*<\/b>)?\s*([^>]*?)\s*<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>/is)
		{
			my $menu4  = $utilityobject->Trim($1); #Menu4 -> Bra  {Swimming Trunks}
			my $cont3_sub = $2;
			while($cont3_sub =~ m/href\=\"([^>]*?)\"[^>]*?>\s*(?:<b>\s*<\/b>\s*)?([^>]*?)\s*</igs)
			{
				my $catlink4 = $1;
				my $menu5 = $utilityobject->Trim($2); #Menu5 -> Balcontee  {Tunks/Shorts}
				$catlink4 = "https://www.zalando.co.uk/".$catlink4 unless($catlink4 =~ m/^http/is);
				my $cont4 = $utilityobject->Lwp_Get($catlink4);
				while($cont4 =~ m/class\=\"fLabel\"\s*[^>]*?>\s*([^>]*?)\s*<\/span>([\w\W]*?)value\=\"(?:close|Apply)\"[^>]*?>\s*(?:<\/form>\s*)?<\/div>\s*<\/div>/igs)
				{
					my $menu6 = $utilityobject->Trim($1);
					my $cont5 = $2;
					next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
					while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
					{
						my $catlink5 = $1.$3;
						my $menu7 = $utilityobject->Trim($2.$4);
						$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = $utilityobject->Lwp_Get($catlink5); 
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
				}
				while($cont4 =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/igs)
				{
					my $menu6 = $utilityobject->Trim($1);
					my $cont5 = $2;
					while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
					{
						my $menu7 = $utilityobject->Trim($1);
						my $catlink5 = $2;		
						# next if($menu7 !~ m/Gray/is);						
						$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = $utilityobject->Lwp_Get($catlink5); 
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
					while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
					{
						my $catlink5 = $1;
						my $menu7 = $utilityobject->Trim($2);
						$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = $utilityobject->Lwp_Get($catlink5); 
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
				}
			}
		}
		else
		{
			while($subcontent =~ m/<div\s*class\=\"filter\">\s*<div\s*class\=\"title\">\s*<label>\s*([^>]*?)\s*<\/label>\s*<\/div>([\w\W]*?)<\/div>/igs)
			{
				my $menu6 = $utilityobject->Trim($1);
				my $cont5 = $2;
				next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
				while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $catlink5 = $1.$3;
					my $menu7 = $utilityobject->Trim($2.$4);
					$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = $utilityobject->Lwp_Get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
			}
			while($subcontent =~ m/class\=\"fLabel\"\s*[^>]*?>\s*([^>]*?)\s*<\/span>([\w\W]*?)value\=\"(?:close|Apply)\"[^>]*?>\s*(?:<\/form>\s*)?<\/div>\s*<\/div>/igs)
			{
				my $menu5 = $utilityobject->Trim($1);
				my $cont5 = $2;
				next if($menu5 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand/is);
				while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\">|href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $catlink5 = $1.$3.$5;
					my $menu6 = $utilityobject->Trim($2.$4.$6);
					$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = $utilityobject->Lwp_Get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu5,$menu6,$cont6);
				}
			}
			while($subcontent =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/igs)
			{
				my $menu6 = $utilityobject->Trim($1);
				my $cont5 = $2;				
				while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
				{					
					my $menu7 = $utilityobject->Trim($1);
					my $catlink5 = $2;
					$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = $utilityobject->Lwp_Get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
				while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{
					my $catlink5 = $1;
					my $menu7 = $utilityobject->Trim($2);
					$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = $utilityobject->Lwp_Get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
			}
		}
	}
}
else
{
	while($content =~ m/class\=\"fLabel\"\s*[^>]*?>\s*([^>]*?)\s*<\/span>([\w\W]*?)value\=\"(?:close|Apply)\"[^>]*?>\s*(?:<\/form>\s*)?<\/div>\s*<\/div>/igs)
	{
		my $menu4 = $utilityobject->Trim($1);
		my $cont5 = $2;
		next if($menu4 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand/is);
		
		while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\">|href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
		{
			my $catlink5 = $1.$3.$5;
			my $menu5 = $utilityobject->Trim($2.$4.$6);
			$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = $utilityobject->Lwp_Get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu4,$menu5,$cont6);
		}
	}			
	while($content =~ m/<div\s*class\=\"filter\">\s*<div\s*class\=\"title\">\s*<label>\s*([^>]*?)\s*<\/label>\s*<\/div>([\w\W]*?)<\/div>/igs)
	{
		my $menu6 = $utilityobject->Trim($1);
		my $cont5 = $2;
		next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
		while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
		{
			my $catlink5 = $1.$3;
			my $menu7 = $utilityobject->Trim($2.$4);
			$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = $utilityobject->Lwp_Get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}
	}
	while($content =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/igs)
	{
		my $menu6 = $utilityobject->Trim($1);
		my $cont5 = $2;
		while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
		{					
			my $menu7 = $utilityobject->Trim($1);
			my $catlink5 = $2;
			$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = $utilityobject->Lwp_Get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}
		while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $catlink5 = $1;
			my $menu7 = $utilityobject->Trim($2);
			$catlink5 = "https://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = $utilityobject->Lwp_Get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}		
	}
}
sub collect_product()
{
	my ($menu_1, $menu_2, $menu_3, $menu_4, $menu_5, $menu_6, $menu_7, $category_content) = @_;
	print "$menu_1->$menu_2->$menu_3->$menu_4->$menu_5->$menu_6->$menu_7\n";
	nextpage:
	if($category_content=~m/<div\s*class\=\"pager\s*\">([\w\W]*?)<div\s*class\=\"pager\s*pBottom\s*cleaner\">/is)
	{
		my $block=$1;
		while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="https://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_4',$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_5',$menu_5,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				$dbobject->SaveTag($menu_6,$menu_7,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}
	elsif($category_content=~m/Sort\s*by\:([\w\W]*?)<div\s*class\=\"pager\s*pBottom\s*cleaner\">/is)
	{
		my $block=$1;
		while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="https://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_4',$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_5',$menu_5,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				$dbobject->SaveTag($menu_6,$menu_7,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}
	elsif($category_content =~ m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/is)
	{
		while($category_content=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="https://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_4',$menu_4,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				$dbobject->SaveTag('Menu_5',$menu_5,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				$dbobject->SaveTag($menu_6,$menu_7,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}
	if($category_content=~m/<link\s*rel="next"\s*href\=\"([^>]*?)\"\s*\/>/is)
	{
		my $next_page_url=$1;	
		$category_content = $utilityobject->Lwp_Get($next_page_url);
		goto nextpage;
		
	}
    elsif($category_content=~m/<span\s*class\=\"current\">[\d]+<\/span>\s*<\/li><li>\s*<a\s*href\=\"([^>]*?)\">/is)
	{
		my $next_page_url="https://www.zalando.co.uk/$1";	
		$category_content = $utilityobject->Lwp_Get($next_page_url);
		goto nextpage;
	}
}

