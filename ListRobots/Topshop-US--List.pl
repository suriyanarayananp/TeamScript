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
my $Retailer_Random_String='Tus';
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

# Getting main page content.
my $url = 'http://us.topshop.com/';
my $content = $utilityobject->Lwp_Get("$url");
my %totalHash;

# Array to take block for each top menus. 
my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(New\s*In)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Clothing)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Shoes)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Bags\s*&amp;\s*Accessories)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Make\s*Up)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Sale\s*(?:\&(?:amp;)?\s*Offers)?)\"[^>]*?>[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>');

# my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(New\s*In)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Clothing)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>');

my $robo_menu=$ARGV[0];

foreach my $regex (@regex_array)
{
	# Pattern Match to get Each Topmenu and the Corresponding url from @regex_array. (Menu1=> Clothing)
	if ( $content =~ m/$regex/is )
	{
		my $urlcontent = $2;
		my $menu_1=$utilityobject->Trim($1); 
		
		# Pattern Match to get product urls from category one by one.
		next unless($menu_1 eq $robo_menu);
		
		# Pattern Match to get Each submenu from TopMenu's Block. (Menu2=> Dresses).
		while ( $urlcontent =~ m/<a[^<]*?href\=\"([^<]*?)\"\s*title\=\"[^<]*?\">([^<]*?)</igs )
		{
			my $main_list_url = $1;
			my $menu_2=$utilityobject->Trim($2);
			
			$menu_2='' if($menu_1=~m/SALE/is);
			
			# Pattern Match to skip if Menu2 is "View All".
			next if($menu_2=~m/^\s*A\-Z\s*$|^\s*View\s*All\s*$|^\s*We\s*Love\s*$/is);;
			
			# Pattern match to add Home Url if url doesn't start with "http".
			$main_list_url=$url.$main_list_url unless($main_list_url=~m/^\s*http\:/is);
			
			&collect_product($main_list_url,$menu_1,$menu_2,'','','','');# Function call to collect product urls.
			
			my $main_list_content = $utilityobject->Lwp_Get($main_list_url);
			
			# Pattern match to get LHM Header and their corresponding Block(Header=> Category & it's Block).
			if ( $main_list_content =~ m/<span\s*class=\"filter_label[^<]*\">((?![^<]*?Brand|[^>]*?Rating|[^>]*?Price|[^>]*?Accessories|[^<]*?Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is) 
			{
				my $part_name = $utilityobject->Trim($1);  
				my $list_part_content = $2; 
				$part_name=~s/Â//igs;
				
				# Pattern match to check whether header name is Category. 
				if($part_name=~m/\s*Categor(?:y|ies)\s*/is)  
				{
					my $count1=1;
					
					# Pattern match to get each Submenu & It's url under the header from block.(Eg. Party Dresses).
					while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^<]*?)</igs)
					{
						my $category_url = $1;
						my $category_name = $utilityobject->Trim($2);  
						
						my $count=1;
						
						# Pattern match to collect products if the "first submenu" or "only submenu" under Category is view all.
						if(($count1==1)&&($category_name=~m/^\s*View\s*All\s*/is))
						{
							goto Color;
						}
						elsif($category_name=~m/^\s*View\s*All\s*/is) #Pattern match to skip view all(If not first Submenu). 
						{
							next;
						}
						$count1++;
						
						# Pattern match to add home url if url doesn't start with "http".
						$category_url=$url.$category_url unless($category_url=~m/^\s*http\:/is);
										
						# To get the content from the URL.
						my $product_list_content=$utilityobject->Lwp_Get($category_url);
						
						&collect_product($category_url,$menu_1,$menu_2,$part_name,$category_name,'',''); # Function call to collect product urls.
Color:						
						# To get the content from the URL.
						my $main_list_content_color=$utilityobject->Lwp_Get($category_url);
						
						# Pattern match to skip view all(won't skip if 1st submenu is "view all").
						if($count==1)
						{
							# Pattern match to get LHM Header "Colour" and their corresponding Block(Header=> Colour & it's Block).
							if ( $main_list_content_color =~ m/<span\s*class=\"filter_label[^<]*\">([^<]*?Colo(?:u)?r)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)								
							{
								my $part_name_clr = $utilityobject->Trim($1);
								my $list_part_content1 = $2;
								$part_name_clr=~s/Â//igs;
								
								# Pattern match to get each LHM menus under header colour.
								while($list_part_content1=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^<]*?)</igs)
								{
									my $category_url_clr = $utilityobject->Trim($1);
									my $category_name_clr = $utilityobject->Trim($2);
									
									$category_name_clr=&ProperCase($category_name_clr);
									$category_name_clr=~s/\-(\w)/-\u\L$1/is;
									sub ProperCase
									{
									 join(' ',map{ucfirst(lc("$_"))}split(/\s/,$_[0]));
									}
									
									$category_url_clr=$url.$category_url_clr unless($category_url_clr=~m/^\s*http\:/is);
									
									&collect_product($category_url_clr,$menu_1,$menu_2,$part_name,$category_name,$part_name_clr,$category_name_clr);# Function call to collect product urls.
								}										
							}
							$count++;
						}
					}
				}
				else  # Products taken under color filter.
				{
					$part_name= 'Color';
					# Pattern match to get LHM Header and their corresponding Block except "view all". 
					while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^<]*?)</igs)
					{
						my $category_url = $1;
						my $category_name = $utilityobject->Trim($2);

						$category_url=$url.$category_url unless($category_url=~m/^\s*http\:/is);
						
						# Pattern match to collect Products.
						&collect_product($category_url,$menu_1,$menu_2,$part_name,$category_name,'','');# Function call to collect product urls.
					}										
				}
			}
			else
			{
				# print "Block Not Matching\n";
			}
		}
	}
}

sub collect_product()
{
	my $category_url_1=shift;
	my $menu1=shift;
	my $menu2=shift;
	my $part_name1=shift;
	my $category_name1=shift;
	my $part_name_clr1=shift;
	my $category_name_clr1=shift;
	
next_page:	
	# To get the content from the URL.
	my $product_list_content_main=$utilityobject->Lwp_Get($category_url_1);

	# Looping through to collect product urls.
	while($product_list_content_main=~m/<a[^<]*?href=\"([^<]*?)\"[^>]*?data\-productId=\"[^>]*?\"[^>]*?>/igs) 
	{
		my $product_url=$1;
		# Pattern match to add home url if url doesn't start with "http".
		$product_url=$url.$product_url unless($product_url=~m/^\s*http/is);
		$product_url =~ s/amp;//g;
		
		# Pattern match to make Unique Product URL.
		if($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is)
		{
			$product_url='http://us.topshop.com/en/tsus/product/'.$1;
		}
		elsif($product_url=~m/^[^>]*\/([^>]*?)$/is)
		{
			$product_url='http://us.topshop.com/en/tsus/product/'.$1;
		}
		
		# Insert Product values.
		my $product_object_key;
		
		if($totalHash{$product_url} ne '')
		{
			# Assigning Objectkey of new product's tag to already existed Product's tag and skip the URL
			$product_object_key = $totalHash{$product_url};
		}
	   else
	   {
			# Insert Product URL if URL not exist.
			$product_object_key = $dbobject->SaveProduct($product_url,$robotname,$retailer_id,$Retailer_Random_String);
			$totalHash{$product_url}=$product_object_key;
	   }

		# Insert Tag  values.
		$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
		$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
		$dbobject->SaveTag('Category',$category_name1,$product_object_key,$robotname,$Retailer_Random_String) if(($category_name1 ne '') && ($part_name1 eq ''));
		$dbobject->SaveTag($part_name1,$category_name1,$product_object_key,$robotname,$Retailer_Random_String) if(($category_name1 ne '') && ($part_name1 ne ''));
		$dbobject->SaveTag($part_name_clr1,$category_name_clr1,$product_object_key,$robotname,$Retailer_Random_String) if($part_name_clr1 ne '');
		
		# Committing the transaction.
		$dbobject->commit();
	}
	
	# Pattern match to get url for the next page.
	if ( $product_list_content_main =~ m/<li\s*class=\"show_next\">\s*<a\s*href=\"([^<]*?)\"[^>]*?>/is )
	{
		$category_url_1 = $1;
		$category_url_1 =~ s/amp;//g;
		goto next_page;
	}
}
$logger->send("$robotname :: Instance Completed  :: $pid\n");
#################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$dbobject->commit();
