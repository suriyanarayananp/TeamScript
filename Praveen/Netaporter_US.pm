#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Netaporter_US;
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
sub Netaporter_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Net-a-porter-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Nus';
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
		goto PNF if($source_page=~m/What\s*to\s*buy\s*now/is);		
		goto PNF if($source_page=~m/<div\s*class\=\"message\">\s*Unfortunately\,\s*this\s*product\s*is\s*no\s*longer\s*available\s*\.\s*<\/div>/is);
		
		####### GLOBAL VARIABLE DECLARATION #######
		
		my @query_string;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hash_color);
		my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
		
		###########################################
		
		# RETAILER PRODUCT REFERENCE EXTRACTION (AS SEEN IN PRODUCT PAGE)
		if($source_page=~m/productID\s*\=\s*\"?\s*(\d+)\s*(?:\;|\,|\")/is){
			$retailer_product_reference=&DBIL::Trim($1);			
		}
		
		# PRODUCT NAME EXTRACTION
		if($source_page=~m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is){
			$product_name=&DBIL::Trim($1);			
		}
		decode_entities($product_name);
		
		# BRAND NAME EXTRACTION - ONLY EXTERNAL BRAND ARE AVAILABLE
		if($source_page=~m/<li>\s*<a\s*href\=\"[^\"]*?\"\s*title\=\"[^\"]*?\">\s*([^<]*?)\s*<\/a>\s*<\/li>|<h2\s*itemprop\=\"brand\"[^>]*?>\s*<a[^>]*?>\s*([^>]*?)\s*<\/a>/is){
			$brand=&DBIL::Trim($1.$2);
			&DBIL::SaveTag('Designer',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		
		# PRODUCT DESCRIPTION EXTRACTION
		if($source_page=~m/<div\s*class\=\'tabBody1\s*tabContent\'>\s*<p><span\s*class\=\"en\-desc\">\s*([\w\W]*?)\s*<\/p>/is){
			$product_description=&DBIL::Trim($1);			
		}
		decode_entities($product_description);
		
		# PRODUCT DETAIL EXTRACTION
		if($source_page=~m/>\s*Size\s*\&\s*fit\s*<\/a>\s*([\w\W]*?)\s*<\/ul>\s*<\/span>/is){
			$product_detail=&DBIL::Trim($1);
		}
		if($source_page=~m/<div\s*class\=\'tabBody2\s*tabContent\'[^>]*?>\s*<p>\s*<span\s*class\=\"en\-desc\">\s*([\w\W]*?)\s*<\/span>/is){
			$product_detail=$product_detail.' '.&DBIL::Trim($1);
		}		
		decode_entities($product_detail);
		
		# PRICE TEXT & CURRENT PRICE EXTRACTION
		if($source_page=~m/<span\s*itemprop\=\"price\">\s*([^>]*?)\s*<\/span>/is){
			$price_text= &DBIL::Trim($1);
			$current_price=$price_text;
		}
		elsif($source_page=~m/<span\s*class\=\"was\">\s*([^<]*?)\s*<\/span>\s*<span\s*class\=\"now\">\s*([^<]*?)\s*<\/span>\s*<span\s*class\=\"percentage\">\s*([^>]*?)\s*<\/span>/is){
			$price_text=$1.' '.$2.' '.$3;
			$current_price=$2;
		}
		elsif($source_page=~m/<span\s*class\=\"was\">\s*([^<]*?)\s*<\/span>\s*<span\s*class\=\"now\">\s*([^<]*?)\s*<\/span>/is){
			$price_text=$1." ".$2;
			$current_price=$2;
		}
		elsif($source_page=~m/<div\s*id\=\"price\">\s*([^<]*?)\s*<\/div>/is){
			$price_text=$1;
			$current_price=$price_text;
		}		
		$current_price=~s/\$//igs;
		$current_price=~s/\,//igs;
		&DBIL::Trim($price_text);
		&DBIL::Trim($current_price);
		
		# RAW COLOUR EXTRACTION - (SO FAR SEEN ONLY 1 COLOUR IN EACH PRODUCT PAGE)
		my $raw_color;
		if($source_page=~m/value\=\"([^\"]*?)\"\s*name\=\"pr_color\"\s*id\=\"pr_color\"\/>/is){
			$raw_color=$1;			
		}

		# SIZE EXTRACTION
		my $own_flag=0;		
		while($source_page=~m/<option\s*value\=\"[^>]*?\"\s*>\s*((?!Choose\s*Your\s*Size)[^>]*?)\s*(?:\-\s*(sold\s*out))?\s*<\/option>/igs){
			my $size=$1; # SIZE
			my $stock=$2;
			my $out_of_stock='n'; # IN-STOCK
			$out_of_stock='y' if($stock=~m/sold/is); # OUT-STOCK
			$size=$1 if($size=~m/^([^>]*?)\s*\-[^>]*?$/is);
			$own_flag=1;
			
			# DEPLOYING SKU DETAILS INTO SKU TABLE
			my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag=1 if($flag);
			$sku_objectkey{$sku_object}=$raw_color;
			push(@query_string,$query);
		}
		if($own_flag==0){
			my $size='one size';
			my $out_of_stock='n';			
			
			# DEPLOYING SKU DETAILS INTO SKU TABLE
			my ($sku_object,$flag,$query)=&DBIL::SaveSku($product_object_key,$product_url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag=1 if($flag);
			$sku_objectkey{$sku_object}=$raw_color;
			push(@query_string,$query);
		}
		
		# PRODUCT IMAGE EXTRACTION
		my $image_count=1;
		if($source_page =~ m/<div\s*id\=\"thumbnails\-container\">([\w\W]*?)<\/div>/is)
		{
			my $imgcont = $1;
			while($imgcont=~m/<meta\s*property\=\"og\:image\"\s*content\=\"([^>]*?)\"\s*\/>/igs)
			{
				my $image_url=$1;
				# $image_url=~s/xs\.jpg/pp\.jpg/igs;
				if($image_count == 1){ # DEFAULT IMAGE EXTRACTION
					my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
					my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag=1 if($flag);
					$image_objectkey{$img_object}=$raw_color;
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);
				}
				elsif($image_count > 1){ # ALTERNATE IMAGE EXTRACTION
					my ($imgid,$img_file)=&DBIL::ImageDownload($image_url,'product',$retailer_name);
					my ($img_object,$flag,$query)=&DBIL::SaveImage($imgid,$image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag=1 if($flag);
					$image_objectkey{$img_object}=$raw_color;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
				$image_count++;
			}
			undef($imgcont);
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
