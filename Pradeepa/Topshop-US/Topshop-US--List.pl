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
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Tou';
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

my $url = 'http://us.topshop.com';
my $content = get_content($url);
# open FH , ">home.html" or die "File not found\n";
# print FH $content;
# close FH;

my %totalHash;

############ URL Collection ##############
my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(New\s*In)\s*(?:\"|\')\s*>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(Clothing)\s*(?:\"|\')\s*>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(Shoes)\s*(?:\"|\')\s*>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(Bags\s*(?:&amp;\s*Accessories)?)\s*(?:\"|\')\s*>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(Make\s*Up)\s*(?:\"|\')\s*>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*href=(?:\"|\')([^<]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*(Sale\s*&(?:amp;)?\s*Offers)\s*(?:\"|\')\s*>');

my $robo_menu=$ARGV[0];

foreach my $regex(@regex_array)
{
	if ( $content =~ m/$regex/is )
	{
		my $menu_1_url = $1;
		my $menu_1=DBIL::Trim($2); ### Menu 1(TopMenu) => New in,Clothing,Etc.
		
		next unless($menu_1 eq $robo_menu);
		
		my ($menu_2,$category_url,$menu_2_cat,$temp);
		
		my $menu_1_content = get_content($menu_1_url);
		
		if($menu_1_content=~m/<ul[^>]*?class\s*\=\s*\"\s*supernav\s*\"\s*>([\w\W]*?)<\/ul>/is)  ###LHM Block
		{
			my $mainblk=$1;
		
			while ( $mainblk =~ m/(?:<li[^>]*?class\s*\=\s*\"\s*navSubHeading\s*\"\s*[^>]*?>(?:\s*<a[^>]*?>\s*)?([^>]*?)\s*\:?\s*(?:\s*<[^>]*?>\s*)?<[^>]*?>\s*)?<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>([^>]*?)</igs ) ###SubMenu in LHM
			{
				$menu_2_cat=$1;  ##Shop by Category
				my $menu_2_url = $2;  
				$menu_2=DBIL::Trim($3);####Dresses
				$menu_2_url=~s/amp;//igs;
				
				if($menu_2_cat)
				{
					$temp=$menu_2_cat;
				}
				else
				{
					$menu_2_cat=$temp;
				}
				
				# again:
				if($menu_2=~m/^\s*A\-Z\s*$|^\s*View\s*All\s*$/is)
				{
					next;
				}
				unless($menu_2_url=~m/^\s*http\:/is)
				{
					$menu_2_url=$url.$menu_2_url;
				}
				
				my $main_list_content = get_content($menu_2_url);
				
				if($main_list_content=~m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)  ##if list page do not have category except "BRAND,COLOR,SIZE,price"    
				{
					while ( $main_list_content =~ m/<span\s*class=\"filter_label[^<]*\">((?!Rating)(?!Price)(?![^<]*\sSize)(?!Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)  
					{
						my $part_name = DBIL::Trim($1);
						my $list_part_content = $2;
						
						if($part_name=~m/^\s*SIZE\s*$|^\s*price\s*/is) 
						{
							next;
						}
						
						while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*(?!View\s*All)([\w\W]*?)\s*<\/a>/igs)  ##Category
						{
							my $category_url = $1;
							my $category_name = lc(DBIL::Trim($2));
							$category_url =~ s/amp;//g;
							
							next_page:
							unless($category_url=~m/^\s*http\:/is)
							{
								$category_url=$url.$category_url;
							}
							
							&GetProduct($category_url,$category_name,$part_name,$menu_1,$menu_2_cat,$menu_2);
							
							my $product_list_content=get_content($category_url);
							
							##Next Page
							if ( $product_list_content =~ m/<li\s*class=\"show_next\">\s*<a\s*href=\"([^<]*)\"\s*title=/is )
							{
								$category_url = $1;
								$category_url =~ s/amp;//g;
								goto next_page;
							}
						}
					}
				}
				else
				{
					# print "Block Not Matching\n";
				}
			}
		}
		if($menu_1_content=~m/<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"($menu_1)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>/is)  ##Menu1 (Topshop Magazine)
		{
			my $blk=$2;
			
			while ( $blk =~ m/<a[^<]*?href\=\"([\w\W]*?)\"\s*title\=\"[\w\W]*?\">\s*(\w[^<]+?)\s*</igs )
			{
				my $main_list_url = $1;
				my $menu_2=&clean($2);####under "Topshop Magazine" => Emma Farrow & Laura Weir,etc. (SubMenu1)
				
				if($menu_2=~m/^\s*A\-Z\s*$|^\s*View\s*All\s*$/is)
				{
					next;
				}
				unless($main_list_url=~m/^\s*http\:/is)
				{
					$main_list_url=$url.$main_list_url;
				}
				my $main_list_content = get_content($main_list_url);
				
				if ( $main_list_content =~ m/<span\s*class=\"filter_label[^<]*\">((?!View\s*All)(?![^<]*\s*Brand)(?!BRAND)?(?!SIZE)(?!price)(?![^>]*?Rating)(?![^>]*?Price)(?![^>]*?Accessories)(?![^<]*\sSize)(?!Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is) 
				{
					my $part_name = &clean($1);  
					my $list_part_content = &clean($2);
						
					while($list_part_content=~m/<a[^<]*?href\=\"\s*([^<]*?)\"[^>]*?>\s*([\w\W]*?)\s*<\/a>/igs) 
					{
						my $category_url = $1;
						my $category_name = &clean($2);
						$category_name =~s/(\([\w]*\))//;  
						
						next_page1:
						unless($category_url=~m/^\s*http\:/is)
						{
							$category_url=$url.$category_url;
						}
						my $product_list_content=get_content($category_url);
						
						&GetProduct($category_url,$category_name,$part_name,$menu_1,'',$menu_2);
						my $product_list_content=get_content($category_url);
						
						##Next Page
						if ( $product_list_content =~ m/<li\s*class=\"show_next\">\s*<a\s*href=\"([^<]*)\"\s*title=/is )
						{
							$category_url = $1;
							$category_url =~ s/amp;//g;
							goto next_page1;
						}
					}
				}
			}
		}
	}
}

sub GetProduct
{
	my $category_url1=shift;
	my $category_name1=shift;
	my $part_name1=shift;
	my $menu_11=shift;
	my $menu_2_cat1=shift;
	my $menu_21=shift;
						
	my $product_list_content1=get_content($category_url1);
	
	while($product_list_content1=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">[\w\W]*?<\/a>/igs) ##Collecting Products
	{
		my $product_url=$1;
		$product_url=~s/\?[\w\W]*$//igs;
		unless($product_url=~m/^\s*http\:/is)
		{
			$product_url=$url.$product_url;
		}
		$product_url =~ s/amp;//g;
		#### Making Unique Product URL
		if($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) 
		{
			$product_url='http://us.topshop.com/en/tsus/product/'.$1;
		}
		elsif($product_url=~m/^[^>]*\/([^>]*?)$/is)
		{
			$product_url='http://us.topshop.com/en/tsus/product/'.$1;
		}
		###Removing Duplicates using Hash
		my $product_object_key;
		if($totalHash{$product_url} ne '')
		{
			$product_object_key = $totalHash{$product_url};
		}
		else
		{
			$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
			$totalHash{$product_url}=$product_object_key;
		}
		
		$category_name1 =~s/(\([\w]*\))//;  
		###Insert Product values
		DBIL::SaveTag('Menu_1',$menu_11,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		if($menu_2_cat1)
		{
			DBIL::SaveTag($menu_2_cat1,$menu_21,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		else
		{
			DBIL::SaveTag('Menu_2',$menu_21,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		DBIL::SaveTag($part_name1,$category_name1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		$dbh->commit();
	}
}
$dbh->disconnect();
#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

##Function to Remove Special Characters and decode_entities
sub clean()
{
	my $text=shift;
	
	$text=~ s/amp;//g;
	$text=~s/Â//igs;
	
	return $text;
}

##Getting Page_Content 
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
	elsif($code =~m/50/is)
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto Home;
		}
	}
	else
	{
		if ( $rerun_count <= 1 )
		{
			$rerun_count++;
			goto Home;
		}
	}
}

