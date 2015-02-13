#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
use utf8;
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Variable Initialization
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Sab';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;

# User Agent
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the config file
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) {
	# Die if reading the settings failed
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Conect to Utility package
my $utilityobject = AnorakUtility->new($logger,$ua);

# Getting Retailer_id & Proxy
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment
$utilityobject->SetEnv($ProxySetting);

# Sending the retailer starting information to dashboard
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Sending retailer starting information to logger 
$logger->send("$robotname :: Instance Started :: $pid\n");

# Main URL 
my $url = 'http://www.saba.com.au';
my $content = $utilityobject->Lwp_Get($url);

# Extraction of the Menu 1 and Menu 1 URL
while($content=~m/<a\s*href\=\"([^>]*?)\"[^>]*?class\=\"level\-1[^>]*?>\s*([^>]*?)\s*<\/a>\s*<div\s*class\=\"level\-2([\w\W]*?)<\/div>\s*<\/div>/igs)
{
	my $menu_1_url=$1;
	my $menu_1=$utilityobject->Trim($2);
	my $menu_1_block=$3;
	
	# Skipping the Saba Style menu
	next if($menu_1=~m/SABA\s*Style/is);

	if($menu_1=~m/SUIT\s*STORE/is)
	{
		while($menu_1_block=~m/<div\s*class\=\"level\-2\">\s*([\w\W]*?)\s*<\/a>[\w\W]*?<ul\s*class\=\"level\-3\">([\W\w]*?)<\/ul>/igs)
		{			
			my $menu_2=$utilityobject->Trim($1);
			my $menu_2_Block=$2;
			while($menu_2_Block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs)
			{
				my $menu_3_url=$1;
				my $menu_3=$utilityobject->Trim($2);				
				my $menu_3_content=$utilityobject->Lwp_Get($menu_3_url);
				
				# Extraction of colour heading and Block
				if($menu_3_content=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is)
				{
					my $colour1=$1;
					my $Colour_block=$2;
				
					# Extraction of Colours and its Naviagtion URL
					while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
					{
						my $Colour=$utilityobject->Trim($1);
						my $Colour_url=$2;
						$Colour_url=~s/\&amp\;/&/igs;
						
						# Colour URL formating for listing all the proucts in single page
						if($Colour_url=~m/\?/is)
						{
							$Colour_url=$Colour_url.'&format=ajax&format=ajax';
						}
						else
						{
							$Colour_url=$Colour_url.'?format=ajax&format=ajax';
						}
						
						my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
						
						# Calling the product collection sub-routine
						&collect_product($Colour_content,$menu_1,$menu_2,$Colour,$menu_3,$colour1);
					}
				}
			}
		}
	}
	
	my $menu_1_content = $utilityobject->Lwp_Get($menu_1_url);
		
	# Extraction of Menu 2 URL and Menu 2
	while($menu_1_content=~m/<a[^>]*?class\=\"refinement\-link[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
	{
		my $menu_2_url=$1;
		my $menu_2=$utilityobject->Trim($2);		
		
		$menu_2_url=$menu_2_url.'all-denim/' if($menu_2=~m/Denim/is);	
		$menu_2_url=$menu_2_url.'stripes/' if($menu_2=~m/Trends/is);
		
		my $menu_2_content=$utilityobject->Lwp_Get($menu_2_url);
		
		# Extraction of colour heading and Block
		if($menu_2_content=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is)
		{
			my $colour1=$1;
			my $Colour_block=$2;
			
			# Extraction of Colours and its Naviagtion URL
			while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
			{
				my $Colour=$utilityobject->Trim($1);
				my $Colour_url=$2;
				$Colour_url=~s/\&amp\;/&/igs;
				
				# Colour URL formating for listing all the proucts in single page
				if($Colour_url=~m/\?/is)
				{
					$Colour_url=$Colour_url.'&format=ajax&format=ajax';
				}
				else
				{
					$Colour_url=$Colour_url.'?format=ajax&format=ajax';
				}
				
				my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
				
				# Calling the product collection sub-routine
				&collect_product($Colour_content,$menu_1,$menu_2,$Colour,'',$colour1);
			}
		}
			
		# Extraction of Image Block		
		if($menu_2_content=~m/class\=\"level-1[^>]*?\">\s*$menu_1\s*<\/a>([\w\W]*?)<\!\-\-\s*end\s*div_three\-col\-group\s*\-\->/is)
		{
			my $menu_2_block=$1;
			if($menu_2_block=~m/>\s*$menu_2\s*<\/a>\s*<div\s*class\=\"level\-3\">\s*<ul\s*class\=\"level\-3\">([\w\W]*?)<\/div>/is)
			{
				my $menu_3_block=$1;
				
				# Extraction of Menu 3
				while($menu_3_block=~m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{				
					my $menu_3_url=$1;
					my $menu_3=$utilityobject->Trim($2);
					next if($menu_3=~m/Under\s*\$[\d\s]+/is);
					my $menu_3_content=$utilityobject->Lwp_Get($menu_3_url);
					
					# Extraction of colour heading and Block
					if($menu_3_content=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is)
					{
						my $colour1=$1;
						my $Colour_block=$2;
						
						# Extraction of Colours and its Naviagtion URL
						while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
						{
							my $Colour=$utilityobject->Trim($1);
							my $Colour_url=$2;
							$Colour_url=~s/\&amp\;/&/igs;
							
							# Colour URL formating for listing all the proucts in single page
							if($Colour_url=~m/\?/is)
							{
								$Colour_url=$Colour_url.'&format=ajax&format=ajax';
							}
							else
							{
								$Colour_url=$Colour_url.'?format=ajax&format=ajax';
							}
							
							my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
							
							# Calling the product collection sub-routine
							&collect_product($Colour_content,$menu_1,$menu_2,$Colour,$menu_3,$colour1);
						}
					}
				}
			}
			elsif($menu_2_block=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is) # colour block
			{
				my $colour1=$1;
				my $Colour_block=$2;
				while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
				{
					my $Colour=$utilityobject->Trim($1);
					my $Colour_url=$2;
					$Colour_url=~s/\&amp\;/&/igs;
					
					# Colour URL formating for listing all the proucts in single page
					if($Colour_url=~m/\?/is)
					{
						$Colour_url=$Colour_url.'&format=ajax&format=ajax';
					}
					else
					{
						$Colour_url=$Colour_url.'?format=ajax&format=ajax';
					}
					my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
					
					# Calling the product collection sub-routine
					&collect_product($Colour_content,$menu_1,$menu_2,$Colour,'',$colour1);
				}
			}
		}
		elsif($menu_2_content=~m/<a[^>]*?href\=\"$menu_2_url"[^>]*?>\s*[^>]*?\s*<\/a>\s*<div\s*class\=\"level\-3\">\s*<ul\s*class\=\"level\-3\">([\w\W]*?)<\/div>/is)
		{
			my $menu_3_block=$1;
			
			# Extraction of Images
			while($menu_3_block=~m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
			{				
				my $menu_3_url=$1;
				my $menu_3=$utilityobject->Trim($2);
				next if($menu_3=~m/Under\s*\$[\d\s]+/is);
				my $menu_3_content=$utilityobject->Lwp_Get($menu_3_url);
				
				# Extraction of colour heading and Block
				if($menu_3_content=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is)
				{
					my $colour1=$1;
					my $Colour_block=$2;
					
					# Extraction of Colours and its Naviagtion URL
					while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
					{
						my $Colour=$utilityobject->Trim($1);
						my $Colour_url=$2;
						$Colour_url=~s/\&amp\;/&/igs;
						
						# Colour URL formating for listing all the proucts in single page
						if($Colour_url=~m/\?/is)
						{
							$Colour_url=$Colour_url.'&format=ajax&format=ajax';
						}
						else
						{
							$Colour_url=$Colour_url.'?format=ajax&format=ajax';
						}
						
						my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
						
						# Calling the product collection sub-routine
						&collect_product($Colour_content,$menu_1,$menu_2,$Colour,$menu_3,$colour1);
					}
				}
			}
		}
		elsif($menu_2_content=~m/<span\s*class\=\"section\-heading\">\s*([^>]*?)\s*<\/span>([\w\W]*?)<\/ul>/is)
		{
			my $colour1=$1;
			my $Colour_block=$2;
			while( $Colour_block=~m/<span>\s*([^>]*?)\s*<\/span>\s*<input[^>]*?value\=\"([^>]*?)\"[^>]*?>\s*<\/input>/igs)
			{
				my $Colour=$utilityobject->Trim($1);
				my $Colour_url=$2;
				$Colour_url=~s/\&amp\;/&/igs;
				
				# Colour URL formating for listing all the proucts in single page
				if($Colour_url=~m/\?/is)
				{
					$Colour_url=$Colour_url.'&format=ajax&format=ajax';
				}
				else
				{
					$Colour_url=$Colour_url.'?format=ajax&format=ajax';
				}
				my $Colour_content=$utilityobject->Lwp_Get($Colour_url);
				
				# Calling the product collection sub-routine
				&collect_product($Colour_content,$menu_1,$menu_2,$Colour,'',$colour1);
			}
		}
	}
}

# Sending retailer completion information to dashboard
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Sending instance completion information to logger
$logger->send("$robotname :: Instance Completed  :: $pid\n");	

# Committing all the transaction.
$dbobject->commit();

# Disconnecting all DB objects
$dbobject->disconnect();
	
#Destroy all DB object
$dbobject->Destroy();

#Product collection Sub-routine

sub collect_product()
{
	my $List_Page_conetnt=shift;
	my $menu_1=shift;
	my $menu_2=shift;				
	my $Colour=shift;		
	my $menu_3=shift;	
	my $colour1=shift;	
	my $menu_Two="Shop ".$menu_1;
		
	# label Check point
	next_page1:
	
	# Collecting the Product URL
	while($List_Page_conetnt=~m/<h\d>\s*<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>\s*<\/h\d>/igs)
	{
		my $prod_url=$1;
		$prod_url=~s/\?[^>]*?$//igs;
		# To insert product URL into table on checking the product is not available already
		my $product_object_key = $dbobject->SaveProduct($prod_url,$robotname,$retailer_id,$Retailer_Random_String);
		
		# Saving the tag information.
		$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
		$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if($menu_2 ne '');
		$dbobject->SaveTag($menu_Two,$menu_2,$product_object_key,$robotname,$Retailer_Random_String) if(($menu_2 ne '')&&($menu_Two ne ''));
		if($menu_3=~m/^\s*$/is)
		{
			$dbobject->SaveTag($colour1,$Colour,$product_object_key,$robotname,$Retailer_Random_String) if($Colour ne '');
		}
		else
		{
			$dbobject->SaveTag('Menu_3',$menu_3,$product_object_key,$robotname,$Retailer_Random_String) if($menu_3 ne '');
			$dbobject->SaveTag($colour1,$Colour,$product_object_key,$robotname,$Retailer_Random_String) if($Colour ne '');
		}
		$dbobject->commit();
	}
	
	# Collecting the next page naviagtions URL
	if($List_Page_conetnt=~m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*<span[^>]*?>\s*Next\s*<\/span>\s*<\/a>/is)
	{
		my $next_url=$1;
		
		$next_url=~s/\&amp\;/&/igs;				
		# Colour URL formating for listing all the proucts in single page
		if($next_url=~m/\?/is)
		{
			$next_url=$next_url.'&format=ajax&format=ajax';
		}
		else
		{
			$next_url=$next_url.'?format=ajax&format=ajax';
		}

		$List_Page_conetnt = $utilityobject->Lwp_Get($next_url);
		# Redirecting to Next_page1 label point
		goto next_page1;
	}
}