#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Jigsaw_UK;
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
sub Jigsaw_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Jigsaw-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Jig';
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
		$product_url='http://www.jigsaw.com'.$product_url unless($product_url=~m/^\s*http\:/is);
		my $source_page=&get_source_page($product_url);
		goto PNF if($source_page==1);
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/id\=\"product_code\">\s*([^>]*?)<\/p>/is){
			$retailer_product_reference=&DBIL::Trim($1);
			$retailer_product_reference=~s/\s*Item\s*number\s*//igs;			
		}
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<h1\s*id\=\"product_title\">([^>]*?)<\/h1>/is){
			$product_name=&DBIL::Trim($1);
		}
		
		# BRAND NAME EXTRACTION - ALL PRODUCTS IN THE RETAILER WEBSITE BELONGS TO JIGSAW BRAND (NO EXTERNAL BRANDS AVAILABLE)
		$brand='Jigsaw';
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/<dd\s*class\=\"description\s*open\s*information_cont\">\s*([^>]*?)<\/dd>/is){
			$product_description=&DBIL::Trim($1);
		}
		
		# PRODUCT DETAIL EXTRACTION
		while($source_page=~m/<dd\s*class\=\"([^>]*?)\s*information_cont\">\s*<ul\s*class\=\"info_list\">\s*([\w\W]*?)\s*<\/ul>/igs){
			$product_detail=$product_detail.' '.&DBIL::Trim($1).' '.&DBIL::Trim($2);
		}
		$product_detail=~s/^\s*|\s*$//igs;
		
		# RAW COLOR EXTRACTION
		if($source_page=~m/<div\s*class\=\"colours\">([\w\W]*?)<\/div>/is){
			my $color_block=$1;
			
			while($color_block=~m/<li[\w\W]*?title\=\'([^>]*?)\'>\s*<a\s*href\=\"([^>]*?)\"/igs)
			{
				my $raw_color=&DBIL::Trim($1); # RAW COLOUR
				my $color_code=&DBIL::Trim($2); # COLOUR CODE
				my $color_url='http://www.jigsaw-online.com'.$color_code;
				my $color_page=&get_source_page($color_url);				
				
				# PRICE TEXT & CURRENT PRICE EXTRACTION FOR EACH COLOURS IN THE PRODUCT PAGE
				if($color_page=~m/<p\s*class\=\"product_price[\w\W]*?<span>\s*\&pound\;([^>]*?)<\/span>/is){
					$current_price=&DBIL::Trim($1);
					$price_text='£ '.$current_price;
				}
				elsif($color_page=~m/class\=\"product_price[\w\W]*?class\=\"wasPrice\">\s*\&pound\;\s*([^>]*?)<\/span>[\w\W]*?class\=\"nowPrice\">\s*\&pound\;\s*([^>]*?)<\/span>/is){
					my $max=$1;#25
					my $min=$2;#19
					$current_price=&DBIL::Trim($min) if($max>$min);
					$current_price=&DBIL::Trim($max) if($max<$min);
					#$price_text='£ '.&DBIL::Trim($max);
					$price_text='£'.$max.' '.'£ '.$min;
				}
				elsif($color_page=~m/<p\s*class\=\"product_price\s*\">\s*<span\s*class\=\"fromPrice\">\&pound\;([^>]*?)\s*<\/span>\s*(\-)\s*<span\s*class\=\"toPrice\">\&pound\;([^>]*?)\s*<\/span>/is)
				{
					$price_text = "£$1 $2 £$3";
				}
				elsif($color_page=~m/<p\s*class\=\"product_price[^>]*?\">[\w\W]*?<span\s*class\=\"nowPrice\">\s*\&pound\;\s*([^>]*?)<\/span><\/p>/is){
					$current_price=&DBIL::Trim($1);
					$price_text='£ '.$current_price;
				}
				
				# SIZE EXTRACTION
				if($color_page=~m/<div\s*id\=\"select_size\"([\w\W]*?)<\/div>/is){
					my $size_block=$1;

					if($price_text =~ m/\-/is)
					{
						if($color_page=~m/<div\s*id\=\"select_size\"([\w\W]*?)<\/div>/is)
						{
							my $size_block=$1;
							my $forwardParamValue1 = $1 if($color_page =~ m/type\=\"hidden\"\s*name\=\"forwardParamValue1\"\s*value\=\"([^>]*?)\"/is);
							while($size_block=~m/<li\s*class\=\"([^>]*?)\"[^>]*?>\s*<label\s*for\=\"sku_([^>]*?)\">\s*([^>]*?)\s*<\/label>/igs){
								my $stock=&DBIL::Trim($1);
								my $sku=&DBIL::Trim($2); # SIZE
								my $size=&DBIL::Trim($3); # SIZE
								my $out_of_stock='y'; # OUT-STOCK			
								$out_of_stock='n' if($stock=~m/in_stock/is); # IN-STOCK
								my $price;
								my $sku_url = "http://www.jigsaw-online.com/pws/UpdateBasket.ice?forwardParamName1=ProductID&forwardParamValue1=$forwardParamValue1&forwardParamName2=colour&forwardParamValue2=&layout=basketresponse.layout&quantity=1&Update=AddQuantity&ProductID=$sku";
								my $eachskucontent = &get_source_page($sku_url);
								$price = &DBIL::Trim($1) if($eachskucontent =~ m/class\=\"unit_price\">\s*([^>]*?)\s*<\/td>/is);
								$price=~s/&pound;//igs;
								$price='null' if($price eq '' or $price eq ' ');
								my $emptybasket = "http://www.jigsaw-online.com/pws/UpdateBasket.ice?newquant_$sku=0&Update=AmendQuantity&ProductID=$sku";
								$eachskucontent = &get_source_page($emptybasket);
								print "$size --> $price_text --> $out_of_stock -> $price\n";
								undef ($eachskucontent);
								# DEPLOYING SKU DETAILS INTO SKU TABLE
								my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$skuflag=1 if($flag);
								$sku_objectkey{$sku_object}=$raw_color;
								push(@query_string,$query);
							}
						}
					}
					else
					{
						while($size_block=~m/<li\s*class\=\"([^>]*?)\"[^>]*?>\s*<label\s*for\=\"sku_[^>]*?\">\s*([^>]*?)\s*<\/label>/igs)
						{
							my $stock=&DBIL::Trim($1);
							my $size=&DBIL::Trim($2); # SIZE
							my $out_of_stock='y'; # OUT-STOCK			
							$out_of_stock='n' if($stock=~m/in_stock/is); # IN-STOCK

							# DEPLOYING SKU DETAILS INTO SKU TABLE
							my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag=1 if($flag);
							$sku_objectkey{$sku_object}=$raw_color;
							push(@query_string,$query);
						}
					}
				}
				
				# PRODUCT IMAGE EXTRACTION
				if($color_page=~m/id\=\"enlarge_button\"\s*data\-image\=\"([^>]*?)\"/is){
					my $default_image=$1; # DEFAULT IMAGE URL
					
					my ($imgid,$img_file)=&DBIL::ImageDownload($default_image,'product',$retailer_name);
					
					# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
					my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$default_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag=1 if($flag);
					$image_objectkey{$img_object}=$raw_color;
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);
					
					# ALTERNATE IMAGE EXTRACTION
					my $count=2;
					if($default_image=~m/^([^>]*?)_1/is){
						my $alternate_image=$1;
						
						while($count <= 4){
							$alternate_image=$alternate_image."_".$count.".jpg";
							my $image_page=&get_source_page($alternate_image);
							goto nextColor if($image_page == 1);
							
							my ($imgid,$img_file)=&DBIL::ImageDownload($alternate_image,'product',$retailer_name);
							
							# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
							my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$alternate_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag=1 if($flag);
							$image_objectkey{$img_object}=$raw_color;
							$hash_default_image{$img_object}='n';
							push(@query_string,$query);
							$count++;
						}
					}					
				}
				nextColor:
			}			
		}
		
		# SWATCH IMAGE EXTRACTION
		if($source_page=~m/<div\s*class\=\"colours\">([\w\W]*?)<\/div>/is){
			my $swatch_block=$1;
			
			while($swatch_block=~m/<img\s*src\=\"([^>]*?)\"\s*alt\=\"([^>]*?)\&nbsp\;swatch\"\s*\/>/igs){
				my $swatch=$1;
				my $raw_color=&DBIL::Trim($2);								
				$swatch='http://www.jigsaw-online.com'.$swatch unless($swatch=~m/^\s*http\:/is);				
				my ($imgid,$img_file)=&DBIL::ImageDownload($swatch,'swatch',$retailer_name);
				
				# DEPLOYING SWATCH IMAGE DETAILS INTO IMAGE TABLE
				my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag=1 if($flag);
				$image_objectkey{$img_object}=$raw_color;
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