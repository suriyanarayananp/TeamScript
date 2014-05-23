#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Matalan_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Matalan_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Matalan-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Mat';
	$pid = $$;
	$ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
	$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
	$excuetionid = $ip.'_'.$pid;
	###########################################
	
	############Proxy Initialization#########
	$country = $1 if($robotname =~ m/\-([A-Z]{2})\-\-/is);
	&DBIL::ProxyConfig($country);
	###########################################
	
	##########User Agent######################
	$ua=LWP::UserAgent->new(show_progress=>1);
	$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
	$ua->timeout(30); 
	$ua->cookie_jar({});
	$ua->env_proxy;
	###########################################

	############Cookie File Creation###########
	($cookie_file,$retailer_file) = &DBIL::LogPath($robotname);
	$cookie = HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
	$ua->cookie_jar($cookie);
	###########################################
	
	my $skuflag = 0;
	my $imageflag = 0;
	
	if($product_object_key)
	{		
		my $product_url=$url;
		$product_url=~s/^\s+|\s+$//g;
		$product_object_key=~s/^\s+|\s+$//g;		
		my $source_page=&get_source_page($product_url);
		goto PNF if($source_page==1); # SOURCE PAGE RETURNS 1 WHEN PRODUCT URL THROWS THE ERROR "404 PAGE NOT FOUND" AND DETAIL COLLECTED FOR THIS URL WILL BE MARKED AS 'X'
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$raw_colour,$current_price,$price_text,$size,$out_of_stock);
		
		###########################################
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/\"id\"\s*\:\s*\"([^>]*?)\"/is){
			$retailer_product_reference=&DBIL::Trim($1);
			$retailer_product_reference=lc($retailer_product_reference);
		}
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<h1[^>]*?>\s*([^>]*?)\s*</is){
			$product_name=&DBIL::Trim($1);
		}		
		
		# BRAND NAME EXTRACTION
		if($source_page=~m/brand\s*tag\-([\w]+)\"/is){
			$brand=$1; # EXTERNAL BRAND NAME
			$brand=~s/__/ & /igs;
			$brand=~s/_/ /igs;
			$brand=~s/(\w+)/\u\L$1/g; # MAKES FIRST LETTER CAPITAL FOR EACH WORD
		}
		else{
			$brand='Matalan'; # OWN BRAND NAME
		}
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/class\=\"description\"[^>]*?>([^>]*?(?:<[^>]*?>[^>]*?)*?)<\/div>/is){
			$product_description=&DBIL::Trim($1);
		}
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/Product\s*Information\s*<\/a>\s*([\w\W]*?)\s*<\/dl>/is){
			$product_detail=&DBIL::Trim($1);
		}
		
		# PRICE TEXT EXTRACTION
		if($source_page=~m/<ul\s*class\=\"prices\"[^>]*?>\s*([\w\W]*?)\s*<\/ul>/is){
			$price_text=&DBIL::Trim($1);
			$price_text=~s/\&\#163\;/£/igs;			
		}

		# CURRENT PRICE EXTRACTION
		if($source_page=~m/itemprop\=\"price\">(?:\s*Now)?\s*([^>]*?)</is){
			$current_price=$1;
			$current_price=~s/\&\#163\;//igs;
		}
		
		# RAW COLOUR EXTRACTION
		while($source_page=~m/<input[^>]*?name\=\"Color\"[^>]*?value\=\"([^>]*?)\"\s*\/>\s*<label[^>]*?>\s*([^>]*?)\s*<\/label>/igs){
			my $color_code=$1; # COLOUR CODE
			my $color_id='http://www.matalan.co.uk/product/detail/'.$retailer_product_reference.'?id='.$retailer_product_reference.'&color='.$1;
			$raw_colour=&DBIL::Trim($2); # RAW COLOUR
			
			# VALIDATING RAW COLOUR FOR DUPLICATES - IF DUPLICATE FOUND, COLOUR CODE (i.e., $color_code) WILL BE APPENDED TO THE DUPLICATE RAW COLOUR (EXAMPLE: WHITE (C109))
			if($hash_color{$raw_colour} eq ''){
				$hash_color{$raw_colour}=$raw_colour;
			}
			else{
				$raw_colour=$raw_colour.' ('.$color_code.')';				
			}
			
			$raw_colour=lc($raw_colour);				
			$raw_colour=~s/(\w+)/\u\L$1/g; # MAKES FIRST LETTER CAPITAL OF EACH WORD
			my $color_content=&get_source_page($color_id);
			next if($color_content==1);
			
			# SIZE EXTRACTION
			if($color_content=~m/<ul\s*class\=\"sizes\">([\w\W]*?)\s*<\/ul>/is){ # SIZE VARIATION 1 (BOX)
				my $size_group=$1;
				while($size_group=~m/data\-max\=\"\d+\"\s*\/>\s*<label\s*for\=\"[^>]*?\"\s*>\s*([^>]*?)\s*(?:<[^>]*?>[^>]*?)*?<\/label>/igs){
					$size=&DBIL::Trim($1);
					$out_of_stock='n'; # IN STOCK
					
					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);
					$sku_objectkey{$sku_object}=$color_code;
					push(@query_string,$query);
				}
				while($size_group=~m/<label\s*for\=\"[^>]*?\"\s*class\=\"oos\">\s*([^>]*?)\s*(?:<[^>]*?>[^>]*?)*?<\/label>/igs){
					$size=&DBIL::Trim($1);
					$out_of_stock='y'; # OUT STOCK
					
					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);				
					$sku_objectkey{$sku_object}=$color_code;
					push(@query_string,$query);
				}
			}
			elsif($color_content=~m/<li\s*class\=\"size\s*dropdown\">\s*([\w\W]*?)\s*<\/li>/is){ # SIZE VARIATION 2 (DROP DOWN)
				my $size_group=$1;
				while($size_group=~m/<option\s*value\=\"[^>]*?\"\s*data\-max\=\"[^>]*?\"\s*>\s*([^>]*?)\s+(?:\-\s*([^>]*?)\s*)?(?:\-\s*([^>]*?)\s*)?<\/option>/igs){
					$size=&DBIL::Trim($1);
					$current_price=$2; # CURRENT PRICE (AVAILABLE IN THE DROP DOWN FOR EACH SIZE)
					$out_of_stock=$3;
					$out_of_stock=~s/^\s*$/n/igs; # IN STOCK
					$out_of_stock=~s/Out\s*of\s*Stock/y/igs; # OUT STOCK
					$out_of_stock=~s/Email\s*me\s*when\s*in\s*Stock/y/igs; # OUT STOCK
					$current_price=~s/Now\s*\&\#163\;\s*([^>]*?)\s*$/$1/igs;
					$current_price=~s/^\&\#163\;\s*([^>]*?)$/$1/igs;
					
					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);
					$sku_objectkey{$sku_object}=$color_code;
					push(@query_string,$query);
				}
			}
			else{ # ENTRY WHEN SIZE IS NOT AVAILABLE IN PRODUCT PAGE
				$size='one size';
				$out_of_stock='n';				
				# DEPLOYING SKU DETAILS INTO SKU TABLE
				my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag=1 if($flag);
				$sku_objectkey{$sku_object}=$color_code;
				push(@query_string,$query);
			}
			
			# IMAGE EXTRACTION
			my $image_count=1;
			if($color_content=~m/<ul\s*id\=\"product\-visual\-thumbnails\">([\w\W]*?)<\/ul>/is){				
				my $img_link_block=$1;				
				while($img_link_block=~m/<a\s*href[^>]*?largeimage\:\s*\'([^>]*?)\'/igs){
					my $img_link='http:'.$1;
					$img_link=~s/\\\//\//g;
					
					if($image_count eq 1){ # DEFAULT IMAGE
						my ($imgid,$img_file)=&DBIL::ImageDownload($img_link,'product',$retailer_name);
						
						# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$img_link,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$color_code;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
					else{ # ALTERNATE IMAGE
						my ($imgid,$img_file)=&DBIL::ImageDownload($img_link,'product',$retailer_name);
						
						# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$img_link,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$color_code;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
					$image_count++;
				}
			}	
		}
		undef %hash_color;
		undef $source_page;
		
		# MAPPING SKU AND IMAGE
		my @image_obj_keys=keys %image_objectkey;
		my @sku_obj_keys=keys %sku_objectkey;
		foreach my $img_obj_key(@image_obj_keys){
			foreach my $sku_obj_key(@sku_obj_keys){
				if($image_objectkey{$img_obj_key} eq $sku_objectkey{$sku_obj_key}){
					
					# DEPLOYING SKU HAS IMAGE INTO SKU HAS IMAGE TABLE
					my $query=&DBIL::SaveSkuhasImage($sku_obj_key,$img_obj_key,$hash_default_image{$img_obj_key},$product_object_key,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					push(@query_string,$query);
				}
			}
		}
		undef %sku_objectkey, undef %image_objectkey, undef %hash_default_image;
		
		# DEPLOYING PRODUCT DETAILS INTO PRODUCT TABLE
		PNF:
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$retailer_product_reference,$product_name,$brand,$product_description,$product_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$product_url,$retailer_id);		
		push(@query_string,$query1);
		push(@query_string,$query2);
		# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		# push(@query_string,$qry); 
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		undef $product_name, undef $product_description, undef $retailer_product_reference, undef $brand, undef $product_detail, undef $raw_colour, undef $current_price, undef $price_text, undef $size, undef $out_of_stock;
	}
}1;

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
