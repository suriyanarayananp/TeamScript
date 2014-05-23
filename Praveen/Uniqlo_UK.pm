#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Uniqlo_UK;
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
sub Uniqlo_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Uniqlo-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Uni';
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
		goto PNF if($source_page == 1);
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/ITEM\s*CODE\s*\:\s*(?<Product_ID>[^>]*?)\s*</is){
			$retailer_product_reference=&DBIL::Trim($1);			
		}
		
		# VERIFICATION ON PRODUCT TABLE, WHETHER RETAILER PRODUCT REFERENCE WAS ALREADY EXIST. IF EXIST DUPLICATE PRODUCT WILL BE REMOVED FROM THE PRODUCT TABLE AND FURTHER SCRAPPING WILL BE SKIPPED
		my $ckproduct_id=&DBIL::UpdateProducthasTag($retailer_product_reference, $product_object_key, $dbh,$robotname);
		goto DUP if($ckproduct_id == 1);
		undef ($ckproduct_id);

		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<h1[^>]*?>\s*(?<Product_name>[^>]*?)\s*<\/h1>/is){
			$product_name=&DBIL::Trim($1);
			$product_name=decode_entities($product_name);
		}
		
		# BRAND NAME EXTRACTION - ALL PRODUCTS IN THE RETAILER WEBSITE BELONGS TO UNIQLO BRAND (NO EXTERNAL BRANDS AVAILABLE)
		$brand='Uniqlo';
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/<p\s*class\=\"about\">\s*(?<Product_Desc>[^>]*?(?:<[^>]*?>[^>]*?)*?)\s*<\/p>/is){
			$product_description=&DBIL::Trim($1);
			$product_description=decode_entities($product_description);
		}
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/<dl\s*class\=\"spec\s*clearfix\">\s*(?<Product_Detail>[\w\W]*?)\s*<\/dl>/is){
			$product_detail=&DBIL::Trim($1);
			$product_detail=decode_entities($product_detail);
		}
		
		# PRICE TEXT EXTRACTION
		my ($first_price,$sale_price);
		if($source_page=~m/\"firstPrice\"\:\"\\u00a3(?<Price>[\d\.\,]*?)\"/is){
			$first_price=$1;
			$price_text='£'.&DBIL::Trim($first_price);			
		}
		
		# CURRENT PRICE EXTRACTION
		if($source_page=~m/\"salesPrice\"\:\"\\u00a3(?<Price>[\d\.\,]*?)\"/is){
			$sale_price=$1;
			if($first_price eq $sale_price){
				$current_price=$price_text;
				$current_price=~s/£//igs;
			}
			else{
				$current_price=&DBIL::Trim($sale_price);
				$price_text=$price_text.'£'.$current_price;
			}
		}
		
		# RAW COLOR EXTRACTION
		my ($color_id,$raw_color);
		if($source_page=~m/\"colorInfoList\"\:\{(?<Color_Block>[^>]*?)\}/is){
			my $colour_block=$1;
			my $inc=2;
			my %hash_color;
			while($colour_block=~m/\"(\d+)\"\:\"(?<Color_list>[^>]*?)\"/igs){ # EXTRACTS ALL COLORS AND IT'S CORRESPONDING COLOR ID FROM PRODUCT PAGE
				$color_id=$1; # COLOUR CODE
				$raw_color=&DBIL::Trim($2); # RAW COLOR
				$raw_color=lc($raw_color);
				$raw_color=~s/(\w+)/\u\L$1/g; # MAKES FIRST LETTER CAPITAL OF EACH WORD
				
				# VALIDATING RAW COLOUR FOR DUPLICATES - IF DUPLICATE FOUND, INCREMENTAL VALUE i.e., '2' WILL BE APPENDED TO THE DUPLICATE RAW COLOUR (EXAMPLE: WHITE (2))
				if($hash_color{$raw_color} eq ''){
					$hash_color{$raw_color}=$raw_color;
				}
				else{
					$raw_color=$raw_color.' ('.$inc.')';
					$inc++;
				}
				
				# SWATCH IMAGE EXTRACTION
				my $swatch='http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/chip/'.$color_id.'_'.$retailer_product_reference.'.gif'; # SWATCH IMAGE URL
				
				# DEPLOYING SWATCH IMAGE DETAILS INTO IMAGE TABLE
				my ($imgid,$img_file)=&DBIL::ImageDownload($swatch,'swatch',$retailer_name);
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$color_id;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
				
				# SIZE EXTRACTION
				if($source_page=~m/\"sizeInfoList\"\:\{(?<Size_Block>[^>]*?)\}/is){
					my $size_block=$1;
					
					while($size_block=~m/\"(\d+)\"\:\"(?<Size_list>[^>]*?)\"/igs){ # EXTRACTS ALL SIZES AND IT'S CORRESPONDING SIZE ID FROM PRODUCT PAGE
						my $size_id=$1; # SIZE ID
						my $size=&DBIL::Trim($2); # SIZE
						my $out_of_stock='n'; # IN-STOCK
						$out_of_stock='y' if($source_page=~m/\"realStockCnt\"\:\"0\"\,\"sumStockCnt\"\:\"0\"\,\"lowStockFlg\"\:\"0\"\,\"colorCd\"\:\"$color_id\"\,\"sizeCd\"\:\"$size_id\"/is); # OUT-STOCK
						
						# DEPLOYING SKU DETAILS INTO SKU TABLE
						my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag=1 if($flag);
						$sku_objectkey{$sku_object}=$color_id;
						push(@query_string,$query);
						
						# DEFAULT IMAGE EXTRACTION
						my $default_image='http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/item/'.$color_id.'_'.$retailer_product_reference.'.jpg'; # DEFAULT IMAGE URL
						my ($imgid,$img_file)=&DBIL::ImageDownload($default_image,'product',$retailer_name);
							
						# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$default_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$color_id;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
						
					}											
				}
			}
		}
		
		# ALTERNATE PRODUCT IMAGE EXTRACTION
		if($source_page=~m/\"goodsSubImageList\"\:\"(?<sub_image_block>[^>]*?)\"\,/is){
			my $image_block=$1;			
			
			while($image_block=~m/(?<sub_image>\d+_sub\d+)/igs){ # EXTRACTS ALL ALTERNATE IMAGE SUB NAME FROM THE PRODUCT PAGE
				my $alternate_image=&DBIL::Trim($1);
				$alternate_image='http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/sub/'.$alternate_image.'.jpg'; # ALTERNATE IMAGE URL				
				my ($imgid,$img_file)=&DBIL::ImageDownload($alternate_image,'product',$retailer_name);
				
				# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$alternate_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$color_id;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
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
		undef $product_name, undef $product_description, undef $retailer_product_reference, undef $brand, undef $product_detail, undef $current_price, undef $price_text;
		DUP:
			print "";
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
