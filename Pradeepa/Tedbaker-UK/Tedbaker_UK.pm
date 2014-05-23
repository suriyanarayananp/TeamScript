#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Tedbaker_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";  
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Tedbaker_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Tedbaker-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Ted';
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
	my @query_string;
	my $skuflag = 0;my $imageflag = 0;
	if($product_object_key)
	{
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$url3='http://www.tedbaker.com/uk/'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = get_content($url3);
		
		my ($brand,$product_id,$description,$prod_detail,$price_text,$product_name); 
		
		
		#Getting Product id
		if ( $content2 =~ m/product_code\s*\:\s*\"([^>]*?)\-/is )
		{
			$product_id = &DBIL::Trim($1);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id,$product_object_key,$dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#Getting product name
		if ( $content2 =~ m/<hgroup>\s*([\w\W]*?)<\/hgroup>/is )
		{
			$product_name = &DBIL::Trim($1);
		}
		#Getting Product description
		if ( $content2 =~ m/<p\s*class\=\"description\">([^<]*?)<\/p>/is )
		{
			$description = &clear(&DBIL::Trim($1));
		}
		#Getting product detail
		if ( $content2 =~ m/<div\s*id=\"product_details\">([\w\W]*?)<\/div>/is )
		{
			$prod_detail = $1;
			$prod_detail=~s/^Details\s*//igs;
			$prod_detail=~s/<li>/-/igs;
			$prod_detail = &clear(&DBIL::Trim($prod_detail));
		}
		#Getting product price Text
		if ( $content2 =~ m/(?:<li\s*class\=\"price\s*previous\">\â?([\w\W]*?)<\/li>)?\s*<li\s*class="price\s*unit">\s*\â?([^<]*?\d)\s*<\/li>/is )
		{
			my $v1=$1;
			my $v2=$2;
			$v1=~s/[^>]*?\£/£/is;
			$v2=~s/[^>]*?\£/£/is;
			$price_text = &DBIL::Trim("$v1 ". "$v2");
		}
		
		###Getting product Sku&Image details###
		my $i=0;
		my $color_block_11 = '"'."href=$url3".'"';
		my $swcode;
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);

		my $nex_swa;
		if ( $content2 =~ m/<div\s*class=\"colours_switch\">([\W\w]*?)<\/div>/is )                    ##To take details of Next Swatch 
		{
			$nex_swa=$1;
		}
		
		if($color_block_11=~m/href=[^>]*?\/\s*p\s*\/\s*([^\"]*?)\s*\"/is)                              ##Getting Swatch Code from Url to get details 
		{
			$swcode=$1;
			goto Swatch;
		}
		
Swatch:
		
		my $color_url="http://www.tedbaker.com/uk/json/product/getProduct.json?productCode=$swcode";   ##Appending each Swatch Code to get details
		my $color_block = get_content($color_url);
		my ($price,$out_of_stock,$color,@color,$size);
		my $count;
		
		while($color_block =~ m/((?:\[\s*| \}\,)\s*\{\s*\"range\"[\W\w]*?\"size\"\s*\:\s*\"[^\"]*?\"?\s*\")/igs)   
		{	
			my $color_block_size=$1;   																	## Block to get the Product Details(Sku & Image)
			my $count=0;
			
			if($color_block_size =~ m/\"pricetype\"\s*\:\s*\"buy\"\s*\,\s*\"value\"\s*\:\s*[\d\.]*\,\s*\"formattedvalue\"\s*\:\s*\"\W*\£(\d+)\.\d+\"[^>]*?\"/is )
			{
				$price = &DBIL::Trim($1);
			}
			if($color_block_size =~ m/\"colourname\"\s*\:\s*\"([^\"]*?)\"/is )
			{
				$color = &DBIL::Trim($1);
			}
			if($color_block_size =~ m/\"size\"\s*\:\s*\"([^<]*?)\s*\\?\s*(")?\s*\"/is )
			{
				$size = $1.$2;
			}
			if($color_block_size =~ m/\"purchasable\"\s*\:\s*([^\"]*?)\,/is )
			{
				$out_of_stock 	= &DBIL::Trim($1);
				$out_of_stock=~s/^\s*false\s*$/y/ig;
				$out_of_stock=~s/^\s*true\s*$/n/ig;
			}
			$price='null' if($price eq '' or $price eq ' ');
			
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			push(@query_string,$query);			
			if($count==0)
			{
				$sku_objectkey{$sku_object}=$color;
				$count++;
			}
		}
		
		##Taking main image
		if ( $color_block =~ m/\"galleryindex"\s*\:\s*0\,\s*\"seoname\"\s*\:\s*\"[^\"]*?\"\s*\,\s*\"url\"\s*\:\s*\"([^\"]*?)\"/is )
		{
			my $imageurl = &DBIL::Trim($1);
			my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=$color;
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
		}
		##Taking alternate image
		while ( $color_block =~ m/\"galleryindex"\s*\:\s*(?!0)[\d]+\,\s*\"seoname\"\s*\:\s*\"[^\"]*?\"\s*\,\s*\"url\"\s*\:\s*\"([^\"]*?)\"/igs )
		{
			my $altimagecontent = $1;
			
			my ($imgid,$img_file) = &DBIL::ImageDownload($altimagecontent,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$altimagecontent,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=$color;
			$hash_default_image{$img_object}='n';
			push(@query_string,$query);
		}
		
		###Mapping Sku has Image Details
		my @image_obj_keys = keys %image_objectkey;
		my @sku_obj_keys = keys %sku_objectkey;
		foreach my $img_obj_key(@image_obj_keys)
		{
			foreach my $sku_obj_key(@sku_obj_keys)
			{
				if($image_objectkey{$img_obj_key} eq $sku_objectkey{$sku_obj_key})
				{
					my $query=&DBIL::SaveSkuhasImage($sku_obj_key,$img_obj_key,$hash_default_image{$img_obj_key},$product_object_key,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					push(@query_string,$query);
				}
			}
		}
		
		while ( $nex_swa =~ m/<a[^>]*?href=[^>]*?(?:\&\#x2f\;|\/)\s*p\s*(?:\&\#x2f\;|\/)\s*([^\"\']*?)\s*(?:\"|\')[^>]*?>/igs)  ##To get Next swatch Image Details
		{
			$swcode=$1;
			goto Swatch;
		}
		
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
ENDOFF:		
		$dbh->commit();
	}
}1;

#Function to Remove Special Characters
sub clear()
{
	my $text=shift;
	
	$text=~s/<li[^>]*?>/*/igs;
	$text=~s/&quot/"/igs;	
	$text=~s/â€™/'/igs;
	$text=~s/â€“/–/igs;
	$text=~s/â€˜/‘/igs;
	$text=~s/â€¦/…/igs;
	$text=decode_entities($text); 	
	return $text;
}
#Function to Get Product Page's Content 
sub get_content
{
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
	 elsif($code=~m/30/is)
	 {
		my $loc=$response->header('location');                
		$loc=decode_entities($loc);    
		my $loc_url=url($loc,$url)->abs;        
		$url=$loc_url;
		goto Repeat;
	 }
	 elsif($code=~m/40/is)
	 {
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
