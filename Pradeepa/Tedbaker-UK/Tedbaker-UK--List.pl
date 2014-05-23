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
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
$robotname =~ s/\.pl//igs;
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Ted';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
###########################################

############ Proxy Initialization #########
my $country = $1 if($robotname =~ m/\-([A-Z]{2})\-\-/is);
DBIL::ProxyConfig($country);
###########################################

##########User Agent######################
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

my $url = 'http://www.tedbaker.com/uk?country=GB';
#open FH , ">home.html" or die "File not found\n";
#print FH $content;
#close FH;

############ URL Collection ##############
my $content = get_content($url);

if($content=~m/<nav[^>]*?>([\w\W]*?)<\/nav>/is)
{
	my $blk=$1; #Main Block
	my $menu_1_link_content;
	
	while($blk=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>([^>]*?)</igs) #title\s*\=\s*(?:\"|\')\s*([^<]*?)(?:\"|\')
	{
		my $url_1=$1;   
		my $menu_1=DBIL::Trim($2);  #Menu1=>Men, Women
		my @menu_2;
	
		my ($category_block,$category_block1,$category_url,$category_head);
		
		unless($url_1=~m/^\s*http\:/is)
		{
			$url_1='http://www.tedbaker.com'.$url_1;
		}
		
		$menu_1_link_content = get_content($url_1);
		
		while($menu_1_link_content=~m/<li \s*class\s*\=\s*\"\s*category_home\s*\"\s*>\s*<a[^>]*?href="\s*(\/uk\/[^\"]*?)\s*\"\s*title="\s*([^\"]*?)\s*"\s*>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>\s*<\/div>\s*<\/li>/igs) ###Clothing,Acc,Footwear,Gifts
		{
			my $menu_2_url = $1;
			my $menu_2 = DBIL::Trim($2);   ####Menu2=>Clothing,Accessories,Footwear,Gifts
			my $menu_2_block=$3;   
			push(@menu_2,$menu_2);	
		
			while($menu_2_block=~m/<a[^>]*?href="\s*(\/uk\/[^\"]*?)\s*\"\s*title="\s*([^\"]*?)\s*"\s*>/igs)
			{
				my $menu_3_link=$1;
				my $menu_3= DBIL::Trim($2);    ###Menu3=>New Arrivals,Shirts
				
				unless($menu_3_link=~m/^\s*http\:/is)
				{
					$menu_3_link='http://www.tedbaker.com'.$menu_3_link;
				}
				my $menu_2_link_content = get_content($menu_3_link); 
			
				if($menu_3=~m/^\s*shirts\s*$/is)  ###shirts(Different Scenario)(Getting urls from Images) 
				{
					while($menu_2_link_content=~m/<li\s*class\s*\=\s*\"\s*image\s*\"\s*>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>/igs)
					{
						my $shir_url=$1;
						
						unless($shir_url=~m/^\s*http\:/is)
						{
							$shir_url='http://www.tedbaker.com'.$shir_url;
						}
						
						my $menu_2_link_content_shir = get_content($shir_url);
						
						if($menu_2_link_content_shir=~m/<select\s*id=\"facet_select_1\">([\w\W]*?)<\/ul>\s*<\/form>/is) ##To take Categories under Menus
						{
							$category_block=$1;
							
							while($category_block=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/igs)
							{
								$category_head=$1; #Category Heading
								$category_block1=$2;
								$category_head =~s/Â//igs;
								
								while($category_block1=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
								{
									$category_url="$shir_url"."?q="."$1";									
									my $category= DBIL::Trim($2); #Category name
									$category =~s/Â//igs;
									$category_url=~s/f\:/f%3A/igs;
									$category_url=~s/\,/%2C/igs;	
									&get_Product($category_url,$menu_1,$menu_2,$menu_3,$category_head,$category);
								}
							}
						}
					}
				}
				else
				{
					if($menu_2_link_content=~m/<select\s*id=\"facet_select_1\">([\w\W]*?)<\/ul>\s*<\/form>/is) ##To take Categories under Menus
					{
						$category_block=$1;
						while($category_block=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/igs)
						{
							$category_head=$1;  #Category Heading
							$category_block1=$2;
							$category_head =~s/Â//igs;
							
							while($category_block1=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
							{
								$category_url="$menu_3_link"."?q="."$1";
								my $category= DBIL::Trim($2); #Category name
								$category =~s/Â//igs;
								$category_url=~s/f\:/f%3A/igs;
								$category_url=~s/\,/%2C/igs;	
								&get_Product($category_url,$menu_1,$menu_2,$menu_3,$category_head,$category);
							}
						}
					}
				}
			}
		}
		&Chk_Footwear($menu_1_link_content,$menu_1);    ##Taking Footwear Details(Having no drop-down Menu)
	}
}

sub Chk_Footwear()    ##Function to Take Footwear Details
{
	my $menu_1_link_contentFoot=shift;
	my $menu1=shift;
	
	if($menu_1_link_contentFoot!~m/<li\s*class\s*\=\s*(?:\"|\')\s*category_home\s*(?:\"|\')\s*>\s*<a\s*class\s*\=\s*\"\s*\"\s*href\s*=\s*(?:\"|\')[^<]*?(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*Footwear\s*(?:\"|\')\s*[^>]*?>/is)
	{
		if($menu_1_link_contentFoot=~m/<li\s*class\s*\=\s*\"\s*\"\s*>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\s*\"[^>]*?>\s*(Footwear)\s*</is)
		{
			my $Foot_url=$1;
			my $menu_2=$2;
			
			$Foot_url='http://www.tedbaker.com'.$Foot_url if($Foot_url!~m/^\s*http/); 
			
			my $menu_2_link_cont_Foot = get_content($Foot_url); 
			
			if($menu_2_link_cont_Foot=~m/<select\s*id=\"facet_select_1\">([\w\W]*?)<\/ul>\s*<\/form>/is)  ##To take Categories under Menus
			{
				my $category_block=$1;
				
				while($category_block=~m/<option\s*value\s*\=\s*\"\s*\"\s*disabled\s*selected>(?![^<]*?Sizes|[^<]*?Prices|[^<]*?Prices)([^<]*?)<([\w\W]*?)<\/li>/igs)
				{
					my $category_head=$1;
					my $category_block1=$2;
					$category_head =~s/Â//igs;
					
					while($category_block1=~m/<option\s*value=\"([^>]*?)">([^>]*?)<\/option>/igs) 
					{
						my $category_url="$Foot_url"."?q="."$1";
						my $category= DBIL::Trim($2);
						$category =~s/Â//igs;
						$category_url=~s/f\:/f%3A/igs;
						$category_url=~s/\,/%2C/igs;	
						&get_Product($category_url,$menu1,$menu_2,'',$category_head,$category);
					}
				}
			}
		}
	}
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
#Function to get Products url
sub get_Product()
{	
	my $Content_url=shift;
	my $menu_11=shift;
	my $menu_22=shift;
	my $menu_33=shift;
	my $categ_h=shift;
	my $categ=shift;
	
	my $category_url_content = get_content($Content_url);			

	#NextPage:
	while($category_url_content=~m/<h4\s*class="name"><a\s*href="\s*([^\"]*?)\s*"[^>]*?>\s*([^<]*?)\s*<\/a>\s*<\/h4>/igs)
	{
		my $product_url=$1;
		$product_url=~s/\&\#x2f\;/\//igs;
		
		unless($product_url=~m/^\s*http\:/is)
		{
			$product_url='http://www.tedbaker.com'.$product_url;
		}
		
		###Insert Product values
		my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
		###Insert Tag values
		DBIL::SaveTag('Menu_1',$menu_11,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		
		unless($menu_22=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_2',$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		
		unless($menu_33=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_3',$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		
		unless(($categ=~m/^\s*$/is)&&($categ_h=~m/^\s*$/is))
		{
			DBIL::SaveTag($categ_h,$categ,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		$dbh->commit();
	}
}
#Function to get Product's Page Content
#TO get Product Page's Content
sub get_content()
{
	my $url=shift;
	my $err_count=0;
	$url=~s/amp\;//igs;
	home:
	my $req = HTTP::Request->new(GET=>"$url");
	my $res = $ua->request($req); 
    $cookie->extract_cookies($res); 
    $cookie->save; 
    $cookie->add_cookie_header($req); 
    my $code = $res->code(); 
    print $code,"\n"; 
    open LL,">>".$retailer_file;
    print LL "$url=>$code\n";
    close LL;
    if($code =~ m/50/is) 
    { 
        sleep 500; 
        goto home; 
    } 
    if($code =~m/40/is)
	{	
		$err_count++;
		if($err_count<=3)
		{
			sleep(100);
			goto home;	
		}
	}
	elsif($code =~m/50/is)
	{
		$err_count++;
		if($err_count<=3)
		{
			sleep(100);
			goto home;	
		}
	}
	elsif($code =~m/20/is)
	{
		$content = $res->content;
	}
	return($content);
}
