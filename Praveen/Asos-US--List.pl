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
my $Retailer_Random_String='Aus';
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

my $home_url='http://us.asos.com/'; # RETAILER HOME URL : ASOS, US
my $source_page=&get_source_page($home_url);
$source_page=~s/(<dl\s*class\=\"section\">)/\^\$\^ $1/igs;

my %validate;
# TOP MENU EXTRACTION : WOMEN & MEN
while($source_page=~m/<li\s*class\=\"floor_\d+\s*\">\s*<a\s*class\=\"[^>]*?\"\s*href\=\"[^>]*?\">\s*<span>\s*($ARGV[0])\s*<\/span>\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/li>/igs){
	my $top_menu=&DBIL::Trim($1); # WOMEN
	my $top_menu_block=$2;
	
	while($top_menu_block=~m/<dt>\s*($ARGV[1])\s*<\/dt>\s*<dd>\s*<ul\s*class\=\"items\">\s*([\w\W]*?)\s*\^\$\^/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT
		my $menu_2=&DBIL::Trim($1); # SHOP BY PRODUCT
		my $menu_2_block=$2;
		
		while($menu_2_block=~m/<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> DRESSES
			my $menu_3_url=$1;
			my $menu_3=&DBIL::Trim($2); # DRESSES
			next if($menu_3=~m/Magazine|Premium\s*Brands/is);					
			$menu_3_url=$home_url.$menu_3_url unless($menu_3_url=~m/^http/is);
			$menu_3_url=~s/\&pgesize\=36/\&pgesize\=200/igs;			
			$menu_3_url=$menu_3_url.'&pgesize=200';
			my $menu_3_page=&get_source_page($menu_3_url);
			my $no_filter_page=$menu_3_page;
			
			if($menu_3!~m/\s*SALE\s*|\s*OUTLET\s*|Beauty|A\s*To\s*Z\s*Of\s*Brands/is){
				&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> DRESSES
				
				while($menu_3_page=~m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> DRESSES -> COLOUR
					my $filter_name=&DBIL::Trim($1);
					my $filter_block=$2;
					
					while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> DRESSES -> COLOUR -> WHITE
						my $filter_url=$1;
						my $filter_value=&DBIL::Trim($2);
						$filter_url=$home_url.$filter_url unless($filter_url=~m/^http/is);
						$filter_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
						$filter_url=$filter_url.'&pgesize=200';
						my $filter_page=&get_source_page($filter_url);
						&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,'','',$filter_name,$filter_value); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> DRESSES -> COLOUR -> WHITE
					}
				}
			}
			elsif($menu_3=~m/Beauty/is){ # ENTRY FOR MENU 3 : BEAUTY
                while($menu_3_page=~m/<h2\s*class\=\"[^>]*?\">\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/h2>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> BEAUTY -> FACE
                    my $menu_4_url=$1;
                    my $menu_4=$2; # FACE
                    $menu_4_url=~s/\&pgesize\=36/\&pgesize\=200/igs;           
                    $menu_4_url=$menu_4_url.'&pgesize=200';
                    my $menu_4_page=&get_source_page($menu_4_url);
                    my $no_filter_page=$menu_4_page;
					&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> BEAUTY -> FACE

                    while($menu_4_page=~m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> BEAUTY -> FACE -> FACE
                        my $filter_name=$1; # FACE
                        my $filter_block=$2;
						
                        while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> BEAUTY -> FACE -> FACE -> CLEANSING & TONING
                            my $filter_url=$1;
                            my $filter_value=$2; # CLEANSING & TONING
                            $filter_url=$home_url.$filter_url unless($filter_url=~m/^http/is);
                            $filter_url=~s/(\&pgesize\=)36/\&pgesize\=200/igs;
                            $filter_url=$filter_url.'&pgesize=200';
                            my $filter_page=&get_source_page($filter_url);
							&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,'',$filter_name,$filter_value); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> BEAUTY -> FACE -> FACE -> CLEANSING & TONING
                        }
                    }
                }
            }
			elsif($menu_3=~m/A\s*To\s*Z\s*Of\s*Brands/is){ # ENTRY FOR MENU 3 : A TO Z OF BRANDS
				while($menu_3_page=~m/<div\s*id\=\"letter_[^>]*?\"\s*class\=\"letter\">\s*<h2>\s*([^>]*?)\s*<\/h2>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS
					my $menu_3_block=$2;
					
					while($menu_3_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*(?:<strong>\s*)?([^>]*?)(?:\s*<\/strong>)?\s*<\/a>\s*<\/li>(?!\s*\-\-\>)/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS -> A QUESTION OF
						my $menu_4_url=$1;
						my $menu_4=$2; # A QUESTION OF
						$menu_4_url=~s/\&pgesize\=36/\&pgesize\=200/igs;			
						$menu_4_url=$menu_4_url.'&pgesize=200';
						my $menu_4_page=&get_source_page($menu_4_url);
						my $no_filter_page=$menu_4_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS -> A QUESTION OF

						while($menu_4_page=~m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"\#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS -> A QUESTION OF -> COLOUR
							my $filter_name=$1;
							my $filter_block=$2;
							
							while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS -> A QUESTION OF -> COLOUR -> WHITE
								my $filter_url=$1;
								my $filter_value=$2;
								$filter_url=$home_url.$filter_url unless($filter_url=~m/^http/is);
								$filter_url=~s/(\&pgesize\=)36/\&pgesize\=200/igs;
								$filter_url=$filter_url.'&pgesize=200';
								my $filter_page=&get_source_page($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,'',$filter_name,$filter_value); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> A TO Z OF BRANDS -> A QUESTION OF -> COLOUR -> WHITE
							}
						}						
					}
				}
			}
			else{
				while($menu_3_page=~m/<h2\s*class\=\"title\">\s*([^>]*?)\s*<\/h2>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES
					my $menu_4=&DBIL::Trim($1); # SHOP BY CATEGORIES
					my $menu_4_block=$2;
					
					while($menu_4_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> DRESSES(ALL)
						my $menu_5_url=$1;
						my $menu_5=&DBIL::Trim($2); # DRESSES(ALL)
						next if($menu_5=~m/Magazine|Premium\s*Brands|A\s*To\s*Z\s*Of\s*Brands/is);
						$menu_5_url=$home_url.$menu_5_url unless($menu_5_url=~m/^http/is);
						$menu_5_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
						$menu_5_url=$menu_5_url.'&pgesize=200';
						my $menu_5_page=&get_source_page($menu_5_url);
						my $no_filter_page=$menu_5_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> DRESSES(ALL)
						
						while($menu_5_page=~m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> DRESSES(ALL) -> COLOUR
							my $filter_name=&DBIL::Trim($1);
							my $filter_block=$2;
							
							while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> DRESSES(ALL) -> COLOUR -> WHITE
								my $filter_url=$1;
								my $filter_value=&DBIL::Trim($2);
								$filter_url=$home_url.$filter_url unless($filter_url=~m/^http/is);
								$filter_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
								$filter_url=$filter_url.'&pgesize=200';
								my $filter_page=&get_source_page($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5,$filter_name,$filter_value); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> DRESSES(ALL) -> COLOUR -> WHITE
							}
						}
					}
				}
				while($menu_3_page=~m/<div\s*class\=\"rightcol\">\s*<ul>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES
					my $menu_4_block=$1;
					my $menu_4='Shop by Category';
					
					while($menu_4_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/li>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> SHOES
						my $menu_5_url=$1;
						my $menu_5=&DBIL::Trim($2); # SHOES
						next if($menu_5=~m/Magazine|Premium\s*Brands|A\s*To\s*Z\s*Of\s*Brands/is);
						$menu_5_url=$home_url.$menu_5_url unless($menu_5_url=~m/^http/is);
						$menu_5_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
						$menu_5_url=$menu_5_url.'&pgesize=200';
						my $menu_5_page=&get_source_page($menu_5_url);
						my $no_filter_page=$menu_5_page;
						&Product_Insert($no_filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> SHOES
						
						while($menu_5_page=~m/<p\s*class\=\"sub\-title\">\s*<a\s*href\=\"#\"\s*class\=\"toggleControl\"\s*>\s*((?!Size|Price|Brand)[^>]*?)\s*<\/a>\s*<\/p>\s*([\w\W]*?)\s*<\/ul>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> SHOES -> COLOUR
							my $filter_name=&DBIL::Trim($1);
							my $filter_block=$2;
							
							while($filter_block=~m/<a[^>]*?href\=\"([^>]*?)\">\s*((?!Clear)[^>]*?)\s*<\/a>/igs){ # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> SHOES -> COLOUR -> BLACK
								my $filter_url=$1;
								my $filter_value=&DBIL::Trim($2);
								$filter_url=$home_url.$filter_url unless($filter_url=~m/^http/is);
								$filter_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
								$filter_url=$filter_url.'&pgesize=200';
								my $filter_page=&get_source_page($filter_url);
								&Product_Insert($filter_page,$top_menu,$menu_2,$menu_3,$menu_4,$menu_5,$filter_name,$filter_value); # NAVIGATION : WOMEN -> SHOP BY PRODUCT -> SALE - UPTO 50% OFF -> SHOP BY CATEGORIES -> SHOES -> COLOUR -> BLACK
							}
						}
					}
				}
			}
		}
	}
}
undef $source_page;
$dbh->commit();
$dbh->disconnect;
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Asos-US--Detail.pl  &`);

#################### For Dashboard #######################################
&DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

###### <-- LIST ROBOT - BEGIN --> ########

sub Product_Insert(){ # INSERT TAGS INTO DB	
	my $page=shift;
	my $top_menu=shift;
	my $menu_2=shift;
	my $menu_3=shift;
	my $menu_4=shift;
	my $menu_5=shift;
	my $filter=shift;
	my $filter_value=shift;
	
	next_page:
	while($page=~m/<div\s*class\=\"categoryImageDiv\"[^>]*?>\s*<a[^>]*?href\=\"([^>]*?)\">/igs){
		my $product_url=$1;
		$product_url='http://us.asos.com/pgeproduct.aspx'.$1 if($product_url=~m/(\?iid\=\d+)/is); # CONSTRUCTING UNIQUE PRODUCT URL
		next if($product_url=~m/\?sgid\=[0-9]+/is);
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
		&DBIL::SaveTag('Menu_5',$menu_5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if($menu_5 ne '');
		&DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) if(($filter ne '') && ($filter_value ne ''));
		$dbh->commit();
	}
	if($page=~m/<a[^<]*?href\=\'([^<]*?)\'>\s*Next/is){ # ENTRY FOR NEXT PAGE	
		my $next_url=$1;
		$next_url=~s/\&pgesize\=36/\&pgesize\=200/igs;
		$page=&get_source_page($next_url);
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
