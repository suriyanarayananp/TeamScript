#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Stagestores_US;
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
sub Stagestores_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Stagestores-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Sta';
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
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$product_detail,$retailer_product_reference,$brand,$current_price,$price_text);
		
		###########################################

		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/\s*WEB\s*ID\s*\#\:\s*(\d+)\s*</is){
			$retailer_product_reference=&DBIL::Trim($1);
		}
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<h1>([^<]*?)<\/h1>/is){
			$product_name=$1;
			$product_name=decode_entities($product_name);
		}
		
		# BRAND NAME EXTRACTION - ONLY EXTERNAL
		my $brand_url='http://c3.ugc.bazaarvoice.com/data/batch.json?passkey=do7uiig8dw5bvdh6goykmanqb&apiversion=5.4&displaycode=13197-en_us&resource.q0=products&filter.q0=id%3Aeq%3A'.$retailer_product_reference;
		my $brand_page=&get_source_page($brand_url);
		if($brand_page=~m/\{\"Brand\"\:\{\"Name\"\:\"([^>]*?)\"\,\"Id\"\:\"\d+\"\}/is){
			$brand=&DBIL::Trim($1);
			&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}

		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/<div\s*class=\"prdinfo\-detls\">\s*([\w\W]*?)<\/div>\s*<\!\-\-\s*Shipping\s*Tab\s*\-\->/is){
			$product_description=$1;
			$product_description=~s/<li>/\n* /igs;
			$product_description=&DBIL::Trim($product_description);
		}

		# PRICE TEXT & CURRENT PRICE EXTRACTION
		if($source_page=~m/<span\s*class\=\"org\-item\-price\">\s*(?<Direct_Sale_Price>[^>]*?)\s*<\/span>/is){
			$price_text=$1;
			$current_price=$price_text;
		}
		elsif($source_page=~m/<span\s*class\=\"cur\-prce\">\s*(?<Sale_Price>[^>]*?)\s*<\/span>/is){
			$current_price=$1;
			$price_text=$price_text.' '.$current_price;
		}
		 $price_text=$price_text.' '.$1.' '.$2 if($source_page=~m/<span\s*class\=\"org\-price\">\s*(?<Original_Price>[^>]*?)\s*<\/span>\s*<span>\s*([^>]*?)\s*<\/span>/is);
		$price_text=$price_text.' '.$1 if($source_page=~m/<span\s*class\=\"sve\-prce\">\s*(?<Offer>[^>]*?)\s*<\/span>/is);
		$current_price=~s/\,/ /igs;
		$current_price=~s/\$//igs;
		$current_price=~s/\!//igs;
		$current_price=~s/yes//igs;
		&DBIL::Trim($price_text);
		&DBIL::Trim($current_price);
		
		# SIZE AND RAW COLOUR EXTRACTION
		my ($size,$out_of_stock,$raw_color);
		if($source_page=~m/Select\s*Color<\/option>/is){ # ENTRY WHEN RAW COLOUR AVAILABLE IN PRODUCT PAGE
			if($source_page=~m/<div\s*class\=\"slct\-szs\">([\w\W]*?)<div>/is){ # ENTRY WHEN RAW COLOUR AND SIZE AVAILABLE IN PRODUCT PAGE
				my $size_block=$1;
				
				while($size_block=~m/<input\s*type=\"button\"\s*class=\"slctsze\s*clean\s*Button\"\s*rel=\"[^<]*?\"\s*value="([^<]*?)\"\s*\/>/igs){
					$size=$1;
					my $size_construct_url='http://www.stagestores.com/store/browse/pdp/gadgets/productInfoContent.jsp?productId='.$retailer_product_reference.'&selectedSize='.$size.'&selectedColor=';
					my $size_page=&get_source_page($size_construct_url);
					
					if($size_page=~m/<option\s*value\=\"\d+\">Select\s*Color<\/option>\s*([\w\W]*?)\s*<\/select>/is){
						my $color_block=$1;

						while($color_block=~m/<option\s*value=\"[^<]*?\"\s*>([^<]*?)<\/option>/igs){
							$raw_color=$1;
							$out_of_stock='n';
							
							# DEPLOYING SKU DETAILS INTO SKU TABLE
							my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag=1 if($flag);
							$sku_objectkey{$sku_object}=$retailer_product_reference;
							push(@query_string,$query);
						}
					}
				}
			}
			elsif($source_page=~m/<div\s*class="qtyslct-bx">/is){ # ENTRY WHEN RAW COLOUR AVAILABLE AND SIZE NOT AVAILABLE IN PRODUCT PAGE
				if($source_page=~m/<option\s*value\=\"\d+\">Select\s*Color<\/option>\s*([\w\W]*?)\s*<\/select>/is){
					my $color_block=$1;
					
					while($color_block=~m/<option\s*value=\"[^<]*?\"\s*>([^<]*?)<\/option>/igs){
						$raw_color=$1;
						$out_of_stock='n';
						$size='One Size';
						
						# DEPLOYING SKU DETAILS INTO SKU TABLE
						my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag=1 if($flag);
						$sku_objectkey{$sku_object}=$retailer_product_reference;
						push(@query_string,$query);
					}
				}
			}			
		}		
		else{ # ENTRY WHEN RAW COLOUR NOT AVAILABLE IN THE PRODUCT PAGE
			$raw_color='no raw color';
			if($source_page=~m/<div\s*class\=\"slct\-szs\">([\w\W]*?)<div>/is){ # ENTRY WHEN RAW COLOUR NOT AVAILABLE AND SIZE AVAILABLE IN PRODUCT PAGE
				my $size_block=$1;
				
				while($size_block=~m/<input\s*type=\"button\"\s*class=\"slctsze\s*clean\s*Button\"\s*rel=\"[^<]*?\"\s*value="([^<]*?)\"\s*\/>/igs){
					$size=&DBIL::Trim($1);
					$out_of_stock='y';
					$out_of_stock='n' if($source_page=~m/<select\s*id=\"itemQty\">\s*<option\s*value=\"[^<]*?\">[^<]*?<\/option>/is);
					
					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);
					$sku_objectkey{$sku_object}=$retailer_product_reference;
					push(@query_string,$query);
				}
			}
			elsif($source_page=~m/<div\s*class\=\"slct\-grp\">/is){ # ENTRY WHEN RAW COLOUR NOT AVAILABLE AND SIZE AVAILABLE (AND ALSO PRICE AVAILABLE FOR EACH SIZE) IN PRODUCT PAGE
				if ($source_page=~m/<div\s*class\=\"slct\-grp\">([\w\W]*?)<div\s*class\=\"slct\-qty\">/is){
					my $price_block=$1;
					
					while ($price_block=~m/<input\s*id\=\"[^>]*?\"\s*type\=\"radio\"\s*name\=\"Grouped\"\s*value\=\"([^>]*?)\"\s*\/>\s*([\w\W]*?)<\/div>/igs){
						my $price_url ='http://www.stagestores.com/store/browse/pdp/gadgets/productInfoContent.jsp?productId='.$retailer_product_reference.'&selectedGroup='.$1;						
						my $size=$2;
						my $price_content=&get_source_page($price_url);
						$size=~s/<[^>]*?>//igs;
						$size=&DBIL::Trim($size);
						my $out_of_stock='y';
						$out_of_stock='n' if($price_content=~m/<select\s*id=\"itemQty\">\s*<option\s*value=\"[^<]*?\">[^<]*?<\/option>/is);
						
						# PRICE TEXT & CURRENT PRICE EXTRACTION
						if($price_content=~m/<span\s*class\=\"org\-item\-price\">\s*(?<Direct_Sale_Price>[^>]*?)\s*<\/span>/is){
							$price_text=$1;
							$current_price=$price_text;							
						}
						elsif($price_content=~m/<span\s*class\=\"cur\-prce\">\s*(?<Sale_Price>[^>]*?)\s*<\/span>/is){
							$current_price=$1;
							$price_text=$price_text.' '.$current_price;							
						}
						$price_text=$price_text.' '.$1.' '.$2 if($price_content=~m/<span\s*class\=\"org\-price\">\s*(?<Original_Price>[^>]*?)\s*<\/span>\s*<span>\s*([^>]*?)\s*<\/span>/is);
						$price_text=$price_text.' '.$1 if($price_content=~m/<span\s*class\=\"sve\-prce\">\s*(?<Offer>[^>]*?)\s*<\/span>/is);
						$current_price=~s/\,/ /igs;
						$current_price=~s/\$//igs;
				                $current_price=~s/\!//igs;
						$current_price=~s/yes//igs;
						&DBIL::Trim($price_text);
						&DBIL::Trim($current_price);

						# DEPLOYING SKU DETAILS INTO SKU TABLE
						my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag=1 if($flag);
						$sku_objectkey{$sku_object}=$retailer_product_reference;
						push(@query_string,$query);
					}	
				}
			}
			else{ # ENTRY WHEN BOTH RAW COLOUR AND SIZE ARE NOT AVAILABLE IN PRODUCT PAGE
				$size='one size';
				$out_of_stock='y';
				$out_of_stock='n' if($source_page=~ m/<select\s*id=\"itemQty\">\s*<option\s*value=\"[^<]*?\">[^<]*?<\/option>/igs);

				# DEPLOYING SKU DETAILS INTO SKU TABLE
				my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag=1 if($flag);
				$sku_objectkey{$sku_object}=$retailer_product_reference;
				push(@query_string,$query);
			}
		}
		
		# PRODUCT IMAGE EXTRACTION
		my $image_count=1;		
		my $source_page=&get_source_page($product_url);
		while($source_page=~m/<img\s*alt=\"\s*\"\s*src=\"[^>]*?\"\s*\/>\s*<\/a>\s*<input\s*type\=\"hidden\"\s*value\=\"([^>]*?)\?\$zm\$\"\s*\/>/igs)
		{
			my $image_url=$1;
			if($image_count==1){ # DEFAULT IMAGE
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
				# DEPLOYING DEFAULT PRODUCT IMAGE INFORMATION INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$retailer_product_reference;
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);
				$image_count++;
			}			
			else{ # ALTERNATE IMAGE
				my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
				
				# DEPLOYING ALTERNATE PRODUCT IMAGE INFORMATION INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$retailer_product_reference;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}			
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
