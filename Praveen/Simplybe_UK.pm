#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Simplybe_UK;
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
sub Simplybe_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $product_url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Simplybe-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Sim';
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
		$product_url=~s/^\s+|\s+$//g;
		$product_object_key=~s/^\s+|\s+$//g;	
		my $source_page=&get_source_page($product_url);
		goto PNF if($source_page==1);
			
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/name\">([^<]*?)</is){
			$product_name=&DBIL::Trim($1);
		}
				
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/ProductId\s*\=\s*\'([^>]*?)\'/is){
			$retailer_product_reference=&DBIL::Trim($1);			
		}
		
		# VERIFICATION ON PRODUCT TABLE, WHETHER RETAILER PRODUCT REFERENCE WAS ALREADY EXIST. IF EXIST DUPLICATE PRODUCT WILL BE REMOVED FROM THE PRODUCT TABLE AND FURTHER SCRAPPING WILL BE SKIPPED
		my $ckproduct_id=&DBIL::UpdateProducthasTag($retailer_product_reference, $product_object_key, $dbh,$robotname,$retailer_id);
		goto Dup if($ckproduct_id==1);
		undef ($ckproduct_id);		
		
		# BRAND NAME EXTRACTION
		if($source_page=~m/<div\s*id\=\"brandLogoContainer\">\s*<a\s*href\=\"\#\"\s*onclick\=\"return\s*fnSearchByBrand\(\'([^>]*?)\'\)\;\">/is){
			$brand=$1; # EXTERNAL BRAND			
			&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}		
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/description\">\s*([\w\W]*?)\s*<\!\-\-\s*END\:\s*\#productDescription/is){
			$product_detail=&DBIL::Trim($1);
		}		
		
		# PRICE TEXT EXTRACTION
		if($source_page=~m/<span\s*class=[^>]*?Range">\s*([\w\W]*?)<\/span>\s*<\/h3>/is){
			$price_text=$1;
			$price_text=~s/\&pound\;/\£/ig;
			$price_text=&DBIL::Trim($price_text);
		}
		
		# CURRENT PRICE EXTRACTION
		if($source_page=~m/productPrice\=\'\s*([^>]*?)\s*to/is){
			$current_price=$1;
		}
		elsif($price_text=~m/\£\s*([\d\.\,]*)\s*$/is){
		   $current_price=$1;
		   $current_price=~s/\,//ig;
		}
		
		my ($pdLpUid,$pdBoUid);		
		if($product_url=~m/\/([\w]*?)\/product\/details/is){
			$pdLpUid=uc($1);
		}
		if($product_url=~m/pdBoUid=(\d+)/is){
			$pdBoUid=$1;
		}

		# RAW COLOR
		my $raw_color;
		if($source_page=~m/<select\s*name=\"optionColour([\w\W]*?)<\/select>/is){
			my $color_Block=$1;

			while($color_Block=~m/<option\s*value=\"([^>]*?)\">(?!Select\s*Colour)[^>]*?(?:<span\s*class=\"([^>]*?)\">[^<]*?<\/span>)?<\/option>/igs){ # EXTRACTS RAW COLOUR FROM COLOUR BLOCK
				$raw_color=&DBIL::Trim($1);
				my $stock=$2;

				if($source_page=~m/<select\s*name\=\"optionSize\"[^>]*?>\s*([\w\W]*?)\s*<\/select>/is){ # ENTRY FOR SIZE BLOCK
					my $size_block=$1;

					my $json_url='http://www.simplybe.co.uk/shop/product/details/ajax/refreshForColour.action?pdLpUid='.$pdLpUid.'&pdBoUid='.$pdBoUid.'&lpgUid=&productId='.$retailer_product_reference.'&lineItem=&selectedOptionId=&unformattedPrice=0&unformattedDeliveryCharge=0&currencyUnicodeSymbol=&productDesc='.$product_name.'&personalisable=false&originalSrcPage=&claimcode=&incentiveId=&optionColour='.$raw_color.'&optionSize=&quantity=1'; # JSON URL - FOR COLLECTING IN/OUT STOCK AND IMAGE INFORMATION
					my $json_page=&get_source_page($json_url);
					$json_page=~s/\\\//\//igs;

					while($size_block=~m/<option\s*value\=\"([^>]*?)\">\s*(?!Select\s*Size)[^>]*?\s*</igs){ # ENTRY FOR SIZE
						my $size=$1; # SIZE						

						# SIZE EXTRACTION						
						if($json_page=~m/\"displayCssClass\"\:\"([\w]*?)\"\,\"displayString\"\:\"\s*$size/is){ # IN/OUT-STOCK VERIFICATION
							my $stock=$1;
							my $out_of_stock='y'; # OUT-STOCK
							$out_of_stock='n' if($stock=~m/inStock|lowStock/is); # IN-STOCK

							# DEPLOYING SKU DETAILS INTO SKU TABLE
							my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag=1 if($flag);
							$sku_objectkey{$sku_object}=$raw_color;
							push(@query_string,$query);
						}

						# PRODUCT DEFAULT IMAGE EXTRACTION
						if($json_page=~m/mainImage\"\:[^>]*?\"hugeLocation\"\:\"([^>]*?)\"/is){
							my $image_url=$1; # DEFAULT IMAGE URL
							$image_url=~s/\\\//\//igs;

							# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
							my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
							my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag=1 if($flag);
							$image_objectkey{$img_object}=$raw_color;
							$hash_default_image{$img_object}='y';
							push(@query_string,$query);
						}						
					}
				}
				else{ # ENTRY FOR PRODUCT WHEN RAW COLOUR IS AVAILABLE AND SIZE IS NOT AVAILABLE IN THE PRODUCT PAGE
					my $size='one size'; # SIZE
					my $out_of_stock='n'; # IN-STOCK
					$out_of_stock='y' if($stock=~m/noLongerAvailable/is); # OUT-STOCK

					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);
					$sku_objectkey{$sku_object}=$raw_color;
					push(@query_string,$query);
					
					# PRODUCT DEFAULT IMAGE EXTRACTION					
					if($source_page=~m/hugeLocation\:\s*\'([^>]*?)\'/is){
						my $image_url=$1; # IMAGE URL												
						my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
						
						# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$raw_color;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);												
					}
				}
			}
		}
		else{ # ENTRY FOR PRODUCT WHEN BOTH RAW COLOUR AND SIZE ARE NOT AVAILABLE IN THE PRODUCT PAGE
			my $size='one size'; # SIZE
			my $out_of_stock='n'; # IN-STOCK
			$raw_color='no raw color'; # RAW COLOUR

			# DEPLOYING SKU DETAILS INTO SKU TABLE
			my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag=1 if($flag);
			$sku_objectkey{$sku_object}=$raw_color;
			push(@query_string,$query);
			
			# PRODUCT DEFAULT IMAGE EXTRACTION
			if($source_page=~m/hugeLocation\:\s*\'([^>]*?)\'/is){
				my $image_url=$1; # IMAGE URL				
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);

				# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$raw_color;
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);				
			}
		}
		
		# PRODUCT ALTERNATE IMAGE EXTRACTION
		my $image_count=1;
		while($source_page=~m/hugeLocation\:\s*\'([^>]*?)\'/igs){ # PRODUCT IMAGE EXTRACTION
			my $image_url=$1; # IMAGE URL
			next if($image_url eq "");
			
			if($image_count >= 2){ # ALTERNATE IMAGE EXTRACTION
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
				
				# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$raw_color;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
			$image_count++;
		}		
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