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
my $Retailer_Random_String='Uni';
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

my $home_url='http://www.uniqlo.com/uk'; # RETAILER HOME URL : UNIQLO, UK
my $source_page=&get_source_page($home_url);

my %validate;
# EXTRACTS TOP MENUS : WOMEN AND MEN
while($source_page=~m/<\!\-\-\s*start\s*(?:wo)?men\s*\/\/\s*\-\->\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*end\s*((?:wo)?men)\s*\-\->/igs){
	my $top_menu_block=$1;
	my $top_menu=&DBIL::Trim($2); # WOMEN
	
	while($top_menu_block=~m/<a\s*href\=\"\#\">\s*<img\s*src\=\"[^>]*?\"\s*alt\=\"([^>]*?)\"[^>]*?>\s*<\/a>\s*<ul\s*class\=\"sub\s*hidden\">\s*([\w\W]*?)\s*<\/ul>\s*<\/li>/igs){ # EXTRACTS MENU 2 BLOCK FROM TOP MENU BLOCK
		my $menu_2=&DBIL::Trim($1); # TOPS
		my $menu_2_block=$2;
		
		while($menu_2_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*((?!UNIQLO\s*app)[^>]*?)\s*<\/a>\s*<\/li>/igs){ # EXTRACTS MENU 3 AND URL FROM MENU 2 BLOCK (SKIP MENU 3 -> UNIQLO APP)
			my $menu_3_url=$1;
			my $menu_3=&DBIL::Trim($2); # POLO SHIRTS
			my $menu_3_page=&get_source_page($menu_3_url);
						
			if($menu_3_page=~m/<a\s*href\=\"\#[^>]*?\">\s*<img\s*alt\=\"[^>]*?\"\s*src\=\"[^>]*?\/[\w\-]*?\.jpg\">/is){ # EXTRACTS THE MENU 3 PAGE WHICH CONTAINS "SELECT BY STYLE" FILTER (NAVIGATION: WOMEN -> TOPS -> DRESSES & TUNICS -> SELECT BY STYLE -> DRESSES)
			
				while($menu_3_page=~m/<a\s*href\=\"\#([^>]*?)\">\s*<img\s*alt\=\"[^>]*?\"\s*src\=\"[^>]*?\/([\w\-]*?)\.jpg\">/igs){ # EXTRACTS STYLE CODE AND STYLE VALUE
					my $style_code=$1;
					my $style=&DBIL::Trim($2); # DRESSES
					
					######### CLEANSING STYLE DATA ########
					
					$style=~s/^[^>]*?type(_[^>]*?)$/$1/igs;
					$style=~s/_W_//igs;
					$style=~s/\-W_//igs;
					$style=~s/_M_//igs;
					$style=~s/_/ /igs;
					$style=~s/^w\s//igs;
					$style=~s/^m\s//igs;					
					$style=~s/socks\-//igs;
					$style=~s/standard/regular/igs;					
					$style=lc($style);
					
					
					#######################################
					
					if($menu_3_page=~m/<div\s*class\=\"contProd\">\s*<h3\s*id\=\"$style_code\"\s*class\=\"[^>]*?\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*(?:end\s*)?alias\s*\-\->/is){ # EXTRACTS STYLE BLOCK BY PASSING STYLE CODE IN REGEX
						my $style_block=$1;
						&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Select by style',$style); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> TOPS -> DRESSES & TUNICS -> SELECT BY STYLE -> DRESSES)						
					}
				}
			}
			elsif($menu_3_page=~m/<a\s*href\=\"\#[^>]*?\"\s*title\=\"[^>]*?\">\s*[^>]*?\s*<\/a>/is){ # EXTRACTS THE MENU 3 PAGE WHICH CONTAINS CATEGORY TYPE (NAVIGATION: WOMEN -> ACCESSORIES & UNDERWEAR -> ACCESSORIES -> CATEGORY -> HATS)
			
				while($menu_3_page=~m/<a\s*href\=\"\#[^>]*?\"\s*title\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){ # EXTRACTS STYLE CODE AND STYLE VALUE
					my $style_code=$1;
					my $style=&DBIL::Trim($2);	# HATS				
					
					if($menu_3_page=~m/<div\s*class\=\"unit\s*title\"\s*id\=\"$style_code\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/alias\s*\-\->/is){ # EXTRACTS STYLE BLOCK BY PASSING STYLE CODE IN REGEX
						my $style_block=$1;
						&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Category',$style); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> ACCESSORIES & UNDERWEAR -> ACCESSORIES -> CATEGORY -> HATS)						
					}
				}
			}
			elsif($menu_3_page=~m/<\!\-\-\s*[^>]*?\s*\-\->\s*<div\s*class\=\"contProd\">/is){ # EXTRACTS THE MENU 3 PAGE WHICH CONTAINS CATEGORY TYPE (NAVIGATION: WOMEN -> COLLECTION -> ULTRA LIGHT DOWN -> CATEGORY -> ULD FOR WOMEN)
			
				while($menu_3_page=~m/<\!\-\-\s*([^>]*?)\s*\-\->\s*<div\s*class\=\"contProd\">\s*([\w\W]*?)\s*<\!\-\-\s*\/\/\s*end[^>]*?\s*\-\->/igs){ # EXTRACTS STYLE VALUE AND STYLE BLOCK
					my $style=$1; # ULD FOR WOMEN
					my $style_block=$2;
					
					################## NAMING CONVERSION ###################
					
					$style='Collaboration' if($style=~m/^\/\/\s*end/is);
					$style='Accessories' if($style=~m/^\s*Goods/is);
					$style='ULD For Women' if($style=~m/Women\'s\s*ULD/is);
					$style='ULD For Men' if($style=~m/Men\'s\s*ULD/is);
					
					#########################################################
					
					&Product_Insert($style_block,$top_menu,$menu_2,$menu_3,'Category',$style); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2, MENU_3, FILTER AND FILTER VALUE TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> COLLECTION -> ULTRA LIGHT DOWN -> CATEGORY -> ULD FOR WOMEN)					
				}
			}
			else{ # EXTRACTS THE MENU 3 PAGE WHETHER NO CATEGORIES ARE AVAILABLE (NAVIGATION: WOMEN -> OUTERWEAR -> COATS & BLAZERS)
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2 AND MENU_3 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> OUTERWEAR -> COATS & BLAZERS)				
			}
		}
	}	
	
	# EXTRACTS TOP MENU : NEW IN, LIMITED OFFER AND SALE
	while($top_menu_block=~m/<li>\s*<a[^>]*?href\=\"([^>]*?)\">\s*<img[^>]*?alt\=\"([^>]*?)\"[^>]*?>\s*<\/a>\s*<\/li>/igs){
		my $menu_2_url=$1;
		my $menu_2=&DBIL::Trim($2); # NEW IN
		my $menu_2_page=&get_source_page($menu_2_url);
		
		while($menu_2_page=~m/<ul\s*id\=\"navSpecialCategory\">\s*([\w\W]*?)\s*<\/ul>/igs){ # GROUPS ALL MENU 3 INTO A BLOCK
			my $menu_2_block=$1;
			
			while($menu_2_block=~m/<a[^>]*?href\=\"([^>]*?\/((?!ut)[\w]*?))\">/igs){ # SEGMENTS EACH MENU 3/URL
				my $menu_3_url=$1;
				my $menu_3=$2; # OUTERWEAR
				$menu_3=~s/and/ \& /igs;
				my $menu_3_page=&get_source_page($menu_3_url);
				&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3); # TRANSPORTS PRODUCT_URL, TOP_MENU, MENU_2 AND MENU_3 TO PRODUCT_INSERT MODULE FOR INSERTING TAGS INTO DB (NAVIGATION: WOMEN -> NEW IN -> OUTERWEAR)				
			}
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect();
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Uniqlo-UK--Detail.pl  &`);

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

	while($page=~m/<dt\s*class\=\"name\">\s*<a\s*href\=[\'|\"]([^>]*?)[\"|\']\s*[^>]*?>\s*[^>]*?\s*<\/a>\s*<\/dt>/igs){
		my $product_url=$1;
		my $product_object_key;
		if($validate{$product_url} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL		
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