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
my $Retailer_Random_String='Zuk';
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
my $content = $utilityobject->Lwp_Get("http://www.zara.com/uk/");
# open FH , ">home.html" or die "File not found\n";
# print FH $content;
# close FH;

# Array to take each top menus and it's url.
my @regex_array=(
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(NEW\s*THIS\s*WEEK)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(WOMAN)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(MAN)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(KIDS)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(TRF)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(DENIM)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(SHOES\s*\&(?:amp\;)?\s*BAGS)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(SALE)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(MINI)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(NEW COLLECTION)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(Special\s*Prices)\s*<\/a>');  #Top Menu Collection
my %hash_id;

# Passing topmenu as argument to get the products under the corresponding topmenu. 
my $robo_menu=$ARGV[0];

# Getting each pattern to get menu and it's url from array.
foreach my $regex(@regex_array)
{
	# Pattern match to get each topmenu and the url from the array.
	if ( $content =~ m/$regex/is )
	{
		my $menu_1_url = $1;		          # Menu1 url. 	
		my $menu_1=$utilityobject->Trim($2);  # Menu1
		my $menu_1=$utilityobject->Decode($menu_1);  # Menu1
		
		# Pattern match to skip topmenu url if menu passed as argument doesn't same as topmenu.
		next unless($menu_1 eq $robo_menu);
		
		# Declaring required variables.
		my ($cat_id,$menu_2,$menu_3,$menu_4,$menu_5);
		
		&Product_Collection($menu_1_url,$menu_1,'','',''); # Function call with menus and their url as arguments to collect product urls.(Some products available in main category's alone not in sub-category's ..hence product collection needed)
		
		my $menu_1_content = $utilityobject->Lwp_Get($menu_1_url);
		
		# Pattern match to get block to navigate through next submenu.
		if($menu_1_content =~ m/<ul\s*class=\"current\">\s*<li([\w\W]*\s*<\/a>\s*<\/li>)\s*<\/ul>\s*<\/li>/is)
		{
			my $menu_2_content_block=$&;
			
			# Pattern match to get next submenus from the above block.
			while($menu_2_content_block =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*([^<]*?)\s*<\s*\/a\s*>/igs)  ##SubMenu1 (Eg.Coats)
			{
				my $menu_2_url=$1;
				$menu_2=$utilityobject->Trim($2);
				$menu_2=$utilityobject->Decode($menu_2);
				# print"menu_2 $menu_2\n";
				
				###next unless(($menu_2=~m/Cardigans\s*and\s*Sweaters/is)&&($menu_1=~m/MINI/is)); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
				next if($menu_2=~m/Sale/is); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
				
				
				&Product_Collection($menu_2_url,$menu_1,$menu_2,'',''); # Function call with menus and their url as arguments to collect product urls.
				
				my $menu_2_content = $utilityobject->Lwp_Get($menu_2_url);
				
				my $menu_2_quoted = quotemeta($menu_2);
				
				##if($menu_2_content =~ m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>\s*<\/li>\s*<\/ul>/is)# Pattern match to check whether next navigate available.
				if($menu_2_content =~ m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>\s*<\/li>/is)# Pattern match to check whether next navigate available.
				{
					#if($menu_2_content =~ m/<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>\s*$menu_2_quoted\s*<[^>]*?>\s*<ul\s*class="current">([\w\W]*?)<\/ul>([\w\W]*?)<\/ul>\s*<\/li>\s*<\/ul>/is)##SubMenu2 Block
					##if($menu_2_content =~ m/<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>\s*Girl\s*\(3-14\s*years\)\s*<[^>]*?>\s*<ul\s*class="current">([\w\W]*?)<\/ul>([\w\W]*?)<\/ul>\s*<\/li>/is)##SubMenu2 Block
					if($menu_2_content =~ m/<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>\s*$menu_2_quoted\s*<[^>]*?>\s*<ul\s*class="current">([\w\W]*?)<\/ul>([\w\W]*?)<\/ul>\s*<\/li>/is)##SubMenu2 Block
					{
						my $main_block_menu2=$1;
						my $main_block_next=$2;
						
						# Pattern match to get block to navigate through next submenu.
						while($main_block_menu2 =~ m/<li\s*id\=\"menuItemData_[\d]+\"\s*class\=\"[^>]*?\">\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>|<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>([^<]*?)<([\w\W]*?)$/igs)##SubMenu2 Block
						{
							my $menu_3_url=$1;
							my $menu_3=$2.$3;
							my $menu_3_urls_block =$4;
							
							next if($menu_3 eq "Sale"); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
							
							&Product_Collection($menu_3_url,$menu_1,$menu_2,$menu_3,'');
							
							# Pattern match to get next submenus from the above block.
							while($menu_3_urls_block =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*(?!\s*View\s*All)([^<]*?)\s*<\s*\/a\s*>/igs) ##SubMenu2
							{
								my $menu_4_url =$1;
								my $menu_4=$utilityobject->Trim($2); 
								my $menu_4=$utilityobject->Decode($menu_4); 
								# print"menu_3 in scenario1: $menu_3\n";
								
								next if($menu_4 eq "Sale"); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
								
								&Product_Collection($menu_4_url,$menu_1,$menu_2,$menu_3,$menu_4); # Function call with menus and their url as arguments to collect product urls.
							}
						}
						
						while($main_block_next=~m/<a[^>]*?href\s*\=\s*\"([^>]*?)\s*\"[^>]*?>\s*([^>]*?)\s*</igs)
						{
							my $Next_cat_url=$1;
							my $menu_3=$2;
							
							&Product_Collection($Next_cat_url,$menu_1,$menu_2,$menu_3,''); # Function call with menus and their url as arguments to collect product urls.
							
							my $Next_cat_content = $utilityobject->Lwp_Get($Next_cat_url);
							
							if($Next_cat_content =~ m/<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>\s*$menu_3\s*<([\w\W]*?)<\/ul>/is)##SubMenu2 Block
							{
								my $menu_3_urls_block=$1;
								
								# print"menu_3 in Scenario1 in next: $menu_3\n";
								next if($menu_3 eq "Sale"); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
								
								# Pattern match to get next submenus from the above block.
								while($menu_3_urls_block =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*(?!\s*View\s*All)([^<]*?)\s*<\s*\/a\s*>/igs) ##SubMenu2
								{
									my $menu_4_url =$1;
									my $menu_4=$utilityobject->Trim($2); 
									my $menu_4=$utilityobject->Decode($menu_4); 
									# print"menu_4  in Scenario1: $menu_4\n";
									next if($menu_4 eq "Sale"); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
									
									&Product_Collection($menu_4_url,$menu_1,$menu_2,$menu_3,$menu_4); # Function call with menus and their url as arguments to collect product urls.
								}
							}
						}
					}
					elsif($menu_2_content =~ m/<li[^>]*?class\s*\=\s*\"\s*current\s*\"\s*>\s*\s*<a[^>]*?>\s*$menu_2_quoted\s*<[^>]*?>\s*<ul\s*class="current">([\w\W]*?)<\/ul>\s*<\/li>/is)
					{
						# print">>>>>>>>>>         In Scenario1 sub\n";
						my $menu_3_block=$1;
						
						while($menu_3_block =~ m/<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>\s*([^>]*?)</igs)##SubMenu2 Block
						{
							my $menu_3_url=$1;	
							my $menu_3=$2;	
							
							# print">>>>>>>sub menu_3 $menu_3\n";
							next if($menu_3 eq "Sale"); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
							
							&Product_Collection($menu_3_url,$menu_1,$menu_2,$menu_3,'');
							
							my $menu_3_content = $utilityobject->Lwp_Get($menu_3_url);
							
							my $menu_3_quoted=quotemeta($menu_3);
							
							if($menu_3_content=~m/<li[^>]*?class\s*\=\s*\"\s*current[^>]*?\"[^>]*?>\s*<a[^>]*?>\s*$menu_3_quoted\s*<[^>]*?>\s*<ul\s*class="current">([\w\W]*?)<\/ul>\s*<\/li>/is)
							{
								my $menu_4_block=$1;
								
								while($menu_4_block=~m/<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>\s*([^>]*?)</igs)
								{
									my $menu_4_url=$1;	
									my $menu_4=$utilityobject->Trim($2); 
									my $menu_4=$utilityobject->Decode($menu_4);
									
									&Product_Collection($menu_4_url,$menu_1,$menu_2,$menu_3,$menu_4);
								}
							}
						}
					}
				}
				elsif($menu_2_content =~ m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>/is)	# Pattern match to check whether next navigate available.
				{
					# Pattern match to get block to navigate through next submenu.
					while($menu_2_content =~ m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>/igs)##SubMenu2 Block
					{
						my $menu_3_content_block=$1;
						
						# Pattern match to get next submenus from the above block.
						while($menu_3_content_block =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*(?!\s*View\s*All)([^<]*?)\s*<\s*\/a\s*>/igs) ##SubMenu2
						{
							my $menu_3_url =$1;
							my $menu_3=$utilityobject->Trim($2); 
							my $menu_3=$utilityobject->Decode($menu_3); 
							# print"menu_3 in scenario2 : $menu_3\n";
							
							next if($menu_3=~m/Sale/is); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
							
							
							&Product_Collection($menu_3_url,$menu_1,$menu_2,$menu_3,''); # Function call with menus and their url as arguments to collect product urls.
							
							my $main_list_content = $utilityobject->Lwp_Get($menu_3_url);
							
							# Pattern match to get block to navigate through next submenu.
							if($main_list_content=~m/>\s*$menu_3\s*(?:\s*<[^>]*?>\s*)*\s*<ul class="current">([\w\W]*?)<\/ul>/is)
							{
								my $menu_4_block=$1;
								# print"menu_4 in scenario2 : $menu_4\n";
								
								# Pattern match to get next submenus from the above block.
								while($menu_4_block=~m/<\s*a\s*href=\"([^<]*?)"\s*>\s*(?!\s*View\s*All)([^<]*?)\s*<\s*\/a\s*>/igs)
								{
									my $menu_4_url=$1;
									my $menu_4=$2;
									# print "in menu 4 $menu_4\n";
									next if($menu_4=~m/Sale/is); # To skip if menu2 is sale (Redirected to SALE menu which is being taken separately).
									
									&Product_Collection($menu_4_url,$menu_1,$menu_2,$menu_3,$menu_4); # Function call with menus and their url as arguments to collect product urls.
								}
							}
						}
					}
				}
			}
		}
	}
}

# Function definition to collect products.
sub Product_Collection
{
	my $category_url=shift;
	my $menu1=shift;
	my $menu2=shift;
	my $menu3=shift;
	my $menu4=shift;
	
	my $cat_id=$1 if($category_url=~m/\-?\s*c\s*(\d+)\s*\.\s*html/is);
	print "in $category_url\t\n$menu1\t$menu2\t$menu3\t$menu4\n";
	
	my $Product_list_content = $utilityobject->Lwp_Get($category_url);
	
	my $char_url='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=STATIC&ajaxCall=true';
	# Formation of characteristic url for the produts under respective category(In filter).
	
	my $color_url='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=DYNAMIC&ajaxCall=true';
	# Formation of color url for the produts under respective category(In filter). 
	
	print "CHAR URL::: $char_url\n";
	print "Colour URL::: $color_url\n";
	#<STDIN>;
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
	print "Inside the CHARACTER TAG\n";
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
			print "NAME:: $name1\n";
			# Pattern match to get the sku id's(Product id's) block from the main block.
			if($Type_blk11=~m/\"\s*skus\s*\"\s*\:([\w\W]*?\"\])/is)   
			{
				my $Skus_id_blk1=$1;
				
				# Looping through to get each sku id's from the skuid's block.
				while($Skus_id_blk1=~m/(?:\"|\')\s*([^\'\"]*?)\s*(?:\"|\')/igs)
				{
					my $Skuid1=$1;
					print "CHAR ID::: $Skuid1 \t $prod_id1\n";
					# Pattern match to get the tag information if product id in product url and sku id from the block is same.
					if(($Skuid1 eq $prod_id1)||($Skuid1=~m/$prod_id1/))
					{
						$Type1=~s/features/characteristics/igs;
						$Type1=~s/quality/qualities/igs;
						print "CHARATER::: $Type1 \t $name1\n";
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
