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
my $Retailer_Random_String='Zes';
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


my ($menu_1,$menu_2,$menu_3,$menu_4, $col_url);
my %hash_id;

$menu_1=$ARGV[0];
$menu_2=$ARGV[1];

if($ARGV[2]=~m/http\:\/\//is)
{	
	$col_url=$ARGV[2];
	$menu_3='';
	$menu_4='';
}
elsif($ARGV[3]=~m/http\:\/\//is)
{
	$col_url=$ARGV[3];
	$menu_3=$ARGV[2];
	$menu_4='';
}
elsif($ARGV[4]=~m/http\:\/\//is)
{	
	$col_url=$ARGV[4];
	$menu_3=$ARGV[2];
	$menu_4=$ARGV[3];	
}

# Product Collection
&Product_Collection($col_url,$menu_1,$menu_2,$menu_3,$menu_4);


# Function definition to collect products.
sub Product_Collection
{
	my $category_url=shift;
	my $menu1=shift;
	my $menu2=shift;
	my $menu3=shift;
	my $menu4=shift;
	
	my $cat_id;
	 if($category_url=~m/\-?\s*c\s*(\d+)\s*\.\s*html/is)
	{
		$cat_id=$1;
	}
	
	my $Product_list_content = $utilityobject->Lwp_Get($category_url);
	
	my $char_url='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=STATIC&ajaxCall=true';
	# Formation of characteristic url for the produts under respective category(In filter).
	
	my $color_url='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=DYNAMIC&ajaxCall=true';
	# Formation of color url for the produts under respective category(In filter). 

	my $char_Cont = $utilityobject->Lwp_Get($char_url);
	my $color_Cont = $utilityobject->Lwp_Get($color_url);
			
	# Declaring required variables.
	my ($prod_id,$product_url,$product_object_key);
	
	# Looping through to get product urls.
	while($Product_list_content=~ m/<a\s*href='([^<]*?)'\s*[^<]*\s*class='item\s*gaProductDetailsLink'/igs) 
	{
		$product_url = $1;
		
		# Pattern match to get the product id to remove duplicate product urls.
		$prod_id=$1 if($product_url=~m/p\s*(\d+)\s*\.\s*html/is);
		
		# Insert Product values.
		if($hash_id{$prod_id} eq  '')
		{
			# Insert product url if url not exist.
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$hash_id{$prod_id}=$product_object_key;
		}
		else
		{
			# Assigning objectkey of already existed product's Objectkey and skip the url if exist and save the new product's tag information along with already existed product url's tag information.
			$product_object_key=$hash_id{$prod_id};
		}
		
		# Save the tag information of "Menu 1" if non-empty.
		$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');  
		
		# Save the tag information of "Menu 2" if non-empty. 
		$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
		
		# Save the tag information of "Menu 3" if non-empty. 
		$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
		
		# Save the tag information of "Menu 4" if non-empty. 
		$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
		
		# Committing the transaction.
		$dbobject->commit();
		
		# Taking characteristics and color tag. 
		&charactertag($char_Cont,$prod_id,$product_object_key);# Function call to get characteristics tag information for the corresponding product.
		&charactertag($color_Cont,$prod_id,$product_object_key);# Function call to get colour tag information for the corresponding product. 
	}
}

sub charactertag() # Function definition to get characteristics and colour tag information for the product urls.
{
	my $Jcont1=shift;
	my $prod_id1=shift;
	my $product_object_key1=shift;
	while($Jcont1=~m/{\s*\"\s*values\s*\"([\w\W]*?)\"\s*type\s*\"\s*\:\s*\"\s*([^>]*?)\s*\"\s*}/igs)  # Characteristics,Colour and quality block (In Filter in RHS).
	{
		my $Type1_blk=$1;
		my $Type1=$2;
		
		next if($Type1=~m/(?:size|Price)/is); # Skip if size ,price tag information in content.
		
		# Looping through to get the each block.
		while($Type1_blk=~m/{\s*\"[\w\W]*?\"\s*\}/igs)
		{
			my $Type_blk11=$&;
			my $name1;
			
			$name1=$1 if($Type_blk11=~m/\s*\"\s*name\s*\"\s*\:\s*\"([^\'\"]*?)\s*\"/is); # Getting tag name Eg. Characteristics or color.
			# Pattern match to get the sku id's(Product id's) block from the main block.
			if($Type_blk11=~m/\"\s*skus\s*\"\s*\:([\w\W]*?\"\])/is)   
			{
				my $Skus_id_blk1=$1;
				
				# Looping through to get each sku id's from the skuid's block.
				while($Skus_id_blk1=~m/(?:\"|\')\s*([^\'\"]*?)\s*(?:\"|\')/igs)
				{
					my $Skuid1=$1;
					# Pattern match to get the tag information if product id in product url and sku id from the block is same.
					if(($Skuid1 eq $prod_id1)||($Skuid1=~m/$prod_id1/))
					{
						$Type1=~s/features/characteristics/igs;
						$Type1=~s/quality/qualities/igs;
						# Save the tag information into tag table.
						$dbobject->SaveTag($Type1,$name1,$product_object_key1,$robotname,$Retailer_Random_String);
						# Committing the transaction.
						$dbobject->commit();
					}
				}
			}
		}
	}
}

#################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$logger->send("$robotname :: Instance Completed  :: $pid\n");	
$dbobject->commit();
