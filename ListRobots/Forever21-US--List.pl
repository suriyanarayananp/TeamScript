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
my $Retailer_Random_String='For';
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
# Getting Content of the home page
my $url="http://www.forever21.com/Product/Main.aspx?br=f21";

my $Menu1=$ARGV[0];
my $Menu2=$ARGV[1];
my $Menu3=$ARGV[2];
my $Menu_URL=$ARGV[3];

my $current_last_menu=$Menu3;
if(($Menu_URL=~m/^\s*$/is)&&($Menu3 ne ''))
{
	$Menu_URL=$Menu3;
	$Menu3='';
	$current_last_menu=$Menu2;	
}
elsif(($Menu_URL=~m/^\s*$/is)&&($Menu2 ne ''))
{
	$Menu_URL=$Menu2;
	$Menu2='';
	$Menu3='';
	$current_last_menu=$Menu1;	
}

# Declaring all required variables.
my ($temp,$temp1,$temp2,$temp3,%hash_id);

# Pattern match to take topmenu and it's url.
if ( $Menu1 )
{
	my $urlcontent =$Menu_URL;
	my $menu_1=$Menu1;
	
	my $content1 = $utilityobject->Lwp_Get($urlcontent);
	
	if($content1=~m/<font\s*class\=\"SubCateg\"\s*style\=\"text\-decoration\:underline\;\s*[^>]*?\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/is)
	{		
		
		&GetProduct('',$content1,$menu_1,$Menu2,$Menu3,'','','','','','','');
		
		while($content1=~m/<dt\s*style\=\"text\-align\:left\;\s*padding-top\:2px\;\s*padding\-bottom\:2px\;padding\-left\:10px\;\">\s*<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?><font\s*class\=\"SubCateg\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/igs)
		{
			my $url_4=$1;
			my $menu_4=$2;
			
			# Function call to collect products under the corresponding menus & the category url.
			&GetProduct($url_4,'',$menu_1,$Menu2,$Menu3,'Menu_4',$menu_4,'','','','','');
			$current_last_menu=$menu_4;
			my $content4 = $utilityobject->Lwp_Get($url_4);
			if($content4=~m/<font\s*class\=\"SubCateg\"\s*style\=\"text\-decoration\:underline\;\s*[^>]*?\">\s*$current_last_menu\s*<\/font>\s*<\/a>\s*<\/dt>/is)
			{
				while($content4=~m/<dt\s*style\=\"text\-align\:left\;\s*padding-top\:2px\;\s*padding\-bottom\:2px\;padding\-left\:20px\;\">\s*<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?><font\s*class\=\"SubCateg\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/igs)
				{
					my $url_5=$1;
					my $menu_5=$2;
					
					# Function call to collect products under the corresponding menus & the category url.
					&GetProduct($url_5,'',$menu_1,$Menu2,$Menu3,'Menu_4',$menu_4,'',$menu_5,'','','');							
				}
			}
		}
	}
	else
	{	
		# Looping through to take header,url and menu to collect products from other topmenus.
		while($content1=~m/(?:class\=\"SubCategBold\">([^>]*?)<\/font><\/dt>)?\s*<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg([^>]*?)\">\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)		
		{
			my $menu_2_cat=$1;  # LHM Main Heading 2=>Features (All menu1 have).
			my $url_2=$2;       # Menu2 url.
			my $subcatflag=$3;  # Flag to avoid looping issue.
			my $menu_2=$4;      # Menu2.
								
			# Function call to collect products under the corresponding menus & the category url.
			&GetProduct($url_2,'',$menu_1,$Menu2,$Menu3,$menu_2_cat,$menu_2,'','','','','');
			
			my $content2 = $utilityobject->Lwp_Get($url_2);
						
			if(($content2=~m/<font\s*class\=\"SubCateg\"\s*style\=\"text\-decoration\:underline\;\s*[^>]*?\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/is) && ($Menu3!~m/Style\s*Deals/is))
			{		
				my $head_menu5=$1;
				
				&GetProduct('',$content2,$menu_1,$Menu2,$Menu3,'','','','','','','');
				
				while($content2=~m/<dt\s*style\=\"text\-align\:left\;\s*padding-top\:2px\;\s*padding\-bottom\:2px\;padding\-left\:10px\;\">\s*<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?><font\s*class\=\"SubCateg\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/igs)
				{
					my $url_5=$1;
					my $menu_5=$2;
					
					# Function call to collect products under the corresponding menus & the category url.
					&GetProduct($url_5,'',$menu_1,$Menu2,$Menu3,$head_menu5,$menu_5,'','','','','');
					$current_last_menu=$menu_5;
					my $content5 = $utilityobject->Lwp_Get($url_5);
					if($content5=~m/<font\s*class\=\"SubCateg\"\s*style\=\"text\-decoration\:underline\;\s*[^>]*?\">\s*$current_last_menu\s*<\/font>\s*<\/a>\s*<\/dt>/is)
					{
						my $head_menu6=$1;
						while($content5=~m/<dt\s*style\=\"text\-align\:left\;\s*padding-top\:2px\;\s*padding\-bottom\:2px\;padding\-left\:20px\;\">\s*<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?><font\s*class\=\"SubCateg\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/igs)
						{
							my $url_6=$1;
							my $menu_6=$2;
							
							# Function call to collect products under the corresponding menus & the category url.
							&GetProduct($url_6,'',$menu_1,$Menu2,$Menu3,$head_menu5,$menu_5,$head_menu6,$menu_6,'','','');	
							
							$current_last_menu=$menu_6;
							my $content6 = $utilityobject->Lwp_Get($url_6);
							if($content6=~m/<font\s*class\=\"SubCateg\"\s*style\=\"text\-decoration\:underline\;\s*[^>]*?\">\s*$current_last_menu\s*<\/font>\s*<\/a>\s*<\/dt>/is)
							{
								my $head_menu7=$1;
								while($content6=~m/<dt\s*style\=\"text\-align\:left\;\s*padding-top\:2px\;\s*padding\-bottom\:2px\;padding\-left\:30px\;\">\s*<a\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?><font\s*class\=\"SubCateg\">\s*([^>]*?)\s*<\/font>\s*<\/a>\s*<\/dt>/igs)
								{
									my $url_7=$1;
									my $menu_7=$2;
									
									# Function call to collect products under the corresponding menus & the category url.
									&GetProduct($url_7,'',$menu_1,$Menu2,$Menu3,$head_menu5,$menu_5,$head_menu6,$menu_6,$menu_7,'','');							
								}
							}
						}
					}
				}
			}
		}
	}	
}	
		
sub GetProduct() # Function definition to collect Products.
{
	my $main_url=shift;  
	my $subblock=shift;
	my $menu_11=shift;
	my $menu_12=shift;
	my $menu_13=shift;
	my $menu_2_cat2=shift;
	my $menu_22=shift;
	my $menu_3_cat3=shift;
	my $menu_33=shift;
	my $menu_44=shift;
	my $menu_55=shift;
	my $menu_66=shift;
	
	# Scenario1: Check whether block taken.(Eg.In SALE topmenu).
	if($subblock ne '')
	{
		# Pattern match to collect products.
		while($subblock=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/igs)
		{
			my $product_url=$1;
			my ($product_id,$product_object_key);
			
			# Pattern match to take product ID from url to remove duplicates.
			if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
			{
				$product_id=$1;
			}
			$product_url=~s/\&VariantID=[\w\W]*//is; # Pattern substitution to limit the url's size.
			
			# Insert Product values.
			if($hash_id{$product_id} eq  '')
			{
				$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				$hash_id{$product_id}=$product_object_key;
			}
			else
			{
				$product_object_key=$hash_id{$product_id};
			}
			
			# Save the Tag information based on the Product ID and its tag values.
			$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
			$dbobject->SaveTag('Menu_2',$menu_12,$product_object_key,$robotname,$Retailer_Random_String) if($menu_12!~m/^\s*$/is);
			$dbobject->SaveTag('Menu_3',$menu_13,$product_object_key,$robotname,$Retailer_Random_String) if($menu_13!~m/^\s*$/is);
			
			if(($menu_2_cat2 ne '') && ($menu_22 ne ''))
			{
				$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			elsif(($menu_12=~m/^\s*$/is) && ($menu_22 ne ''))
			{
				$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			elsif(($menu_13=~m/^\s*$/is) && ($menu_22 ne ''))
			{
				$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			elsif($menu_22 ne '')
			{
				$dbobject->SaveTag('Menu_4',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
			}
			
			unless($menu_33 eq '')
			{
				if($menu_3_cat3)
				{
					$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
				}
				else
				{
					$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
				}
			}
			unless($menu_44 eq '')
			{
				$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_55 eq '')
			{
				$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($menu_66 eq '')
			{
				$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
			}
			$dbobject->commit();
		}
	}
	else # If subblock not available.
	{
		my $main_url1;
		if($main_url=~m/\?/is)
		{
			$main_url1="$main_url"."&pagesize=100"; # Appending url to collect more product urls.
		}
		else
		{
			$main_url1="$main_url"."?pagesize=100";
		}
		
		my $main_url_content;
		
		my $staus=$utilityobject->GetCode($main_url1);  # Getting status to check whether appended url is having information.
		
		# Pattern match to check whether appended url is having code "200".(Is page have complete information).
		if($staus=~m/200/is)
		{
			$main_url_content=$utilityobject->Lwp_Get($main_url1);
		}
		else # If page doesn't have complete information get the page information of the actual url.
		{
			$main_url_content=$utilityobject->Lwp_Get($main_url);
		}

	next_page:

		# Pattern match to check whether product urls can be collected in this scenario.	
		if($main_url_content=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/is)
		{
			# Pattern match to collect product urls.
			while($main_url_content=~m/<div[^>]*?class\=(?:\'|\")ItemImage[^>]*?(?:\'|\")[^>]*?>\s*<a[^>]*?href\=(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/igs)
			{
				my $product_url=$1;
				my ($product_id,$product_object_key);
				
				# Pattern match to take product ID from url to remove duplicates.
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is; # Pattern substitution to limit the url's size.
				
				# Insert Product values.
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
				# Save the Tag information based on the Product ID and its tag values.
				$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_2',$menu_12,$product_object_key,$robotname,$Retailer_Random_String) if($menu_12!~m/^\s*$/is);
				$dbobject->SaveTag('Menu_3',$menu_13,$product_object_key,$robotname,$Retailer_Random_String) if($menu_13!~m/^\s*$/is);
				
				if(($menu_2_cat2 ne '') && ($menu_22 ne ''))
				{
					$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				elsif(($menu_12=~m/^\s*$/is) && ($menu_22 ne ''))
				{
					$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				elsif(($menu_13=~m/^\s*$/is) && ( $menu_22 ne ''))
				{
					$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				elsif($menu_22 ne '')
				{
					$dbobject->SaveTag('Menu_4',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
					else
					{
						$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
				}
				unless($menu_44 eq '')
				{
					$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_55 eq '')
				{
					$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_66 eq '')
				{
					$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
				}
				$dbobject->commit();
			}
		}
		elsif($main_url_content=~m/<iframe\s*src\=\s*(?:\"|\')([^<]*?)(?:\"|\')[^<]*?>/is) # Pattern match to check whether product urls can be collected in this scenario, If Product Page having Images (Eg: "http://www.forever21.com/looks/F21_main.aspx?br=21men")
		{
			# "Inside Frame"
			my $main_url_content_url1=$1;
			
			my $main_url_content_url1="http://www.forever21.com".$main_url_content_url1 unless($main_url_content_url1=~m/^http/is);
			
			my $main_url1_content=$utilityobject->Lwp_Get($main_url_content_url1);
			
			while($main_url1_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')\s*javascript[^\(]*?\((?:\'|\")([^>]*?)(?:\'|\")[^>]*?\)\s*[^>]*?>/igs)
			{
				my $product_url=$1;
				$product_url=~s/amp;//igs;					
				
				my $product_url="http://www.forever21.com".$product_url unless($product_url=~m/^http/is);
				
				my ($product_id,$product_object_key);
				
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is;
				
				# Insert Product values.
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
				# Save the Tag information based on the Product ID and its tag values.
				$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				$dbobject->SaveTag('Menu_2',$menu_12,$product_object_key,$robotname,$Retailer_Random_String) if($menu_12!~m/^\s*$/is);
				$dbobject->SaveTag('Menu_3',$menu_13,$product_object_key,$robotname,$Retailer_Random_String) if($menu_13!~m/^\s*$/is);
				
				if(($menu_2_cat2 ne '') && ($menu_22 ne ''))
				{
					$dbobject->SaveTag($menu_2_cat2,$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				elsif(($menu_12=~m/^\s*$/is) && ($menu_22 ne ''))
				{
					$dbobject->SaveTag('Menu_2',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				elsif(($menu_13=~m/^\s*$/is) && ($menu_22 ne ''))
				{
					$dbobject->SaveTag('Menu_3',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				else
				{
					$dbobject->SaveTag('Menu_4',$menu_22,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						$dbobject->SaveTag($menu_3_cat3,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
					else
					{
						$dbobject->SaveTag($menu_22,$menu_33,$product_object_key,$robotname,$Retailer_Random_String);
					}
				}
				unless($menu_44 eq '')
				{
					$dbobject->SaveTag($menu_33,$menu_44,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_55 eq '')
				{
					$dbobject->SaveTag($menu_44,$menu_55,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($menu_66 eq '')
				{
					$dbobject->SaveTag($menu_55,$menu_66,$product_object_key,$robotname,$Retailer_Random_String);
				}
				$dbobject->commit();
			}
		}
		# Pattern match to take next page url.
		if($main_url_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*NextPage[^>]*?(?:\"|\')[^>]*?>/is)
		{
			$main_url=$1;
			
			$main_url='http://www.forever21.com/Product/Category.aspx'.$main_url unless($main_url=~m/^\s*http\:/is);
			
			$main_url_content = $utilityobject->Lwp_Get($main_url);
			goto next_page;
		}
	}
}

# To indicate script has completed in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Once script has complete send a msg to logger.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Committing the transaction.
$dbobject->commit();