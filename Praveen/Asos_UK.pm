#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Asos_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use HTTP::Cookies;
use DBI;
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Asos_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;	
	my $retailer_id=shift;
	my $logger = shift;
	$robotname='Asos-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Auk';
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
		goto PNF if($source_page==1);
		goto PNF if($source_page=~m/<div\s*class\=\"outofstock\">\s*Out\s*Of\s*Stock\s*<\/div>/is);
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/productcode\"\s*>\s*([^>]*?)\s*</is){
			$retailer_product_reference=&DBIL::Trim($1);
		}
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/title\"\s*content\=\"([^>]*?)\s*at(?:\s*asos\.com\")?/is){
			$product_name=&DBIL::Trim($1);
			$product_name=decode_entities($product_name);
		}
		
		# BRAND NAME EXTRACTION
		if($source_page=~m/\"ProductBrand\"\:\"([^>]*?)\"/is){ # EXTERNAL BRAND
			$brand=&DBIL::Trim($1);
			&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		elsif($product_name ne ''){
			$brand='Asos'; # OWN BRAND
		}
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/class\=\"product-description\"\s*[^>]*?>\s*([\w\W]*?)\s*<\/div>/is){
			$product_description=&DBIL::Trim($1);
			$product_description=decode_entities($product_description);
		}
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/id\=\"infoAndCare\"[^>]*?\s*>\s*([\w\W]*?)\s*<span[^>]*?class\=\"productcode\">/is){
			$product_detail=$1;
			$product_detail=~s/Product\s*Code\://ig;
			$product_detail=~s/ABOUT\s*ME//ig;
			$product_detail=&DBIL::Trim($product_detail);
			$product_detail=decode_entities($product_detail);
		}
		
		# PRICE TEXT EXTRACTION
		if($source_page=~m/<div[^>]*?class\=\"product_price\"[^>]*?>\s*([\w\W]*?\s*<span[^>]*?product_price_details\s*[^>]*?\s*>[\w\W]*?)\s*<\/div>/is){
			$price_text=&DBIL::Trim($1);
			$price_text=~s/\&\#163\;/\£ /igs;
		}
		
		# CURRENT PRICE EXTRACTION
		if($source_page=~m/price\"\s*content\=\'\&\#163\;([^>]*?)\'/is){
			$current_price=$1;
		}
		
		# RAW COLOUR EXTRACTION		
		if($source_page=~m/colour(?:s)?\s*<\/option>\s*([\w\W]*?)\s*<\/select>/is){
			my $color_block=$1;
			
			while($color_block=~m/<option[^>]*?value\=\"([^>]*?)\">\s*([^>]*?)\s*</igs){			
				my $raw_color=&DBIL::Trim($1); # RAW COLOUR VALUE				
				my $sku_color=$raw_color;
				$sku_color=~s/\W*//igs;
				$sku_color=~s/\s*//igs;
				$sku_color=lc($sku_color);
				
				# SIZE EXTRACTION
				if($source_page=~m/var\s*arrSzeCol_ctl00_ContentMainPage_ctlSeparateProduct([\w\W]*?)\s*<\/script>/is){
					my $size_block=$1;
					
					while($size_block=~m/\(\d+\,\"([^>]*?)\"\,\"[^\"]*?\"\,\"(true|false)\"/igs){
						my $size=&DBIL::Trim($1); # SIZE
						my $out_of_stock=&DBIL::Trim($2); # STOCK - TRUE/FALSE
						$out_of_stock=~s/\s*true\s*$/n/ig; # IN-STOCK
						$out_of_stock=~s/\s*false\s*$/y/ig; # OUT-STOCK			

						# DEPLOYING SKU INFORMATION INTO SKU TABLE
						my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag=1 if($flag);
						$sku_objectkey{$sku_object}=$retailer_product_reference;
						push(@query_string,$query);
					}
				}				
			}
		}

		# DEFAULT PRODUCT IMAGE EXTRACTION
		if($source_page=~m/arrMainImage\s*\=([\w\W]*?)\s*var/is){
			my $image_block=$1;			

			while($image_block=~m/\"([a-z\/0-9\.\:\-]*)\"\,\s*\"[\w]*?\"\)\;/igs){
				my $image_url=$1;
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
				
				# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$retailer_product_reference;
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);
			}			
		}
		
		# ALTERNATE PRODUCT IMAGE EXTRACTION
		if($source_page=~m/arrThumbImage\s*\=([\w\W]*?)\s*var/is){
			my $image_block=$1;
			
			while($image_block=~m/\(\"([^<]*?)\"\s*\,[^>]*?\s*\"/igs){
				my $image_url=$1;
				$image_url=~s/image2s/image2xxl/igs;				
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
				
				# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$retailer_product_reference;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
		}
		
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
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		undef $product_name, undef $product_description, undef $retailer_product_reference, undef $brand, undef $product_detail, undef $current_price, undef $price_text;
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
