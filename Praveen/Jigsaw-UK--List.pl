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
my $Retailer_Random_String='Jig';
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

my $home_url='http://www.jigsaw-online.com'; # RETAILER HOME URL : JIGSAW, UK
my $source_page=&get_source_page($home_url);

$source_page=~s/(<li\s*class\=\"level_1[^>]*?\"\s*id\=\"wc_(?!explore)[^>]*?\">)/\^\$\^ $1/igs;
$source_page=~s/(<li\s*id\=\"stores\"\s*class\=\"level_1\">)/\^\$\^ $1/igs;

my %validate;
# EXTRACTS TOP MENUS EXCLUDING "EXPLORE" AND "STORES"
while($source_page=~m/<li\s*class\=\"level_1[\w\W]*?id\=\"[\w\W]*?\">\s*<a\s*class\=\"level_1\"[\w\W]*?>((?!Explore)[^>]*?)<\/a>([\w\W]*?)\^\$\^/igs){
	my $top_menu=&DBIL::Trim($1); # WOMEN
	my $top_menu_block=$2;

	if($top_menu=~m/New\s*In|Homeware/is){ # ENTRY FOR "NEW IN" AND "HOMEWARE" MENUS

		while($top_menu_block=~m/class\=\"level_2\"\s*href\=\"([^>]*?)\"[\w\W]*?>([^>]*?)<\/a>/igs){ # EXTRACTS MENU 2/URL FROM TOP MENU BLOCK
			my $menu_2_url=$1;
			my $menu_2=&DBIL::Trim($2); # NEW IN WOMEN'S
			my $menu_2_page=&get_source_page($menu_2_url);
			&Product_Insert($menu_2_page,$top_menu,$menu_2); # TRANSPORTS PRODUCT_URL, TOP_MENU AND MENU_2 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: NEW IN -> NEW IN WOMEN'S)
			
			while($menu_2_page=~m/<p\s*class\=\"filter_title\">\s*((?!\s*Size|\s*Price)[^>]*?)\s*<\/p>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs){ # EXTRACTS FILTER BLOCK (EXCLUDING SIZE AND PRICE)
				my $filter=&DBIL::Trim($1); # COLOUR
				my $filter_block=$2;

				while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){ # EXTRACTS FILTER VALUE AND IT'S CORRESPONDING URL
					my $filter_url=$1;
					my $filter_value=&DBIL::Trim($2); # GREEN
					my $filter_page=&get_source_page($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,'',$filter,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU AND MENU_2 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: NEW IN -> NEW IN WOMEN'S -> COLOUR -> WHITE)					
				}
			}
		}				
	}
	else{ # ENTRY FOR "WOMEN", "MEN", "JUNIOR" AND "SALE" MENUS
		while($top_menu_block=~m/<span\s*class\=\"level_2\">\s*([^>]*?)\s*<\/span>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs){ # EXTRACTS MENU 2 AND MENU 2 BLOCK FROM TOP MENU BLOCK
			my $menu_2=&DBIL::Trim($1); # CLOTHING
			my $menu_2_block=$2;

			while($menu_2_block=~m/class="level_3"\s*href="([^>]*?)\"[\w\W]*?>([^>]*?)<\/a>/igs){ # EXTRACTS MENU 3/URL FROM MENU 2 BLOCK
				my $menu_3_url=$1;
				my $menu_3=&DBIL::Trim($2); #DRESSES
				my $menu_3_page=&get_source_page($menu_3_url);
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # TRANSPORTS PRODUCT_URL, TOP_MENU AND MENU_2 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> CLOTHING -> DRESSES)

				while($menu_3_page=~m/<p\s*class\=\"filter_title\">\s*((?!\s*Size|\s*Price)[^>]*?)\s*<\/p>\s*([\w\W]*?)\s*<\/li>\s*<\/ul>/igs){ # EXTRACTS FILTER BLOCK (EXCLUDING SIZE AND PRICE)
					my $filter=&DBIL::Trim($1); # COLOUR
					my $filter_block=$2;

					while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){ # EXTRACTS FILTER VALUE AND IT'S CORRESPONDING URL
						my $filter_url=$1;
						my $filter_value=&DBIL::Trim($2); # GREEN
						my $filter_page=&get_source_page($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$filter,$filter_value); # TRANSPORTS PRODUCT_URL, TOP_MENU AND MENU_2 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> CLOTHING -> DRESSES -> COLOUR -> GREEN)						
					}
				}
			}		
		}
	}
}
$dbh->commit();
$dbh->disconnect();
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Jigsaw-UK--Detail.pl  &`);

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - END --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB
	my $page=shift;
	my $top_menu=shift;
	my $menu_2=shift;
	my $menu_3=shift;
	my $filter=shift;
	my $filter_value=shift;

	# EXTRACTING PRODUCT URL
	while($page=~m/href\=\"([^>]*?)"\s*class\=\"product_link\"><img/igs){
		my $product_url=$home_url.$1;
		my $unique=$1 if($product_url=~m/\/products\/([^>]*?)\-\d+/is);
		my $product_object_key;
		if($validate{$unique} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$unique}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$unique}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL		
		&DBIL::SaveTag('Menu_1',$top_menu,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($top_menu ne '');
		&DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_2 ne '');	
		&DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_3 ne '');
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));
		$dbh->commit();
	}
}

sub FC(){ # REMOVES FOREIGN CHARACTERS
	my $text=shift;
	$text=decode_entities($text);
	return $text;
}

sub get_source_page(){ # FETCH SOURCE PAGE FOR THE GIVEN URL
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