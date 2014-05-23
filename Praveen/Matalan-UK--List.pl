#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
########## MODULE INITIALIZATION ###########

use strict;
use LWP::UserAgent;
use HTML::Entities;
use HTTP::Cookies;
use DBI;
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm"; # USER DEFINED MODULE DBIL.PM

###########################################

######### VARIABLE INITIALIZATION ##########

my $robotname=$0;
$robotname=~s/\.pl//igs;
$robotname =$1 if($robotname=~m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name=~s/\-\-List\s*$//igs;
$retailer_name=lc($retailer_name);
my $Retailer_Random_String='Mat';
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
&DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - BEGIN --> ########

my $home_url='http://www.matalan.co.uk'; # RETAILER HOME URL : MATALAN, UK
my $source_page=&get_source_page($home_url);

my %validate;
while($source_page=~m/dept\-((?!home\b|style|in|reward|sport)[^>]*?)\">\s*<a\s*class\=\"\s*link\"\s*href\=\"([^>]*?)\"/igs){ # EXTRACTING TOP MENU/URL -> WOMENS, MENS, BOYS, GIRLS, SHOES,HOMEWARE AND SALE
	my $top_menu=FC($1); # WOMEN
	my $top_menu_url=$home_url.$2;	
	my $top_menu_page=&get_source_page($top_menu_url);
	
	if($top_menu_page=~m/<nav\s*id\=\"section\-nav\">\s*([\w\W]*?)\s*<\/nav>/is){ # LHM FULL BLOCK
		my $menu_block=$1;
		undef $top_menu_page;
		
		# LHM -> EXTRACTING SEPARATE BLOCKS FOR EACH MENU_2
		while($menu_block=~m/<h4>\s*<span\s*class\=\"\s*link\">\s*([^>]*?)\s*<\/span>\s*<\/h4>\s*([\w\W]*?)\s*<\/ul>/igs){
			my $menu_2=FC($1); # Women's Highlights
			my $menu_2_block=$2;
			
			# LHM -> EXTRACTING MENU_3/URL FROM EACH MENU_2 BLOCK
			while($menu_2_block=~m/<a\s*class\=\"\s*link\"\s*href\=\"([^>]*?)\"\s*title\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>/igs){
				my $menu_3_url=$home_url.$1;
				my $menu_3=FC($2); # NEW ARRIVALS				
				my $part_filter_url=$menu_3_url;				
				$menu_3_url=$menu_3_url.'?size=120&page=1'; # DISPLAYS 120(MAXIMUM) PRODUCTS PER PAGE				
				my $menu_3_page=&get_source_page($menu_3_url);
				&Product_Insert($menu_3_url,$menu_3_page,$top_menu,$menu_2,$menu_3); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2 AND MENU_3 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION EXAMPLE : Menu_1(WOMEN) -> Menu_2(WOMEN'S HIGHLIGHTS) -> Menu_3(NEW ARRIVALS))
				# EXTRACTING PRODUCT URL
				
				# FILTER BLOCK - EXCLUDING FILTERS : SIZE, PRICE AND RATING
				while($menu_3_page=~m/<h5>\s*<span[^>]*?>\s*<\/span>\s*((?!\s*size|\s*price|\s*rating)[^>]*?)\s*<\/h5>\s*([\w\W]*?)\s*<\/ul>/igs){
					my $filter=FC($1); # Color
					my $filter_block=$2;
					
					# EXTRACTING FILTER VALUES FROM EACH FILTER BLOCK EXCLUDING COLOUR
					while($filter_block=~m/<input\s*type\s*[^>]*?name=\"([^>]*>?)\"\s*value\=\"([^>]*>?)\"/igs){
						my $part_name=$1;
						my $filter_value=FC($2); # WHITE						
						my $filter_url=$part_filter_url.'?'.$part_name.'='.$filter_value.'&size=120&page=1'; # CONSTRUCTING FILTER URL TO EXTRACT PRODUCT URLS FROM DISPLAY PAGE (120 URL PER PAGE)						
						my $filter_page=&get_source_page($filter_url);
						&Product_Insert($filter_url,$filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER_NAME AND FILTER_VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION EXAMPLE : Menu_1(WOMEN) -> Menu_2(WOMEN'S HIGHLIGHTS) -> Menu_3(NEW ARRIVALS) -> (COLOR) -> (WHITE))						
						undef $filter_page;
					}
					
					# EXTRACTING FILTER VALUES FOR COLOUR BLOCK
					while($filter_block=~m/<input\s*type\=\"checkbox\"\s*value\=\"([^>]*?)\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*\/>/igs){
						my $filter_value=FC($1); # WHITE
						my $part_name=$2;
						my $filter_url=$part_filter_url.'?'.$part_name.'='.$filter_value.'&size=120&page=1'; # CONSTRUCTING FILTER URL TO EXTRACT PRODUCT URLS FROM DISPLAY PAGE (120 URL PER PAGE)						
						my $filter_page=&get_source_page($filter_url);
						&Product_Insert($filter_url,$filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER_NAME AND FILTER_VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION EXAMPLE : Menu_1(WOMEN) -> Menu_2(WOMEN'S HIGHLIGHTS) -> Menu_3(NEW ARRIVALS) -> (COLOR) -> (WHITE))						
						undef $filter_page;
					}
				}
				undef $menu_3_page;
			}
			undef $menu_2_block;
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect;
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Matalan-UK--Detail.pl  &`);

#################### For Dashboard #######################################
&DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - BEGIN --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB
	my $url=shift;
	my $page=shift;
	my $top_menu=shift;
	my $menu_2=shift;
	my $menu_3=shift;
	my $filter=shift;
	my $filter_value=shift;
	
	##### DATA CLEANSING #####
	$top_menu=~s/Â//igs;
	$menu_2=~s/Â//igs;
	$menu_3=~s/Â//igs;
	$filter=~s/Â//igs;
	$filter_value=~s/Â//igs;
	##########################
	my $page_count=1;
	nextPage:
	while($page=~m/<h3>\s*<a\s*class\=\"link\"\s*href\=\"([^>]*?)"[^>]*?>\s*[^>]*?\s*<\/a>/igs){
		my $product_url=$1;
		$product_url=$home_url.$1 if($product_url=~m/(\/s\d+)\//is); # CONSTRUCTING UNIQLE PRODUCT URL
		my $product_object_key;
		if($validate{$product_url} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
		$filter_value=~s/_/ /igs;		
		&DBIL::SaveTag('Menu_1',$top_menu,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($top_menu ne '');
		&DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($menu_2!~m/sale/is) && ($menu_2 ne ''));
		&DBIL::SaveTag('Menu_2',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_2=~m/sale/is);
		&DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($menu_3!~m/\ssale/is) && ($menu_3 ne ''));
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));
		$dbh->commit();
	}
	# MATCHES NEXT PAGE IN DISPLAY PAGE AND RE-LOOP TO NEXTPAGE WITH CONSTRUCTED MENU_3 URL
	if($page=~m/<li\s*class\=\"next\">/is){
		$page_count++;
		$url=$1.$page_count if($url=~m/([^>]*?\&page\=)/is);
		$page=&get_source_page($url);
		goto nextPage;
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
