#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBIL/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Bhs';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
###########################################

############ Proxy Initialization #########
my $country = $1 if($robotname =~ m/\-([A-Z]{2})\-\-/is);
DBIL::ProxyConfig($country);
###########################################

##########User Agent#######################
my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;
###########################################

############Cookie File Creation###########
my ($cookie_file,$retailer_file) = DBIL::LogPath($robotname);
my $cookie = HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
$ua->cookie_jar($cookie);
###########################################

############Database Initialization########
my $dbh = DBIL::DbConnection();
###########################################

my $select_query = "select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);
DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################

my $url = 'http://www.bhs.co.uk/';
my $content = get_content($url);
#open FH , ">home.html" or die "File not found\n";
#print FH $content;
#close FH;
my %hash_id;

############ URL Collection ##############
my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Sale\s*(?:&amp;\s*Offers)?|Offers)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title=\"(Women)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title\s*\=\s*\"\s*(Home\s*(?:\,?\s*Lighting\s*&(?:amp\;)?\s* Furnitures?)?\s*)\s*\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\s*\"[^<]*title=\"(Men)\"[^<]*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Children)\"[^<]*>','<li\s*class=\"[^<]*?471109\"\s*>\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*home)\"[^<]*title=\"(Wedding)\"[^<]*>','<li\s*class=\"[^<]*?1288491\">\s*<a\s*[^<]*\s*href\s*\=\s*\"([^<]*)\"[^<]*title=\"(Gifts)\"[^<]*>');   ##To take Block for Each TopMenu's

my $robo_menu=$ARGV[0];

foreach my $regex(@regex_array)
{	
	if ( $content =~ m/$regex/is )
	{
		my $url=$1;
		my $menu_11=DBIL::Trim($2);  #Menu1=>Women
		$url =~ s/amp;//g;
		
		my $main_page_content = get_content($url);
		my ($menu_22,$menu_2_blk);
		
		if(($menu_11=~m/$robo_menu/is)&&($robo_menu=~m/(?:Sale\s*(?:&amp;\s*Offers)?|Offers)/is))  #Menu1=>sale Scenario 1
		{
			if ( $main_page_content =~ m/<ul\s*class\s*\=\s*\"\s*column_1\s*\"\s*>\s*<li\s*class\s*\=\s*\"\s*category_935514\s*"\s*>([\w\W]*?)<\/ul>\s*<\/div>/is)
			{
				$menu_2_blk=$1;   #Menu2 Block
				&func($menu_2_blk,$menu_11,'');  #Passing Menu2 Block their Menu
			}
		}
		else
		{
			if(($menu_11=~m/$robo_menu/is)&&($menu_11=~m/(?:Home|women|Men|children|Wedding)/is)) #Scenario 2
			{
				while ( $main_page_content =~ m/<a[^<]*?class\s*\=\s*\"\s*division\s*\"[^<]*?>([^<]*?)<\/a>\s*<ul>([\w\W]*?)<\/ul>/igs ) 
				{
					$menu_22=DBIL::Trim($1);  #Menu2 => Shop by Collection, Clothing,etc.
					$menu_2_blk=$2;           #Menu2 Block
					
					if($menu_22=~m/(?:\s*looks\s*\&(?:amp;)?\s*features\s*|buying\s*guides|BHSfurniture.co.uk|bhsdirect.co.uk)/is)
					{
						next;
					}
					&func($menu_2_blk,$menu_11,$menu_22); #Passing Menu2 Block with their Menu
				}
			}
			elsif(($menu_11=~m/$robo_menu/is)&&($menu_11=~m/Gifts/is)) #Scenario 3
			{
				&GetProductcat($url,$menu_11,'','','','','','');  #Gifts TopMenu do not have Block Hence Directly collecting Products
			}
			else
			{
				next;
			}
		}
	}
}

sub func()  #Function to take LHM Menu's(#3 Scenario's-pages having single left navigation,double left navigation,without left nevigation)
{		
	my $menu_22_blk=shift;
	my $menu_1=shift;
	my $menu_2=shift;
	while($menu_22_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
	{
		my $main_list_url = $1;
		my $menu_3=DBIL::Trim($2);   ##New Arrivals
		$main_list_url =~ s/amp;//g;
		my ($category_url,$menu_4,$menu_4_cat,$main_list_content,$menu_5_cat,$menu_5,$main_list_url2);
		
		unless($main_list_url=~m/^\s*http\:/is)
		{
			$main_list_url="http://www.bhs.co.uk".$main_list_url;
		}	
			
		# again:
		if($menu_3=~m/^\s*sale\s*$|^\s*All\s*Women\'s\s*Sale\s*$|^Furniture$/is)
		{
			next;
		}
		
		my $main_list_content = get_content($main_list_url);
		
		if($main_list_content=~m/<ul\s*id\s*\=\s*\"\s*leftnav\s*"\s*>/is)  ##1st left navigation
		{
			while($main_list_content=~m/<li>\s*<h2>([^<]*?)<([\w\W]*?)<\/ul>/igs) 
			{
				$menu_4_cat=DBIL::Trim($1);   
				my $menu_44_blk=$2;
				
				while($menu_44_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
				{
					my $main_list_url1=$1;
					$menu_4=DBIL::Trim($2);
					$main_list_url1 =~ s/amp;//g;
					
					if($menu_4=~m/(?:See|view)\s*All\s*[^>]*?/is)
					{
						next;
					}
					
					unless($main_list_url1=~m/^\s*http\:/is)
					{
						$main_list_url1="http://www.bhs.co.uk".$main_list_url1;
					}
					
					my $main_list_content1 = get_content($main_list_url1);
					
					if($main_list_content1=~m/<ul\s*id\s*\=\s*\"\s*leftnav\s*"\s*>/is)   ####2nd left navigation
					{
						while($main_list_content1=~m/<li>\s*<h2>([^<]*?)<([\w\W]*?)<\/ul>/igs)
						{
							$menu_5_cat=DBIL::Trim($1);   
							my $menu_55_blk=$2;
							
							while($menu_55_blk=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>([^>]*?)</igs)
							{
								$main_list_url2=$1;
								$menu_5=DBIL::Trim($2);
								$main_list_url2 =~ s/amp;//g;
								
								if($menu_5=~m/^(?:See|view)\s*All\s*/is)
								{
									next;
								}
								
								unless($main_list_url2=~m/^\s*http\:/is)
								{
									$main_list_url2="http://www.bhs.co.uk".$main_list_url2;
								}
								
								&GetProductcat($main_list_url2,$menu_1,$menu_2,$menu_3,$menu_4_cat,$menu_4,$menu_5_cat,$menu_5);  #passing url's which is having 2 left navigations
							}
						}
					}
					else
					{
						&GetProductcat($main_list_url1,$menu_1,$menu_2,$menu_3,$menu_4_cat,$menu_4,'',''); #passing url's which is having single left navigations
					}
				}
			}
		}
		else
		{
			&GetProductcat($main_list_url,$menu_1,$menu_2,$menu_3,'','','','');   #passing url's of page having no left navigation
		}
	}
}

sub GetProductcat()   #Function to collect product by Filter
{
	my $main_list_url_main=shift;
	my $menu_11=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $menu_4_cat1=shift;
	my $menu_44=shift;
	my $menu_5_cat1=shift;
	my $menu_55=shift;
	$main_list_url_main =~ s/amp;//g;
	
	my $main_list_content_main = get_content($main_list_url_main);
	
	while( $main_list_content_main =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)    
	{
		my $part_name = DBIL::Trim($1); #Taking Part name
		my $list_part_content = $2;     #Taking Part's Block
		
		if($part_name=~m/Category/is)  #If Product page having "category" in LHM (Filtering Products by category)
		{
			while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)
			{
				my $category_url = $1;
				my $category_name = DBIL::Trim($2);  #Taking Category name
				$category_url =~ s/amp;//g;
				
				&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55); #Passing Product's url to collect Products
				my $main_list_content_main1=get_content($category_url);
				
				if($main_list_content_main1=~m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)
				{
					while ( $main_list_content_main1 =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!\s*Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)   
					{
						my $part_name = DBIL::Trim($1);   #Taking Part name
						my $list_part_content = $2;       #Taking Part's Block
						
						if($part_name=~m/Category/is)    #Filtering Products by Category within Category
						{
							while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)
							{
								my $category_url = $1;
								my $category_name = DBIL::Trim($2);  #Taking Category name
								$category_url =~ s/amp;//g;
								
								&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);#Passing Product's url  to collect Products
								my $main_list_content_main1=get_content($category_url);
								
								if($main_list_content_main1=~m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)
								{
									while ( $main_list_content_main1 =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!\s*Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)  
									{
										my $part_name = DBIL::Trim($1);   #Taking Part name
										my $list_part_content = $2;       #Taking Part's Block
										
										while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs) 
										{
											my $category_url = $1;
											my $category_name = DBIL::Trim($2);   #Taking Category name
											$category_url =~ s/amp;//g;
											
											&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);#Passing Product's url to collect Products
										}
									}
								}
							}
						}
						else
						{
							while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)#If Product page not having "category" within Category in LHM (Filtering Products that does not have category within Category)
							{
								my $category_url = $1;
								my $category_name = DBIL::Trim($2);  
								$category_url =~ s/amp;//g;
								
								&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);
							}
						}
					}
				}
			}
			$main_list_content_main='';
		}
		else  #If Product page not having "category" in LHM (Filtering Products that does not have category)
		{
			while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)<\/a>/igs)  
			{
				my $category_url = $1;
				my $category_name = DBIL::Trim($2);  ##All clothing
				$category_url =~ s/amp;//g;
				
				&GetProduct($category_url,$category_name,$part_name,$menu_11,$menu_22,$menu_33,$menu_4_cat1,$menu_44,$menu_5_cat1,$menu_55);#Passing Product's url to collect Products
			}
		}
	}
}
					
sub GetProduct()  #Function to collect Products
{					
	my $category_url1=shift;
	my $category_name1=shift;
	my $part_name1=shift;
	my $menu_111=shift;
	my $menu_222=shift;
	my $menu_333=shift;
	my $menu_4_cat11=shift;
	my $menu_444=shift;
	my $menu_5_cat11=shift;
	my $menu_555=shift;
	my $product_list_content;
	
	unless($category_url1=~m/^\s*http\:/)
	{
		$category_url1="http://www.bhs.co.uk/en/bhuk/category/"."$category_url1";
		$category_url1=~ s/amp;//g;
	}
	$category_name1 =~s/(\([\w]*\))//;
	
next_page:
	
	my $category_url11="$category_url1"."&pageSize=200";
	
	my $staus=get_content_status($category_url11);
	
	if($staus=~m/200/is)
	{
		$product_list_content = get_content($category_url11);
	}
	else
	{
		$product_list_content = get_content($category_url1);
	}
	
	while($product_list_content=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">/igs)   
	{
		my $product_url=$1;
		print "product_url :$product_url\n";	
		
		unless($product_url=~m/^\s*http\:/is)
		{
			$product_url=$url.$product_url;
		}
		$product_url =~ s/amp;//g;
		
		if($product_url=~m/([^<]*productId=[^<]*?&langId=-1)[^<]*?/is)
		#### Making Unique Product URL (If url like "http://www.bhs.co.uk/webapp/wcs/stores/servlet/ProductDisplay?refinements=category~%5b471666%7c471194%5d%5ecategory~%5b471666%7c471194%5d%5ecategory~%5b472090%7c471666%5d&beginIndex=41&viewAllFlag=&catalogId=34096&storeId=13077&productId=5108303&langId=-1")
		{
			$product_url=$1;
			$product_url=~s/^([^>]*?\?)[^>]*?(\&catalogId=[^<]*?)$/$1$2/igs;
		}		
		elsif($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) #### Making Unique Product URL (If url like "http://www.bhs.co.uk/en/bhuk/product/great-value-polka-print-jersey-gypsy-dress-2651313")
		{
			$product_url='http://www.bhs.co.uk/en/bhuk/product/'.$1;
		}
		
		###Getting Product_Id to Remove Duplicates
		my $prod_id;
		
		if($product_url=~m/productId\s*\=\s*(\d+)/is)
		{
			$prod_id=$1;
		}
		elsif($product_url=~m/^[^>]*?(\d+)$/is)
		{
			$prod_id=$1;
		}
		
		###Insert Product values
		my $product_object_key;
		if($hash_id{$prod_id} eq '')
		{
			$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
			$hash_id{$prod_id}=$product_object_key;
		}
		else
		{
			$product_object_key=$hash_id{$prod_id};
		}
		   
		###Insert Tag values
		DBIL::SaveTag('Menu_1',$menu_111,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		
		unless($menu_333 eq '')
		{
			if($menu_111=~m/(?:Sale\s*(?:&amp;\s*Offers)?|Offers|Sale)/is)
			{
				DBIL::SaveTag('Menu_2',$menu_333,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			else
			{
				DBIL::SaveTag($menu_222,$menu_333,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		
		unless($menu_444 eq '')
		{
			DBIL::SaveTag($menu_4_cat11,$menu_444,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);	
		}
		unless($menu_555 eq '')
		{
			DBIL::SaveTag($menu_5_cat11,$menu_555,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);	
		}
		
		DBIL::SaveTag($part_name1,$category_name1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);	
		$dbh->commit();
	}
	
	if ($product_list_content =~ m/<a\s*href=\"([^<]*?)\"\s*title=\"Show\s*next\s*page\">/is )
	{
		$category_url1 = $1;
		$category_url1 =~ s/amp;//g;
		goto next_page;
		
	}
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

#Obtaining Product Page's Content
sub get_content()
{
    my $url=shift;
    my $rerun_count=0;
    Home:
    my $req = HTTP::Request->new(GET=>"$url");
    $req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
    my $res = $ua->request($req); 
    $cookie->extract_cookies($res); 
    $cookie->save; 
    $cookie->add_cookie_header($req); 
    my $code = $res->code(); 
    print $code,"\n"; 
    open LL,">>".$retailer_file;
    print LL "$url=>$code\n";
    close LL;
    if($code =~m/20/is)
	{
		return($res->content());
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto Home;
		}
	}
}
#Obtaining Product Page's response code
sub get_content_status
{
        my $url = shift;
        my $rerun_count=0;
        Home:
        $url =~ s/^\s+|\s+$//g;
        $url =~ s/amp\;//g;
        my $req = HTTP::Request->new(GET=>"$url");
        $req->header("Content-Type"=> "text/plain");
        my $res = $ua->request($req);
        $cookie->extract_cookies($res);
        $cookie->save;
        $cookie->add_cookie_header($req);
        my $code=$res->code;
        if($code =~m/20/is)
        {
         return $code;
        }
        else
        {
                if ( $rerun_count <= 3 )
                {
                        $rerun_count++;
                        goto Home;
                }
        }
}
