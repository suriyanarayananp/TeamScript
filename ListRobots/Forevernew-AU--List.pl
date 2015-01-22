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
my $Retailer_Random_String='Fon';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %hash_id;
###########################################

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

# URL Collection.
my $content = $utilityobject->Lwp_Get("http://www.forevernew.com.au/"); 

# Pattern Match to get the Topmenu Block.
while($content=~m/<a[^>]*?class\s*\=\s*\"\s*drop\"[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>\s*([^>]*?)\s*</igs)
{
	my $menu_1_url=$1; 
	my $menu_1=$utilityobject->Trim($2);
	
	next if($menu_1!~/$ARGV[0]/is);

	&collect_Product($menu_1_url,$menu_1,'','','','');
	
	my $content = $utilityobject->Lwp_Get($menu_1_url); 
	
	# Pattern Match to get the Topmenu URL and Menus.(Menu1=>Women,Men).
	while($content=~m/filter-name\s*\"[^>]*?>\s*((?!shop\s*by\s*(?:size|price))[^<]*)<([\w\W]*?)<\/dd>/igs) #SHOP\s*BY\s*CATEGORY 
	{
		my $filter_1_header=$1;
		my $filter_1_block=$2;  #(SHOP BY CATEGORY-DRESSES)

		next if($filter_1_header=~m/Size|price/is);
		
		# Only for the Category Header holding filters
		if($filter_1_header=~m/CATEGORY/is)
		{
			while($filter_1_block=~m/<a[^>]*?(?:data-param\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?)?href\s*\=\s*\"([^>]*?)"[^>]*?>\s*(?:<[^>]*?>\s*)*([^>]*?)</igs)
			{
				my $filter_1_url_ext=$1;
				my $filter_1_url=$2;
				my $filter_1_value=$utilityobject->Trim($3);

				$filter_1_url=$filter_1_url."$filter_1_url_ext" if($filter_1_url_ext ne "");
				
				# Adding home URL If the URL doesn't Start with "http".
				$filter_1_url='http://www.forevernew.com.au/'.$filter_1_url unless($filter_1_url=~m/^\s*http\:/is);
				
				&collect_Product($filter_1_url,$menu_1,$filter_1_header,$filter_1_value,'','','','');
				
				my $filter_1_content = $utilityobject->Lwp_Get($filter_1_url);			
				
				# Filter matching excluding Size and Price Filters
				while($filter_1_content=~m/filter-name\s*\"[^>]*?>\s*((?!shop\s*by\s*(?:size|price))[^<]*)<([\w\W]*?)<\/dd>/igs)
				{
					my $filter_2_header=$1;
					my $filter_2_block=$2; #(Dresses=>SHOP BY CATEGORY-DAY DRESSES)
					
					next if($filter_2_header=~m/Size|price/is);
					
					if($filter_2_header=~m/CATEGORY/is)
					{
						$filter_2_header="$filter_1_value" if($filter_2_header=~m/SHOP\s*BY\s*CATEGORY/is);
						
						while($filter_2_block=~m/<a[^>]*?(?:data-param\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?)?href\s*\=\s*\"([^>]*?)"[^>]*?>\s*(?:<[^>]*?>\s*)*([^>]*?)</igs)
						{	
							my $filter_2_url_ext=$1;
							my $filter_2_url=$2;
							my $filter_2_value=$utilityobject->Trim($3);
							
							next if($filter_2_value=~m/\b\s*Back\s*to/is);
							
							$filter_2_url=$filter_2_url."$filter_2_url_ext" if($filter_2_url_ext ne "");
						
							# Adding home URL If the URL doesn't Start with "http".
							$filter_2_url='http://www.forevernew.com.au/'.$filter_2_url unless($filter_2_url=~m/^\s*http\:/is);
														
							&collect_Product($filter_2_url,$menu_1,$filter_1_header,$filter_1_value,$filter_2_header,$filter_2_value,'','');
							
							my $filter_2_content = $utilityobject->Lwp_Get($filter_2_url);			
							
							# Filter matching excluding Size and Price Filters
							if($filter_2_content=~m/filter-name\s*\"[^>]*?>\s*((?!shop\s*by\s*(?:size|price))[^<]*)<([\w\W]*?)<\/dd>/is)
							{
								while($filter_2_content=~m/filter-name\s*\"[^>]*?>\s*((?!shop\s*by\s*(?:size|price))[^<]*)<([\w\W]*?)<\/dd>/igs)
								{
									my $filter_3_header=$1;
									my $filter_3_block=$2; 
									
									next if($filter_3_header=~m/Size|price/is);
									
									$filter_3_header="$filter_2_value" if($filter_3_header=~m/SHOP\s*BY\s*CATEGORY/is);
									
									while($filter_3_block=~m/<a[^>]*?(?:data-param\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?)?href\s*\=\s*\"([^>]*?)"[^>]*?>\s*(?:<[^>]*?>\s*)*([^>]*?)</igs)
									{	
										my $filter_3_url_ext=$1;
										my $filter_3_url=$2;
										my $filter_3_value=$utilityobject->Trim($3);
										
										next if($filter_3_value=~m/\b\s*Back\s*to/is);
										
										$filter_3_url=$filter_3_url."$filter_3_url_ext" if($filter_3_url_ext ne "");
									
										# Adding home URL If the URL doesn't Start with "http".
										$filter_3_url='http://www.forevernew.com.au/'.$filter_3_url unless($filter_3_url=~m/^\s*http\:/is);

										&collect_Product($filter_3_url,$menu_1,$filter_1_header,$filter_1_value,$filter_2_header,$filter_2_value,$filter_3_header,$filter_3_value);
									}
								}
							}
						}
					}
					else
					{
						while($filter_2_block=~m/<a[^>]*?(?:data-param\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?)?href\s*\=\s*\"([^>]*?)"[^>]*?>\s*(?:<[^>]*?>\s*)*([^>]*?)</igs)
						{	
							my $filter_2_url_ext=$1;
							my $filter_2_url=$2;
							my $filter_2_value=$utilityobject->Trim($3);

							next if($filter_2_value=~m/\b\s*Back\s*to/is);
							
							$filter_2_url=$filter_2_url."$filter_2_url_ext" if($filter_2_url_ext ne "");
						
							# Adding home URL If the URL doesn't Start with "http".
							$filter_2_url='http://www.forevernew.com.au/'.$filter_2_url unless($filter_2_url=~m/^\s*http\:/is);

							&collect_Product($filter_2_url,$menu_1,$filter_1_header,$filter_1_value,$filter_2_header,$filter_2_value,'','');
						}								
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

sub collect_Product() #Function Definition to get Products url
{	
	my $Content_url=shift;
	my $menu_11=shift;
	my $filter_11_header=shift;
	my $filter_11_value=shift;
	my $filter_22_header=shift;
	my $filter_22_value=shift;
	my $filter_33_header=shift;
	my $filter_33_value=shift;
	
	# Getting the Content of the Category URL.
	my $prouduct_list_content = $utilityobject->Lwp_Get($Content_url);			
	my $total_items;
	my $count=1;
	
	if($prouduct_list_content=~m/total-items\"[^>]*?>\s*([\d]+)\s*[^<]*?</is)
	{
		$total_items=$1;
		$total_items=$total_items/9;
		$total_items=$total_items+1;
	}
		
	if($count>$total_items) # $total_items eq 0
	{
		while($prouduct_list_content=~ m/<a[^>]*?href\s*\=\s*\"([^>]*?)(?:\?[^>]*?)?\"[^>]*?class\s*\=\s*\"\s*product\-image[^>]*?>/igs)
		{
			my $product_url=$1;
			
			# Adding home URL If the URL doesn't Start with "http".
			$product_url='http://www.forevernew.com.au'.$product_url unless($product_url=~m/^\s*http\:/is);
			
			my $product_id=$1 if($product_url=~m/(\d+)/is);
			
			# Calling SaveProduct to make entry to the product table.
			my $product_object_key;
			if($hash_id{$product_id} eq '')
			{
				$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				$hash_id{$product_id}=$product_object_key;
			}
			else # If Product id already exist in hash assigning product's tag information to existed product url.
			{
				$product_object_key=$hash_id{$product_id};
			}
			
			# Insert Product values.
			my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			# Insert Tag values.
			$dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
			
			unless($filter_11_header=~m/^\s*$/is)
			{
			 $dbobject->SaveTag($filter_11_header,$filter_11_value,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($filter_22_header=~m/^\s*$/is)
			{
			 $dbobject->SaveTag($filter_22_header,$filter_22_value,$product_object_key,$robotname,$Retailer_Random_String);
			}
			unless($filter_33_header=~m/^\s*$/is)
			{
			 $dbobject->SaveTag($filter_33_header,$filter_33_value,$product_object_key,$robotname,$Retailer_Random_String);
			}
			
			$dbobject->commit();
		}
	}
	else
	{
		if($Content_url=~m/\?/is)
		{
			$Content_url="$Content_url"."&p=";
		}
		else
		{
			$Content_url="$Content_url"."?p=";
		}
		
		while($count<=$total_items)
		{
			my $product_pageno_content = $utilityobject->Lwp_Get("$Content_url"."$count");
			
			# Pattern Match to collect Product URLs.
			while($product_pageno_content=~m/<a[^>]*?href\s*\=\s*\"([^>]*?)(?:\?[^>]*?)?\"[^>]*?class\s*\=\s*\"\s*product\-image[^>]*?>/igs)
			{
				my $product_url=$1;
				# Adding home URL If the URL doesn't Start with "http".
				$product_url='http://www.forevernew.com.au'.$product_url unless($product_url=~m/^\s*http\:/is);

				my $product_id=$1 if($product_url=~m/(\d+)/is);
			
				# Calling SaveProduct to make entry to the product table.
				my $product_object_key;
				if($hash_id{$product_id} eq '')
				{
					$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
					$hash_id{$product_id}=$product_object_key;
				}
				else # If Product id already exist in hash assigning product's tag information to existed product url.
				{
					$product_object_key=$hash_id{$product_id};
				}
			
				# Insert Product values.
				 my $product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
				# Insert Tag values.
				 $dbobject->SaveTag('Menu_1',$menu_11,$product_object_key,$robotname,$Retailer_Random_String);
				
				unless($filter_11_header=~m/^\s*$/is)
				{
					$dbobject->SaveTag($filter_11_header,$filter_11_value,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($filter_22_header=~m/^\s*$/is)
				{
				 $dbobject->SaveTag($filter_22_header,$filter_22_value,$product_object_key,$robotname,$Retailer_Random_String);
				}
				unless($filter_33_header=~m/^\s*$/is)
				{
				 $dbobject->SaveTag($filter_33_header,$filter_33_value,$product_object_key,$robotname,$Retailer_Random_String);
				}
				
				$dbobject->commit();
			}
			$count++;
		}
	}
}
