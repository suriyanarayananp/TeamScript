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
my $Retailer_Random_String='Sim';
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

my $home_url='http://www.simplybe.co.uk';
my $source_page=&get_source_page($home_url);

my %validate;
# EXTRACTS TOP MENUS : FASHION, SWIMWEAR, LINGERIE, ACCESSORIES, SHOES, SPORTS AND OFFERS
while($source_page=~m/<a\s*id\=\"topNav_[^>]*?\"\s*name\=\"topNav_[^>]*?\"\s*href\=\"([^>]*?)\">\s*($ARGV[0])\s*<\/a>/igs){
	my $top_menu_url=$home_url.$1.'&Rpp=48';
	my $top_menu=&DBIL::Trim($2); # FASHION
	$top_menu=~s/offers/latest offers/igs;
	my $top_menu_page=&get_source_page($top_menu_url);

	if($top_menu_page=~m/<p\s*class\=\"refinementHeader\">\s*<span\s*class\=\"active\">\s*$top_menu\s*<\/span>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>/is){ 
		my $top_menu_block=$1;
		$top_menu=~s/latest offers/offers/igs;

		while($top_menu_block=~m/<a\s*id\=\'stid_addLeftNavFilter\-[^>]*?\'\s*name\=\'[^>]*?\'\s*href\=\'([^>]*?)\'\s*>\s*([^>]*?)\s*<span\s*class\=\"count\">\s*\([\d\,]*?\)\s*<\/span>\s*<\/a>/igs){ # NAVIGATION: FASHION
			my $menu_2_url=$home_url.$1;
			my $menu_2=&DBIL::Trim($2); # COATS & JACKETS
			my $menu_2_page=&get_source_page($menu_2_url);
			&Product_Insert($menu_2_page,$top_menu,$menu_2); # NAVIGATION: FASHION -> COATS & JACKETS

			while($menu_2_page=~m/<p\s*class\=\"refinementHeader\">\s*<span\s*class\=\"active\">\s*((?!size|price|[^>]*?size|brand)[^>]*?)\s*<\/span>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>/igs){ # NAVIGATION: FASHION -> COATS & JACKETS
				my $filter_name=&DBIL::Trim($1); # COLOUR
				my $filter_block=$2;
				
				while($filter_block=~m/<a\s*id\=\'stid_addLeftNavFilter\-[\w\-]*?\s*\'[^>]*?\s*href\=\'([^>]*?)\'\s*>\s*([^>]*?)\s*<span\s*class\=\"count\">\s*\([\d\,]*?\)\s*<\/span>\s*<\/a>/igs){
					my $filter_url=$home_url.$1;
					my $filter_value=&DBIL::Trim($2); # BLACK					
					my $filter_page=&get_source_page($filter_url);					
					&Product_Insert($filter_page,$top_menu,$menu_2,$filter_name,$filter_value); # NAVIGATION: FASHION -> COATS & JACKETS -> COLOUR -> BLACK
				}
			}
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect();
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Simplybe-UK--Detail.pl  &`);

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - END --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB
	my $filter_page=shift;
	my $top_menu=shift;
	my $menu_2=shift;	
	my $filter=shift;
	my $filter_value=shift;	
	
	next_page:
	while($filter_page=~m/<meta\s*itemprop\=\"sku\"\s*content=\"[^>]*?\">\s*\s*<div[^>]*?>\s*<a[^>]*?href=\'([^>]*?)\'[^>]*?>/igs){
		my $product_url=$home_url.$1;		
		my $product_object_key;
		if($validate{$product_url} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL		
		&DBIL::SaveTag('Menu_1',$top_menu,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($top_menu ne '');
		&DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_2 ne '');	
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));		
		$dbh->commit();
	}
	if($filter_page=~m/<a[^<]*?href\=\'([^<]*?)\'>\s*Next\s*<\/a>[\w\W]*?<\/html>/is){ # NEXT PAGE ENTRY
		my $next_url=$home_url.$1;
		decode_entities($next_url);
		$filter_page=&get_source_page($next_url);
		goto next_page;
	}
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