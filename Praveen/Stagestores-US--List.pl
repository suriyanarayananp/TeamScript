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
my $Retailer_Random_String='Sta';
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

my $home_url='http://www.stagestores.com';
my $source_page=&get_source_page($home_url);
$source_page=~s/\&amp\;/\&/igs;

my %validate;
while($source_page=~m/<a[^>]*?rel\=\"\d+\"\s*href\=\"([^>]*?)\;jsessionid\=[^>]*?\">\s*($ARGV[0])\s*<\/a>/igs){
	my $top_menu_url=$home_url.$1;
	my $top_menu=&DBIL::Trim($2);
	my $top_menu_page=&get_source_page($top_menu_url);
	
	while($top_menu_page=~m/<div\s*class\=\"lnk\">\s*<a\s*class\=\"labl\"\s*href\=\"([^>]*?N\=\d+\&[^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<span\s*class\=\"category\-price\">/igs){		
		my $menu_2_url=$home_url.$1.'&Nrpp=1000';
		my $menu_2=&DBIL::Trim($2);
		my $menu_2_page=&get_source_page($menu_2_url);
		
		if($menu_2_page=~m/>\s*category/is){
			my $no_filter_page=$menu_2_page;
			
			while($no_filter_page=~m/<h6>\s*((?!by\s*price|by\s*size|brand)[^>]*?)\s*<\/h6>\s*<ul\s*class\=\"leftNav\s*moreLessCategory\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/igs){
				my $filter=&DBIL::Trim($1);
				my $filter_block=$2;
				$filter=~s/by\s*color/Color/igs;
				
				while($filter_block=~m/<a\s*class\=\"labl\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){						
					my $filter_url=$home_url.$1.'&Nrpp=1000';
					my $filter_value=&DBIL::Trim($2);					
					my $filter_page=&get_source_page($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,'','',$filter,$filter_value);
				}
				while($filter_block=~m/<input\s*type\=\"checkbox\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs){
					my $filter_value=&DBIL::Trim($1);
					my $filter_url=$home_url.$2.'&Nrpp=1000';
					my $filter_page=&get_source_page($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,'','',$filter,$filter_value);
				}
			}
			while($menu_2_page=~m/<div\s*class\=\"lnk\">\s*<a\s*class\=\"labl\"\s*href\=\"([^>]*?N\=\d+\&[^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<span\s*class\=\"category\-price\">/igs){
				my $menu_3_url=$home_url.$1.'&Nrpp=1000';
				my $menu_3=&DBIL::Trim($2);
				my $menu_3_page=&get_source_page($menu_3_url);
				
				if($menu_3_page!~m/>\s*category/is){
					&Product_Insert($menu_3_page,$top_menu,$menu_2,$menu_3);
					
					while($menu_3_page=~m/<h6>\s*((?!by\s*price|by\s*size|brand)[^>]*?)\s*<\/h6>\s*<ul\s*class\=\"leftNav\s*moreLessCategory\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/igs){
						my $filter=&DBIL::Trim($1);
						my $filter_block=$2;
						$filter=~s/by\s*color/Color/igs;
						
						while($filter_block=~m/<a\s*class\=\"labl\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){
							my $filter_url=$home_url.$1.'&Nrpp=1000';
							my $filter_value=&DBIL::Trim($2);							
							my $filter_page=&get_source_page($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'',$filter,$filter_value);
						}
						while($filter_block=~m/<input\s*type\=\"checkbox\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs){
							my $filter_value=&DBIL::Trim($1);
							my $filter_url=$home_url.$2.'&Nrpp=1000';
							my $filter_page=&get_source_page($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'',$filter,$filter_value);							
						}
					}
				}
				else{
					while($menu_3_page=~m/<div\s*class\=\"lnk\">\s*<a\s*class\=\"labl\"\s*href\=\"([^>]*?N\=\d+\&[^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<span\s*class\=\"category\-price\">/igs){
						my $menu_4_url=$home_url.$1.'&Nrpp=1000';
						my $menu_4=&DBIL::Trim($2);
						my $menu_4_page=&get_source_page($menu_4_url);
						&Product_Insert($menu_4_page,$top_menu,$menu_2,$menu_3,$menu_4);

						while($menu_4_page=~m/<h6>\s*((?!by\s*price|by\s*size|brand)[^>]*?)\s*<\/h6>\s*<ul\s*class\=\"leftNav\s*moreLessCategory\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/igs){
							my $filter=&DBIL::Trim($1);
							my $filter_block=$2;
							$filter=~s/by\s*color/Color/igs;
							
							while($filter_block=~m/<a\s*class\=\"labl\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){
								my $filter_url=$home_url.$1.'&Nrpp=1000';
								my $filter_value=&DBIL::Trim($2);								
								my $filter_page=&get_source_page($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$filter,$filter_value);
							}
							while($filter_block=~m/<input\s*type\=\"checkbox\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs){
								my $filter_value=&DBIL::Trim($1);
								my $filter_url=$home_url.$2.'&Nrpp=1000';
								my $filter_page=&get_source_page($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$filter,$filter_value);
							}
						}
					}
				}
			}
		}
		else{			
			&Product_Insert($menu_2_page,$top_menu,$menu_2,'','','','');
			
			while($menu_2_page=~m/<h6>\s*((?!by\s*price|by\s*size|brand)[^>]*?)\s*<\/h6>\s*<ul\s*class\=\"leftNav\s*moreLessCategory\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/igs){
				my $filter=&DBIL::Trim($1);
				my $filter_block=$2;
				$filter=~s/by\s*color/Color/igs;
				
				while($filter_block=~m/<a\s*class\=\"labl\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs){
					my $filter_url=$home_url.$1.'&Nrpp=1000';
					my $filter_value=&DBIL::Trim($2);					
					my $filter_page=&get_source_page($filter_url);					
					&Product_Insert($filter_page,$top_menu,$menu_2,'','',$filter,$filter_value);					
				}
				while($filter_block=~m/<input\s*type\=\"checkbox\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs){
					my $filter_value=&DBIL::Trim($1);
					my $filter_url=$home_url.$2.'&Nrpp=1000';					
					my $filter_page=&get_source_page($filter_url);
					&Product_Insert($filter_page,$top_menu,$menu_2,'','',$filter,$filter_value);
				}
			}
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect;
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Stagestores-US--Detail.pl  &`);

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - BEGIN --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB	
	my $page=shift;
	my $top_menu=shift;
	my $menu_2=shift;
	my $menu_3=shift;
	my $menu_4=shift;	
	my $filter=shift;
	my $filter_value=shift;
	
	next_page:
	while($page=~m/<a\s*class\=\"prodTxtLink\"\s*href\=\"([^>]*?)(?:\;jsessionid\=[^>]*?)?\">/igs){
		my $product_url=$home_url.$1;
		$product_url=$1.'1'.$2 if($product_url=~m/([^>]*?product\/)[^>]*?(\/\d+\/)/is);
		my $product_object_key;
		if($validate{$product_url} eq ''){ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
		&DBIL::SaveTag('Menu_1',$top_menu,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($top_menu ne '');
		&DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_2 ne '');
		&DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_3 ne '');
		&DBIL::SaveTag('Menu_4',$menu_4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_4 ne '');		
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));
		$dbh->commit();
	}
	if($page=~m/<link\s*rel\=\"next\"\s*href\=\"([^>]*?)\">/is){
		my $next_page_url=$home_url.$1;
		my $next_page=&get_source_page($next_page_url);
		$page=$next_page;
		goto next_page;
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