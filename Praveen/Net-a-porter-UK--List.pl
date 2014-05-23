#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
########## MODULE INITIALIZATION ###########

use strict;
use LWP::UserAgent;
use HTML::Entities;
use HTTP::Cookies;
use DBI;
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm"; # USER DEFINED MODULE DBIL.PM

###########################################

######### VARIABLE INITIALIZATION ##########

my $robotname=$0;
$robotname=~s/\.pl//igs;
$robotname =$1 if($robotname=~m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name=~s/\-\-List\s*$//igs;
$retailer_name=lc($retailer_name);
my $Retailer_Random_String='Nuk';
my $pid=$$;
my $ip=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip=$1 if($ip=~m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid=$ip.'_'.$pid;

#############################################

######### PROXY INITIALIZATION ##############

my $country=$1 if($robotname=~m/\-([A-Z]{2})\-\-/is);
&DBIL::ProxyConfig($country);

#############################################

######### USER AGENT #######################

my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;

############################################

######### COOKIE FILE CREATION ############

my ($cookie_file,$retailer_file)=&DBIL::LogPath($robotname);
my $cookie=HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
$ua->cookie_jar($cookie);

############################################

######### ESTABLISHING DB CONNECTION #######

my $dbh=&DBIL::DbConnection();

############################################
 
my $select_query="select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id=&DBIL::Objectkey_Checking($select_query, $dbh, $robotname);

# ROBOT START PROCESS TIME STORED INTO RETAILER TABLE FOR RUNTIME MANIPULATION
&DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - BEGIN --> ########

my $home_url='http://www.net-a-porter.com'; # RETAILER HOME URL : NET-A-PORTER, UK
my $source_page=&get_source_page($home_url);

my %validate;
# EXTRACTS TOP MENUS : WHAT'S NEW, CLOTHING, BAGS, SHOES, ACCESSORIES, LINGERIE AND BEAUTY (EXCLUDED THE EDIT AND DESIGNER - SINCE WE SCRAPE DESIGNER FROM THE PRODUCT PAGE)
while($source_page=~m/<a\s*class\=\"top\-nav\-link[^>]*?\"\s*href\=\"[^>]*?\">\s*((?!\s*The\s*Edit|\s*Sale|\s*Designer)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/div>\s*<\/div>\s*<\/li>/igs){
	my $top_menu=&DBIL::Trim($1); # CLOTHING
	my $top_menu_block=$2;
	
	while($top_menu_block=~m/<div\s*class\=\"header\s*border\-bottom[^>]*?\">\s*([^>]*?)\s*<\/div>\s*([\w\W]*?\s*<\/div>)\s*<\/div>/igs){ # EXTRACTS MENU 2 AND MENU 2 BLOCK FROM TOP MENU BLOCK
		my $menu_2=$1; # SHOP BY
		my $menu_2_block=$2;
		next if($menu_2=~m/Designers|Brand/is); # MENU 2 : DESIGNER/BRAND SKIPPED
		
		while($menu_2_block=~m/<a[^>]*?href\=\"([^>]*?)\"\s*>\s*((?!The\s*Trend\s*Report|\s*All\s*)[^>]*?)\s*<\/a>/igs){ # EXTRACTS MENU 3 AND IT'S CORRESPONDING URL FROM MENU 2 BLOCK (EXCLUDING "THE TREND REPORT" AND "ALL" FROM MENU 2 BLOCK)
			my $menu_3_url=$home_url.$1;
			my $menu_3=&DBIL::Trim($2); # BLAZERS
			my $menu_3_page=&get_source_page($menu_3_url);
			next if($menu_3_url=~m/AZdesigner/is); # MENU 3 URL : AZ DESIGNER SKIPPED			
			
			if($menu_3_url=~m/level\d+Filter\=/is){ # NAVIGATION: CLOTHING -> SHOP BY -> BLAZERS
				while($menu_3_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"\?([^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
					my $filter_url=$menu_3_url.'&'.$1.'&npp=view_all';
					my $filter_name=&DBIL::Trim($2); # COLOUR
					my $filter_value=&DBIL::Trim($3); # WHITE
					#$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
					my $filter_page=&get_source_page($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: CLOTHING -> SHOP BY -> BLAZERS -> COLOUR -> WHITE)					
				}
			}
			elsif($menu_3_page=~m/<li\s*class\=\"open\s*selected\">/is){ # NAVIGATION: CLOTHING -> SHOP BY -> WEDDING
				while($menu_3_page=~m/<span>\s*<a[^>]*?href\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>\s*<\/span>\s*<ul>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> WEDDING -> THE BRIDE
					my $category=$1; # THE BRIDE
					my $category_block=$2;
					
					while($category_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> WEDDING -> THE BRIDE -> DRESSES & SEPARATES
						my $sub_category_url=$1;
						my $sub_category=$2; # DRESSES & SEPARATES
						my $sub_category_page=&get_source_page($sub_category_url);
						
						while($sub_category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
							my $filter_url=$sub_category_url.$1;
							my $filter_name=&DBIL::Trim($2); # COLOUR
							my $filter_value=&DBIL::Trim($3); # WHITE
							$filter_url=$1.$2 if($filter_url=~m/([^>]*?)\?SelItem\=\d+(?:\;\d+)?(\&colourFilter\=[^>]*?)\&[^>]*?$/is);							
							$filter_url=$1.$2 if($filter_url=~m/([^>]*?)\?SelItem\=\d+(?:\;\d+)?\&[^>]*?(\&colourFilter\=[^>]*?)$/is);
							$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
							my $filter_page=&get_source_page($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: CLOTHING -> SHOP BY -> WEDDING -> THE BRIDE -> DRESSES & SEPARATES -> COLOUR -> WHITE)							
						}
					}
				}
				while($menu_3_page=~m/<li\s*class\=\"\">\s*<a\s*id\=\"\d+\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> WEDDING -> MOTHER OF BRIDE
					my $category_url=$1;
					my $category=$2; # MOTHER OF BRIDE
					my $category_page=&get_source_page($category_url);
					
					while($category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
						my $filter_url=$category_url.$1;
						my $filter_name=&DBIL::Trim($2); # COLOUR
						my $filter_value=&DBIL::Trim($3); # WHITE
						$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
						my $filter_page=&get_source_page($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: CLOTHING -> SHOP BY -> WEDDING -> MOTHER OF BRIDE -> COLOUR -> WHITE)
					}
				}
			}
			else{
				if($menu_3_page!~m/<li\s*class\=\"\">\s*<a\s*href\=\"[^\"]*?\"\s*data\-filter\=\"[^\"]*?\">/is){
					if($menu_3_page=~m/<li\s*class\=\"has\-children\s*selected\">\s*<a[^>]*?href\=\"([^>]*?)\">\s*((?!All)[^<]*?)\s*<\/a>/is){ # ENTRY WHEN SUB CATEGORY IS SELECTED
						while($menu_3_page=~m/<li\s*class\=\"has\-children\s*selected\">\s*<a[^>]*?href\=\"([^>]*?)\">\s*((?!All)[^<]*?)\s*<\/a>/igs){ # NAVIGATION: LINGERIE -> SHOP BY -> BRAS -> BRAS
							my $category_url=$home_url.$1;
							my $category=&DBIL::Trim($2); # ACTIVEWEAR
							my $category_page=&get_source_page($category_url);							
							
							if($category_page=~m/<li\s*class\=\"\">\s*<a\s*href\=\"[^\"]*?\"\s*data\-filter\=\"[^\"]*?\">/is){
								while($category_page=~m/<li\s*class\=\"\">\s*<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs){ # NAVIGATION: LINGERIE -> SHOP BY -> BRAS -> BRAS -> DD PLUS BRA
									my $sub_category_url=$home_url.$1;
									my $sub_category=&DBIL::Trim($2); # DD PLUS BRA
									my $sub_category_page=&get_source_page($sub_category_url);
									
									while($sub_category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
										my $filter_url=$sub_category_url.$1;
										my $filter_name=&DBIL::Trim($2); # COLOUR
										my $filter_value=&DBIL::Trim($3); # WHITE
										$filter_url=~s/^([^>]*?)\?((colour)Filter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;									
										$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
										my $filter_page=&get_source_page($filter_url);
										&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: LINGERIE -> SHOP BY -> BRAS -> BRAS -> DD PLUS BRA -> COLOUR -> WHITE)
									}
								}
							}
							else{ # NAVIGATION: WHAT'S NEW -> SHOP BY -> THIS WEEK -> CLOTHING
								while($category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
									my $filter_url=$category_url.$1;
									my $filter_name=&DBIL::Trim($2); # COLOUR
									my $filter_value=&DBIL::Trim($3); # WHITE
									$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
									my $filter_page=&get_source_page($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WHAT'S NEW -> SHOP BY -> THIS WEEK -> CLOTHING -> COLOUR -> WHITE)
								}
							}
						}
					}
					else
					{
						while($menu_3_page=~m/<a[^>]*?href\=\"(\/Shop[^\"]*?)\">\s*((?!All)[^<]*?)\s*<\/a>\s*<\/li>/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> ACTIVEWEAR -> ACTIVEWEAR
							my $category_url=$home_url.$1;
							my $category=&DBIL::Trim($2); # ACTIVEWEAR
							my $category_page=&get_source_page($category_url);							
							
							if($category_page=~m/<li\s*class\=\"\">\s*<a\s*href\=\"[^\"]*?\"\s*data\-filter\=\"[^\"]*?\">/is){
								while($category_page=~m/<li\s*class\=\"\">\s*<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> ACTIVEWEAR -> ACTIVEWEAR -> TOPS
									my $sub_category_url=$home_url.$1;
									my $sub_category=&DBIL::Trim($2); # TOPS
									my $sub_category_page=&get_source_page($sub_category_url);
									
									while($sub_category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
										my $filter_url=$sub_category_url.$1;
										my $filter_name=&DBIL::Trim($2); # COLOUR
										my $filter_value=&DBIL::Trim($3); # WHITE
										$filter_url=~s/^([^>]*?)\?((colour)Filter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;									
										$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
										my $filter_page=&get_source_page($filter_url);
										&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,$sub_category,$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: CLOTHING -> SHOP BY -> ACTIVEWEAR -> ACTIVEWEAR -> TOPS -> COLOUR -> WHITE)
									}
								}
							}
							else{ # NAVIGATION: WHAT'S NEW -> SHOP BY -> THIS WEEK -> CLOTHING
								while($category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
									my $filter_url=$category_url.$1;
									my $filter_name=&DBIL::Trim($2); # COLOUR
									my $filter_value=&DBIL::Trim($3); # WHITE
									$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
									my $filter_page=&get_source_page($filter_url);
									&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$category,'',$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WHAT'S NEW -> SHOP BY -> THIS WEEK -> CLOTHING -> COLOUR -> WHITE)
								}
							}
						}
					}
				}
				else{
					while($menu_3_page=~m/<li\s*class\=\"\">\s*<a\s*href\=\"([^\"]*?)\"\s*data\-filter\=\"([^\"]*?)\">/igs){ # NAVIGATION: CLOTHING -> SHOP BY -> SHORTS -> DENIM
						my $sub_category_url=$home_url.$1;
						my $sub_category=&DBIL::Trim($2); # DENIM
						my $sub_category_page=&get_source_page($sub_category_url);
						
						while($sub_category_page=~m/<a\s*class\=\"filter_name\"\s*href\=\"(\?[^>]*?(colour)Filter\=[^>]*?)\"\s*title\=\"[^>]*?\">\s*<span>\s*([^>]*?)\s*<\/span>/igs){
							my $filter_url=$sub_category_url.$1;
							my $filter_name=&DBIL::Trim($2); # COLOUR
							my $filter_value=&DBIL::Trim($3); # BLUE
							$filter_url=~s/^([^>]*?)\?((colour)Filter\=[^>]*?)\&[^>]*?$/$1\&$2/igs;							
							$filter_url=~s/\&npp\=60/\&npp\=view_all/igs;
							my $filter_page=&get_source_page($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'',$sub_category,$filter_name,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: CLOTHING -> SHOP BY -> SHORTS -> DENIM -> COLOUR -> BLUE)
						}
					}
				}
			}
			undef $menu_3_page;
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect();

# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Net-a-porter-UK--Detail.pl  &`);

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - END --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB
	my $page=shift;
	my $top_menu=shift;
	my $menu_2=shift;
	my $menu_3=shift;
	my $category=shift;
	my $sub_category=shift;
	my $filter=shift;
	my $filter_value=shift;
	
	while($page=~m/<div\s*class\=\"description\"><a\s*href\=\"([^<]*?(\d+))[^>]*?\"\s*title\=\"[^\"]*?\">/igs){
		my $product_url=$home_url.$1;
		my $product_id=$1;
		my $product_object_key;		
		if($validate{$product_id} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_id}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_id}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
		&DBIL::SaveTag('Menu_1',$top_menu,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($top_menu ne '');
		&DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_2 ne '');	
		&DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_3 ne '');
		&DBIL::SaveTag($category,$sub_category,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($category ne '') && ($sub_category ne ''));
		&DBIL::SaveTag('category',$category,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($category ne '') && ($sub_category eq ''));
		&DBIL::SaveTag('sub category',$sub_category,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($category eq '') && ($sub_category ne ''));
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));
		$dbh->commit();
	}
}

sub FC(){ # REMOVES FOREIGN CHARACTERS
	my $text=shift;
	$text=decode_entities($text);
	return $text;
}

sub get_source_page(){ # FETCH SOURCE PAGE CONTENT FOR THE GIVEN URL
	my $url=shift;
	my $rerun_count=0;
	$url=~s/^\s+|\s+$//g;
	Repeat:
	my $request=HTTP::Request->new(GET=>$url);
	$request->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $request->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $response=$ua->request($request);
	$cookie->extract_cookies($response);
	$cookie->save;
	$cookie->add_cookie_header($request);
	my $code=$response->code;
	
	######## WRITING LOG INTO /var/tmp/Retailer/$retailer_file #######
	
	open JJ,">>$retailer_file";
	print JJ "$url->$code\n";
	close JJ;
	
	##################################################################
	
	my $content;
	if($code=~m/20/is){
		$content=$response->content;
		return $content;
	}
	elsif($code=~m/30/is){
		my $loc=$response->header('location');                
        $loc=decode_entities($loc);    
        my $loc_url=url($loc,$url)->abs;        
        $url=$loc_url;
        goto Repeat;
	}
	elsif($code=~m/40/is){
		if($rerun_count <= 3){
			$rerun_count++;			
			goto Repeat;
		}
		return 1;
	}
	else{
		if($rerun_count <= 3){
			$rerun_count++;			
			goto Repeat;
		}
		return 1;
	}
}
