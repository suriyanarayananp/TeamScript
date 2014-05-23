#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Topshop_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm";  # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";  
###########################################

####Variable Initialization##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
my $robotname_detail=$robotname;
my $robotname_list=$robotname;
$robotname_list =~ s/\-\-Detail/--List/igs;
$retailer_name =~ s/\-\-Detail\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Tou';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
###########################################

############Proxy Initialization#########
my $country = $1 if($robotname =~ m/\-([A-Z]{2})\-\-/is);
&DBIL::ProxyConfig($country);
###########################################
my $count=1;
##########User Agent######################
my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;
###########################################

############Cookie File Creation###########
my ($cookie_file,$retailer_file) = &DBIL::LogPath($robotname);
my $cookie = HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
$ua->cookie_jar($cookie);
###########################################

############Database Initialization########
my $dbh = DBIL::DbConnection();
###########################################

my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Topshop_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Topshop-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Tou';
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
		my $skuflag = 0;
		my $imageflag = 0;
		my $mflag = 0;
		$url3 =~ s/^\s+|\s+$//g;
		$product_object_key =~ s/^\s+|\s+$//g;
		$url3='http://us.topshop.com/en/tsus/product/'.$url3 unless($url3=~m/^\s*http\:/is);
		my ($status,$url_redirect,$itempurl,$content2,$MainId_to_Match);
		($status,$url_redirect) = get_content_status($url3);
		
		if($url_redirect=~m/searchTerm/is) #Match to Get Redirected Url
		{
			my $content_redirected = get_content($url_redirect);  #Content of the Redirected Url having Multiple Products 
			
			if($content_redirected=~m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is) #ID to match the Required Product from the Redirected Page (Redirected Page Having Multiple Products)
			{
				$MainId_to_Match=$1;
				$MainId_to_Match=~s/^TS//igs;
			}
			
			while($content_redirected=~m/<li\s*class\s*\=\s*\"\s*product_image\s*\"\s*>\s*<a[^>]*?href\s*\=\s*\"([^>]*?)\s*\"[^>]*?>/igs) #Getting Each Product urls in the  Redirected Page
			{
				my $Id_to_Match_url=$1; 
				my $content_Match_cont = get_content($Id_to_Match_url);
				if($content_Match_cont=~m/<li\s*class\=\s*\"product_code\"\s*>\s*Item\s*code\s*\:[^>]*?<[^<]*?>([^<]*?)</is)
				{
					my $Id_to_Match=$1;  ##ID's of the Products in Redirected Page
					if($MainId_to_Match eq $Id_to_Match) ##To get Required Product content from the Redirected Page
					{
						$content2=$content_Match_cont;
					}
				}				
			}
		}
		else
		{
		  $content2 = get_content($url3);
		}
		
		if($content2=~m/<body\s*id\s*\=\s*\"\s*cmd_bundledisplay\s*\"\s*>/is)
		{
			$mflag=1;
		}
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color,$clr);
		#Getting productID
		if($mflag)
		{
			if($content2 =~ m/product_view\s*\"\s*>\s*(?:\s*<[^>]*?>\s*)*<a[^>]*?href\s*\=\s*(?:\"|\')[^\"\']*?\/\s*catalog\s*\/([^\"\']*?\d{1,2})[^\"\']*?(?:\"|\')/is)
			{
				$product_id = &DBIL::Trim($1);
			}
		}
		elsif ( $content2 =~ m/<li\s*class\=\s*\"product_code\"\s*>Item\s*code\s*\:[^>]*?<span>([\w\W]*?)<\/span>/is )
		{
			$product_id = &DBIL::Trim($1);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
			goto LAST if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#Getting price text & price
		if ( $content2 =~ m/<li\s*class\=\s*\"product_price\"\s*>\s*Price\s*\:\s*[^>]*<[^>]*?>\s*([^<]*?)\s*</is )
		{
			$price_text=&DBIL::Trim($1);
			$price_text=~s/Now/, Now/igs;	
			
			if ($price_text =~ m/([\d\.]+)/is )
			{
				$price = $1;
			}
		}
		if($price_text eq "")
		{
			if ( $content2 =~ m/\->\s*<li\s*class\=\s*\"[^<]*product_price\"\s*>\s*([\w\W]*?)\s*<li\s*class=\"product_colour\"/is )
			{
				$price_text=&DBIL::Trim($1);
			
				if ($price_text =~ m/Now[^<]*?(?:<[^>]*?>)*[^<]*?([\d\.]+)$/is )
				{
					$price = $1;
				}
				$price_text=~s/Now/, Now/igs;
				$price_text=~s/&pound;/£/igs;
			}
		}
		if($mflag)  ##Price for Multiple Product
		{
			if($content2 =~ m/<p\s*id\s*\=\s*\"\s*buy_bundle\s*\"\s*>([\w\W]*?)<\/p>/is)
			{
				$price_text = &DBIL::Trim($1);
				$price_text=~s/&pound;/£/igs;
				
				if($price_text=~m/(\d[^<]*)/is)
				{
					$price = $1;
				}
			}
		}
		#Getting product name
		if ( $content2 =~ m/<h1[^>]*?>\s*([\w\W]*?)\s*<\/h1>/is )
		{
			$product_name = &DBIL::Trim($1);
			#Brand
			if($product_name=~m/\s+BY\s+([^<]*)$/is)
			{
				$brand=$1;
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#Getting Product Description & Product_Detail
		if ( $content2 =~ m/<p\s*class\=\"product_description\">\s*([\w\W]*?)\s*<\/p>/is ) 
		{
			$description = &DBIL::Trim($1);
			$prod_detail = &DBIL::Trim($2);
		}
		#Getting Product Description & Product_Detail for Multiple Product
		if($mflag) 	
		{
			if ( $content2 =~ m/<p\s*(?:class|id)\s*\=\s*\"(?:product|bundle)_description\">\s*([\w\W]*?)\s*<\/p>/is ) 
			{
				$description = &DBIL::Trim($1);
				$prod_detail = &DBIL::Trim($2);
				$description='MULTI-ITEM PRODUCT:'."$description"
			}
		}
		#Getting Product's Colour
		if ( $content2 =~ m/<li\s*class\=\"product_colo(?:u)?r\"\s*>\s*Colo(?:u)?r\s*\:\s*[^>]*?<span>([\w\W]*?)</is )
		{
			$color = &DBIL::Trim($1);
		}
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);	
		#Getting Size & Out_of_stock
		if ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is )
		{
			my $size_content = $1;
			my %size_hash;
			while($size_content=~m/<option\s*value\=(?:\"|\')[^\"\']*?(?:\"|\')\s*title\=(?:\"|\')([^\"\']*?)(?:\"|\')(?:\s*class\=\"[^\"]*?\")?>\s*([^<]*?)\s*<\/option>/igs)
			{
				my $size 			= &DBIL::Trim($2);
				my $out_of_stock 	= &DBIL::Trim($1);
				$out_of_stock=~s/\s*In\s*stock\s*$/n/ig;
				$out_of_stock=~s/\s*Low\s*stock\s*$/n/ig;
				$size_hash{$out_of_stock}=$size;
				
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$color;
				$size_hash{$size}=1;
				push(@query_string,$query);
			}
			while($size_content=~m/<option\s*disabled\s*\=\s*\"\s*disabled\s*\"\s*title\s*\=\s*(?:\"|\')\s*([^\"\']*?)(?:\"|\')\s*[^>]*?>\s*([^<]*?)\s*<\/option>/igs)
			{
				my $size 			= &DBIL::Trim($2);
				my $out_of_stock 	= &DBIL::Trim($1);
				$out_of_stock=~s/\s*Out\s*of\s*stock\s*$/y/ig;
				$out_of_stock=~s/^\s*$/y/igs;
				
				if($size_hash{$size} eq '')
				{
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$color;
					push(@query_string,$query);
				}
			}
		}
		if($mflag)  #out_of_stock for Multiple Product	
		{
			$out_of_stock='n';
			
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			$sku_objectkey{$sku_object}='';
			push(@query_string,$query);
		}
		#Getting MainImage
		if ( $content2 =~ m/<meta\s*property\=\"og\:image\"\s*content\=\"([\w\W]*?)\"\/\s*>/is )
		{
			my $imageurl_det = &DBIL::Trim($1);
			my $imageurl_up = (split('_',$imageurl_det))[0];
			my $imageurl = $imageurl_up."_large.jpg";
			my $image_Domain_url="http://media.topshop.com/";
			($status,$itempurl)=get_content_status($imageurl);
			
			if($status!~m/20/is) ##Formation of Image url if Image url ending with "_large" having page error (leads to downloading Issue in Parent Directory)
			{
				$imageurl = $imageurl_det;
				unless($imageurl=~m/^\s*http\:/is)
				{
					$imageurl=$image_Domain_url.$imageurl ;
				}	
			}
			
			my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=$color;
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
							
			foreach my $count ( 2 .. 5 )
			{
				my $imageurl1 = $imageurl_up."\_$count\_large.jpg";
				($status,$itempurl)=get_content_status($imageurl1);  
				
				if($status!~m/20/is) ##Formation of Image url if Image url ending with "_large" having page error (leads to downloading Issue in Parent Directory)
				{
					$imageurl1 = $imageurl_up."\_$count\_normal.jpg";;
					$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is);
				}
				
				($status,$itempurl)=get_content_status($imageurl1);
				
				if($status == 200)
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl1,'product',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl1,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$color;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);	
				}
			}
		}
		if($mflag)  ##Getting Images for Multiple Product
		{
			if ( $content2 =~ m/product_view\s*\"\s*>\s*(?:\s*<[^>]*?>\s*)*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)(?:\"|\')/is )
			{
				my $imageurl_mul = $1;
				
				my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl_mul,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl_mul,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}='';
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);
			}		
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
		
		PNF:
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id,$mflag);
		push(@query_string,$query1);
		push(@query_string,$query2);
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		LAST:
			$dbh->commit();
	}
}
$dbh->commit();
$dbh->disconnect();
##Getting page Content 
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
##Getting Status code for the page
sub get_content_status
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
	 ####### WRITING LOG INTO /var/tmp/Retailer/$retailer_file #######
	 open JJ,">>$retailer_file";
	 print JJ "$url->$code\n";
	 close JJ;
	 #################################################################
	 if($code=~m/20/is)
	 {
		return $code,$url;
	 }
	 if($code=~m/30/is)
	 {
		my $urlb = $response->base( );
		return $code,$urlb;
	 }
	 elsif($code=~m/40/is)
	 {
	  if($rerun_count <= 1){
	   $rerun_count++;   
	   goto Repeat;
	  }
	  return 1;
	 }
	 else{
	  if($rerun_count <= 1){
	   $rerun_count++;   
	   goto Repeat;
	  }
	  return 1;
	 }
}