#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;
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
my $Retailer_Random_String='Whi';
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

my $url='http://www.whistles.co.uk/';
my $content = $utilityobject->Lwp_Get($url);
my $flag=0;
#Menu-1
##while($content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"level\-1\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)
while($content=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"level\-1[^>]*?>[\w\W]*?\s*([^>]*?)\s*<\/span>\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)
{
	my $menu_1_URL=$1;
	my $menu_1=$utilityobject->Trim($2);
	my $menu1_block=$3;	
	print "MENU1:: $menu_1\n";
	#Menu-2
	# while($menu1_block=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"level\-2\"[^>]*?>\s*([^>]*?)\s*</igs)
	# {
		# my $menu2_url=$1;
		# my $menu_2=$utilityobject->Trim($2);
		
	my $menu2_content=$utilityobject->Lwp_Get($menu_1_URL);
		##print "Inside the While Loop 2 of Whistles:: $menu_2\n";
		
		##while($menu2_content=~m/<span\s*class\=\"menu\-item\">([^>]*?)<\/span>([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)
	# if($menu2_content=~m/<span\s*class\=\"menu\-item[^>]*?\">([^>]*?)<\/span>\s*<\/a>\s*<div\s*class([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)
	# {	
		my $countf=0;
		while($menu2_content=~m/<span\s*class\=\"menu\-item[^>]*?\">([^>]*?)<\/span>\s*<\/a>\s*<div\s*class([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)
		{
			my $menu11=$1;
			my $menu11_block=$2;
			
			print "MENU2:: $menu11\n";
			
			while($menu11_block=~m/<a\s*href\=\"([^>]*?)\"\s*class\=\"level\-2\"[^>]*?>\s*([^>]*?)\s*</igs)
			{
				my $menu22_url=$1;
				my $menu_22=$utilityobject->Trim($2);		
												
				SS15_Show:
				if($flag==1)
				{
					$menu22_url='http://www.whistles.com/search?cgid=LFW_WW';
					$menu11='SS15 SHOW';
					$menu_22='';
				}
								
				my $menu22_content=$utilityobject->Lwp_Get($menu22_url);
		
				#Menu-3
				if($menu22_content=~m/<h3\s*class\=\"toggle\">\s*<span>\s*(Refine\s*by\s*Type|Type|Refine\s*by\s*Colour|Colour|by\s*product\s*type|by\s*colour|\s*Refine\s*by\s*category)\s*<\/span>([\w\W]*?)<\/div>/is)
				{
					while($menu22_content=~m/<h3\s*class\=\"toggle\">\s*<span>\s*(Refine\s*by\s*Type|Type|Refine\s*by\s*Colour|Colour|by\s*product\s*type|by\s*colour|\s*Refine\s*by\s*category)\s*<\/span>([\w\W]*?)<\/div>/igs)
					{
						my $menu_3=$utilityobject->Trim($1);		
						my $menu3_block=$2;
						$menu_3=~s/\b([a-z]{1})/uc $1/ige;		
						
						#Menu-4
						while($menu3_block=~m/<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>([^>]*?)<\/span>\s*<\/a>/igs)
						{
							my $menu4_url=$1;
							my $menu_4=$utilityobject->Trim($2);				
							$menu_4=~s/\b([a-z]{1})/uc $1/ige;
							$menu4_url=~s/\&amp\;/&/igs;
						
							# Url framed to get all the products listed in a single page
							if($menu4_url=~m/\?/is)
							{
								$menu4_url=$menu4_url.'&start=0&format=page-element&sz=60' ; # Url framed to get all the products listed in a single page
							}
							else
							{
								$menu4_url=$menu4_url.'?start=0&format=page-element&sz=60' ; # Url framed to get all the products listed in a single page
							}
							my $menu4_content=$utilityobject->Lwp_Get($menu4_url);
							
							###while($menu4_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
							while($menu4_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
							{
								my $product_url=$1;
								$product_url=~s/\?[^>]*?$//igs;						
								my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
							
								$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
								$dbobject->SaveTag('Menu_2',$menu11,$product_object_key,$robotname,$Retailer_Random_String) if($menu11 ne '');
								#$dbobject->SaveTag('Menu_3',$menu11,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String) if($menu_22 ne '');
								$dbobject->SaveTag($menu_3,$menu_4,$product_object_key,$robotname,$Retailer_Random_String) if($menu_4 ne '');	
								
								# Commiting the Transation
								$dbobject->commit();
							
							}
						}					
					}
				}
				else
				{
					# Url framed to get all the products listed in a single page
					if($menu22_url=~m/\?/is)
					{
						$menu22_url=$menu22_url.'&start=0&format=page-element&sz=60' ;
					}
					else
					{
						$menu22_url=$menu22_url.'?start=0&format=page-element&sz=60' ;
					}
					
					$menu22_url=~s/\&amp\;/&/igs;
					my $menu221_content=$utilityobject->Lwp_Get($menu22_url);
					
					while($menu221_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
					{
						my $product_url=$1;
						$product_url=~s/\?[^>]*?$//igs;
						
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
						
						$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
						#$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_2',$menu11,$product_object_key,$robotname,$Retailer_Random_String) if($menu11 ne '');
						$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String) if($menu_22 ne '');						
						###$dbobject->SaveTag($menu_3,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);	
						
						$dbobject->commit();			
					}				
				}
				
			}				
		}
		
	if(($menu_1=~m/\bmen\b/is)&&($flag==0))
	{
		print "In men Accessories\n";
		##<STDIN>;
		my $menu22_url='http://www.whistles.com/men/accessories/';
		my $menu11='Accessories';
		my $menu_22='';

		my $menu22_content=$utilityobject->Lwp_Get($menu22_url);
	
		#Menu-3
		if($menu22_content=~m/<h3\s*class\=\"toggle\">\s*<span>\s*(Refine\s*by\s*Type|Type|Refine\s*by\s*Colour|Colour|by\s*product\s*type|by\s*colour|\s*Refine\s*by\s*category)\s*<\/span>([\w\W]*?)<\/div>/is)
		{
			while($menu22_content=~m/<h3\s*class\=\"toggle\">\s*<span>\s*(Refine\s*by\s*Type|Type|Refine\s*by\s*Colour|Colour|by\s*product\s*type|by\s*colour|\s*Refine\s*by\s*category)\s*<\/span>([\w\W]*?)<\/div>/igs)
			{
				my $menu_3=$utilityobject->Trim($1);		
				my $menu3_block=$2;
				$menu_3=~s/\b([a-z]{1})/uc $1/ige;		
				
				#Menu-4
				while($menu3_block=~m/<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>([^>]*?)<\/span>\s*<\/a>/igs)
				{
					my $menu4_url=$1;
					my $menu_4=$utilityobject->Trim($2);				
					$menu_4=~s/\b([a-z]{1})/uc $1/ige;
					$menu4_url=~s/\&amp\;/&/igs;
				
					# Url framed to get all the products listed in a single page
					if($menu4_url=~m/\?/is)
					{
						$menu4_url=$menu4_url.'&start=0&format=page-element&sz=60' ; # Url framed to get all the products listed in a single page
					}
					else
					{
						$menu4_url=$menu4_url.'?start=0&format=page-element&sz=60' ; # Url framed to get all the products listed in a single page
					}
					my $menu4_content=$utilityobject->Lwp_Get($menu4_url);
					
					###while($menu4_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
					while($menu4_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
					{
						my $product_url=$1;
						$product_url=~s/\?[^>]*?$//igs;						
						my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					
						$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
						$dbobject->SaveTag('Menu_2',$menu11,$product_object_key,$robotname,$Retailer_Random_String) if($menu11 ne '');
						#$dbobject->SaveTag('Menu_3',$menu11,$product_object_key,$robotname,$Retailer_Random_String);
						$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String) if($menu_22 ne '');
						$dbobject->SaveTag($menu_3,$menu_4,$product_object_key,$robotname,$Retailer_Random_String) if($menu_4 ne '');	
						
						# Commiting the Transation
						$dbobject->commit();
					
					}
				}					
			}
		}
		else
		{
			# Url framed to get all the products listed in a single page
			if($menu22_url=~m/\?/is)
			{
				$menu22_url=$menu22_url.'&start=0&format=page-element&sz=60' ;
			}
			else
			{
				$menu22_url=$menu22_url.'?start=0&format=page-element&sz=60' ;
			}
			
			$menu22_url=~s/\&amp\;/&/igs;
			my $menu221_content=$utilityobject->Lwp_Get($menu22_url);
			
			while($menu221_content=~m/<a\s*class\=\"name\-link\"\s*href\=\"([^>]*?)\"\s*title\=\"/igs)
			{
				my $product_url=$1;
				$product_url=~s/\?[^>]*?$//igs;
				
				my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				
				$dbobject->SaveTag('Menu_1',$menu_1,$product_object_key,$robotname,$Retailer_Random_String) if($menu_1 ne '');
				#$dbobject->SaveTag('Menu_2',$menu_2,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_2',$menu11,$product_object_key,$robotname,$Retailer_Random_String) if($menu11 ne '');
				$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String) if($menu_22 ne '');						
				###$dbobject->SaveTag($menu_3,$menu_4,$product_object_key,$robotname,$Retailer_Random_String);	
				
				$dbobject->commit();			
			}				
		}
	}			
}
if($flag==0)
{
	$flag=1;
	print "SS15 SHOW\n";
	##<STDIN>;
	goto SS15_Show;
}

# Sending retailer completion information to dashboard
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Sending instance completion information to logger
$logger->send("$robotname :: Instance Completed  :: $pid\n");	

# Committing all the transaction.
$dbobject->commit();

# Disconnecting all DB objects
$dbobject->disconnect();

# Destroy all DB objects
$dbobject->Destroy();
