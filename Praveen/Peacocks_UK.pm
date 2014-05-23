#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Peacocks_UK;
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
sub Peacocks_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $product_url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Peacocks-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Pea';
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
		goto PNF if($source_page=~m/<h1>\s*(Whoops\!)\s*<\/h1>/is); # SOURCE PAGE CONTAINS WHOOPS! WHEN REQUESTED PRODUCT NOT FOUND IN THE WEBSITE AND DETAIL COLLECTED FOR THIS URL WILL BE MARKED AS 'X'
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################		
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/Number\:\s*(\d+)\s*[^>]*?\s*</is){
			$retailer_product_reference=&DBIL::Trim($1);
		}

		# VERIFICATION ON PRODUCT TABLE, WHETHER RETAILER PRODUCT REFERENCE WAS ALREADY EXIST. IF EXIST DUPLICATE PRODUCT WILL BE REMOVED FROM THE PRODUCT TABLE AND FURTHER SCRAPPING WILL BE SKIPPED
		my $ckproduct_id=&DBIL::UpdateProducthasTag($retailer_product_reference, $product_object_key, $dbh,$robotname,$retailer_id);
		goto End if($ckproduct_id == 1);
		undef ($ckproduct_id);
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<header>\s*<h1>([^>]*?)<\/h1>/is){
			$product_name=&DBIL::Trim($1);
		}
		
		# BRAND NAME EXTRACTION - ALL PRODUCTS IN THE RETAILER WEBSITE BELONGS TO PEACOCKS BRAND (NO EXTERNAL BRANDS AVAILABLE)
		$brand='Peacocks';
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/description\">\s*([^>]*?(?:<[^>]*?>[^>]*?)*?)\s*<\/p>/is){		
			$product_description=&DBIL::Trim($1);
			$product_description=~s/â€//igs;
		}
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/extra\">\s*([^>]*?(?:<br\s*\/>[^>]*?)*?)\s*<\/p>/is){
			$product_detail=&DBIL::Trim($1);			
		}
		
		# PRICE TEXT EXTRACTION
		if($source_page=~m/price\-box\">\s*([\w\W]*?)\s*<\/div>/is){
			$price_text=$1;			
			$price_text=~s/<[^>]*?>/ /igs;
			$price_text=~s/^\s*|\s*$//igs;
			$price_text=~s/\s+/ /igs;
			$price_text=~s/Â//igs;
		}	
		
		# CURRENT PRICE EXTRACTION
		if($source_page=~m/regular\-price\"[^>]*?>\s*<span\s*class\=\"price\">\s*[^>]*?([\d\.]*?)\s*</is){
			$current_price=&DBIL::Trim($1);
		}
		elsif($source_page=~m/<strong\s*class\=\"price\"\s*id\=\"[^>]*?\">\s*[^>]*?([\d\.]*?)\s*<\/strong>/is){
			$current_price=&DBIL::Trim($1);
		}
		
		# EXTRACTION OF SWATCH IMAGE, PRODUCT IMAGE AND SKU FOR EACH COLOUR IN THE PRODUCT PAGE
		while($source_page=~m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\">\s*<span\s*class\=\"swatch\">\s*<img\s*src\=\"([^>]*?)\"[^>]*?\/>/igs){
			my $swatch_url=$1;
			my $raw_colour=&DBIL::Trim($2);
			my $swatch=$3;
			$swatch=~s/^\s+|\s+$//g;
			my $swatch_page=&get_source_page($swatch_url);
			
			# SWATCH IMAGE EXTRACTION
			my ($imgid,$img_file)=&DBIL::ImageDownload($swatch,'swatch',$retailer_name);
			my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag=1 if($flag);
			$image_objectkey{$img_object}=$raw_colour;
			$hash_default_image{$img_object}='n';
			push(@query_string,$query);
						
			# SIZE EXTRACTION
			if($swatch_page=~m/<\/dl>\s*<script[^>]*?>\s*([\w\W]*?)\s*<\/script>\s*<div\s*class\=\"no\-display\">/is){
				my $size_block=$1;		
				while($size_block=~m/\"label\"\:\"((?!Size)[^>]*?)\"/igs){
					my $size=&DBIL::Trim($1);
					my $out_of_stock='n'; # IN STOCK - ONLY IN-STOCK PRODUCTS ARE AVAILABLE IN THE RETAILER WEBSITE (OUT STOCK NOT AVAILABLE)
					
					# DEPLOYING SKU DETAILS INTO SKU TABLE
					my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag=1 if($flag);
					$sku_objectkey{$sku_object}=$raw_colour;
					push(@query_string,$query);
				}
				undef $size_block;
			}
			
			# PRODUCT IMAGE EXTRACTION
			if($swatch_page=~m/data\-images\=\"[^>]*?default([^>]*?)\">/is){
				my $image_block=$1;		
				my $count=1;
				while($image_block=~m/large\&quot\;\:\&quot\;(http\:[^>]*?970x1274[^>]*?)\&quot\;\}/igs){
					my $image_url=&DBIL::Trim($1);					
					$image_url=~s/\\\//\//g;
					if($count == 1){ # DEFAULT IMAGE
						my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
						
						# DEPLOYING DEFAULT IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$raw_colour;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
					else{ # ALTERNATE IMAGE
						my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
						
						# DEPLOYING ALTERNATE IMAGE DETAILS INTO IMAGE TABLE
						my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag=1 if($flag);
						$image_objectkey{$img_object}=$raw_colour;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
					$count++;
				}
				undef $image_block;
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
		End:
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