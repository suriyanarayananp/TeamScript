#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Forever21_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use URI::Escape;
#require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";  # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Forever21_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Forever21-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='For';
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
	my $skuflag = 0;my $imageflag = 0;my $mflag = 0;
	if($product_object_key)
	{
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$product_object_key =~ s/^\s+|\s+$//g;
		my %color_hash;
		$url3='http://www.forever21.com'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = &getcont($url3,"GET","","");
	
		my($view_state,$EVENTVALIDATION)=&view_state_Event_val($content2);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour);
		
		#Getting Product product's id
		if ( $content2 =~ m/Product\s*Code\s*\:[^<]*?(\w[^<]*?)\s*</is )
		{
			my $prod_id=decode_entities($&); 
			$product_id=$1 if($prod_id=~m/Product\s*Code\s*\:[^<]*?(\w[^<]*?)\s*</is);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id,$product_object_key,$dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
			
		#Getting Product price_text &price
		if ( $content2 =~ m/<p\s*class\=\"product\-price\">\s*([\w\W]*?)\s*<\/\s*p>/is )
		{
			$price_text = &DBIL::Trim($1);
			$price=$price_text;
			$price=~s/\$//is;
		}
		elsif($content2=~m/<span\s*itemprop\=\"price\">\s*<p\s*class\=\"was\-now\-price\">\s*([\w\W]*?)\s*<br\s*\/>([\w\W]*?)<\/\s*p>/is)
		{
			$price_text=&DBIL::Trim($1);
			$price=&DBIL::Trim($2);
			$price_text=$price_text."-".$price;
			$price=~s/now\s*\:|\$//igs;
		}
		#Getting Product name
		if ( $content2 =~ m/<h1\s*class\=(?:\"|\')[^<]*?product\-title(?:\"|\')\s*>\s*([\w\W]*?)\s*<\/h1>/is )
		{
			$product_name = &clean(&DBIL::Trim($1));
		}
		#Getting Product brand 
		if($content2=~m/(?:MainContent_)?hdBrand\"\s*value\=\"([^\"]*?)\"\s*/is)
		{
			$brand=$1;
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		my $cat_name;
		if($content2=~m/(?:MainContent_)?hdCategoryName\"\s*value\=\"([^\"]*)\"/is)
		{
			$cat_name=$1;
		} 
		my $item_code;
		if($content2=~m/(?:MainContent_)?hdItemCode\"\s*value\=\"([^\"]*)\"/is)
		{
			$item_code=$1;
		}
		my $hdProductSKU;
		if($content2=~m/hdProductSKU\"\s*value\=\"([^\"]*?)\"/is)
		{
			$hdProductSKU=$1;
		}
		#Getting Product description data
		if($content2=~m/class\=(?:\"|\')\s*(?:simpleTabsContent|productdesc)\s*(?:\"|\')>\s*([\w\W]*?)\s*<[^>]*?>\s*DETAILS\s*\:\s*<[^>]*?>\s*([\w\W]*?)\s*<\/div>/is)
		{
			$description=&clean($1);
			$prod_detail=&clean($2);
			
			$prod_detail=~s/<li>/-/igs;	
			 
			$description=&DBIL::Trim($description);
			$prod_detail=&DBIL::Trim($prod_detail);
			$prod_detail=~s/(?:Model\s*Info|Product\s*Code)[\w\W]*$//igs;	
		}
		elsif($content2=~m/class\=(?:\"|\')\s*(?:simpleTabsContent|productdesc)\s*(?:\"|\')>\s*([\w\W]*?)\s*<\/p>\s*<ul>\s*<li>([\w\W]*?)\s*<\/div>/is)
		{	
			$description=&clean($1);
			$prod_detail=&clean($2);		
			
			$prod_detail=~s/<li>/-/igs;
			
			$description=&DBIL::Trim($description);
			$prod_detail=&DBIL::Trim($prod_detail);	
			$prod_detail=~s/(?:Model\s*Info|Product\s*Code)[\w\W]*$//igs;
		}	
		
		##Getting Product Image & Sku Details
		my $reg_1='<option\s*[^>]*?\s*value\=\"('.$item_code.'[^\"]*)\"\s*>\s*([\w\W]*?)\s*<\/\s*option>';
		while($content2=~m/$reg_1/igs)
		{	
			my $colr_data=$1;
			my $color=$2;
			
			my $colr_ids=(split('\|',$colr_data))[0];
			
			$color_hash{$colr_ids}=[$color,uri_escape($colr_data)];
		}
	
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key,$color_cont,$color_cont1,$color_cont_img,@color_cont_img);	
	
		if($content2=~m/largeimage\s*\:\s*\'([^\']*?)\'\s*\}/is)    ##If Content matches with largeimage for getting Images(Scenario 1)
		{
			foreach my $color_id (sort{$a<=>$b} keys %color_hash)
			{
				my $color_code;
				if($color_id=~m/[\w\W]*?\-([\w\W]*)/is)
				{
					$color_code=$1;
				}
				
				my $id_s=(split('\|',$color_hash{$color_id}[1]))[-2];
				
				my $post_content='ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage&ctl00%24MainContent%24hdBrand='.$brand.'&ctl00%24MainContent%24hdCategoryName='.$cat_name.'&ctl00%24MainContent%24hdProductId='.$product_id.'&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode='.$item_code.'&ctl00%24MainContent%24hdRepColorCode='.$color_code.'&ctl00%24MainContent%24dlColorChart%24ctl00%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24dlColorChart%24ctl01%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24ddlColor='.$color_hash{$color_id}[1].'&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='.$view_state.'&__ASYNCPOST=true&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.x=9&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.y=6';
				#Forming Page's Post Content
							
				my $content_3 = &getcont($url3,"POST",$post_content,"$url3");
				
				($view_state,$EVENTVALIDATION)=&view_state_Event_val($content_3);
				
				my $img_count=0;
				
				while($content_3=~m/largeimage\s*\:\s*\'([^\']*?)\'\s*\}/igs)  #Getting Image Urls
				{
					my $final_img_url=$1;
					my $img_cont = &image_validate($final_img_url,"GET","","");
					my $count=1;
					
					next if($img_cont==0);
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($final_img_url,'product',$retailer_name);
					
					if($img_count==0)
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_img_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$color_id;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
					else
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_img_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$color_id;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
					$img_count++;
				}
				#Getting size for each color
				if($content_3=~m/>\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
				{
					my $size_block=$1;
					my $size_count=0;
					
					while($size_block=~m/<option\s*[^>]*value\=\"[^\"]*\">\s*([\w\W]*?)\s*<\/option>/igs)
					{
						my $size=$1;
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');

						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color_hash{$color_id}[0],$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$color_id;
						push(@query_string,$query);
						
						$size_count++;
					}
					if($size_count==0)
					{
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'',$color_hash{$color_id}[0],$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$color_id;
						push(@query_string,$query);
					}
				}
				#Getting swatch image url
				while($content2=~m/imgColorImage\"\s*src\=\"([^\"]*?(?:(\d{2})\s*\.\s*jpg)?)\s*\"/igs) 
				{
					my $final_sw_img_url=$1;
					my $sw_clr_code=$2;
					
					if($sw_clr_code eq $color_code)
					{
						my $sw_img_cont = &image_validate($final_sw_img_url,"GET","","");
								
						next if($sw_img_cont==0);
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($final_sw_img_url,'swatch',$retailer_name);
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_sw_img_url,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$color_id;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
			}	
		}
		elsif($content2=~m/<div[^>]*?id\s*\=\s*(?:\"|\')\s*imageBoxInside\s*(?:\"|\')[^>]*?>([\w\W]*?)<\/div>/is)   ##If  Content matches with imageBoxInside for getting Images(url differs with "product_pop.aspx") (Scenario 2)
		{
			if($content2=~m/<div\s*id\s*\=\s*\"\s*upColorChart\s*\"\s*>([\w\W]*?)<\/div>/is)                        ##Block for taking Color details
			{
				my $blk=$1;
				
				while($blk=~m/<td[^>]*?>\s*<input[^>]*?id\s*\=\s*\"([^>]*?)\s*\"\s*src\s*\=\s*\"[^<]*?\-([^<]*?)\s*\.\s*jpg[^>]*?>/igs)
				{
					my $color_cont=$1;
					my $color_code=$2;
					
					$color_cont=~s/_/%24/igs;
					
					my $post_content='ScriptManager1=upColorChart%7CdlColorChart%24ctl03%24imgColorImage&hdBrand='."$brand".'&hdCategoryName='."$cat_name".'&hdProductId='."$product_id".'&hdVariantId=&hdItemCode='."$hdProductSKU".'&hdRepColorCode=04&rpButtonImageList%24ctl00%24hdIdx=0&rpButtonImageList%24ctl00%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl01%24hdIdx=1&rpButtonImageList%24ctl01%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl02%24hdIdx=2&rpButtonImageList%24ctl02%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl03%24hdIdx=3&rpButtonImageList%24ctl03%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl04%24hdIdx=4&rpButtonImageList%24ctl04%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl05%24hdIdx=5&rpButtonImageList%24ctl05%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl06%24hdIdx=6&rpButtonImageList%24ctl06%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&dlColorChart%24ctl00%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl01%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl02%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl03%24hdProductSKU='."$hdProductSKU".'&ddlColor='."$hdProductSKU"."-$color_code".'%7Clarge%7C0%7C'."$color_code".'&ddlQty=1&ddlSize=&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='."$view_state".'&__ASYNCPOST=true&'."$color_cont".'.x=18&'."$color_cont".'.y=13';
					#Forming Page's Post Content
					
					my $content_3 = &getcont($url3,"POST",$post_content,"$url3");
					
					if($content_3=~m/<div[^>]*?id\s*\=\s*(?:\"|\')imageBoxInside(?:\"|\')[^>]*?>([\w\W]*?)<\/div>/is)#Getting Image Urls
					{
						my $blk1=$1;
						my $img_count=0;
						
						while($blk1=~m/<img[^>]*?src\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/igs)
						{
							my $final_img_url=$1;
							$final_img_url=~s/_58/_330/igs;
							
							my $img_cont = &image_validate($final_img_url,"GET","","");
							
							next if($img_cont==0);
						
							my ($imgid,$img_file) = &DBIL::ImageDownload($final_img_url,'product',$retailer_name);
							
							if($img_count==0)
							{
								my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_img_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$imageflag = 1 if($flag);
								$image_objectkey{$img_object}=$color_code;
								$hash_default_image{$img_object}='y';
								push(@query_string,$query);
							}
							else
							{
								my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_img_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$imageflag = 1 if($flag);
								$image_objectkey{$img_object}=$color_code;
								$hash_default_image{$img_object}='n';
								push(@query_string,$query);
							}
							$img_count++;
						}
					}
				
				#Getting color
				my $color=$1 if($content_3=~m/<option[^>]*?selected\s*\=\s*\"selected\s*\"\s*[^>]*?>([^<]*?)</is);
					
				#Getting size
				if($content_3=~m/>\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
				{
					my $size_block=$1;
					my $size_count=0;
					
					while($size_block=~m/<option\s*[^>]*value\=\"[^\"]*\">\s*([\w\W]*?)\s*<\/option>/igs)
					{
						my $size=$1;
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$color_code;
						push(@query_string,$query);
						
						$size_count++;
					}
					if($size_count==0)
					{
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$color_code;
						push(@query_string,$query);
					}
				}
				#Getting swatch image url
				while($content2=~m/imgColorImage\"\s*src\=\"([^\"]*?(?:(\d{2})\s*\.\s*jpg)?)\s*\"/igs) 
				{
					my $final_sw_img_url=$1;
					my $sw_clr_code=$2;
					
					if($sw_clr_code eq $color_code)
					{
						my $sw_img_cont = &image_validate($final_sw_img_url,"GET","","");
								
						next if($sw_img_cont==0);
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($final_sw_img_url,'swatch',$retailer_name);
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$final_sw_img_url,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$color_code;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
			}
		}
	}
	#Mapping Sku and Image Objectkeys
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
ENDOFF:	
	$dbh->commit();
	}
}1;

#Function to remove Special Characters and replacing decode entities
sub clean()
{
	my $text=shift;
	
	$text=decode_entities($text); 
	$text=~s/&eacute;/é/is;
	$text=~s/Â//igs;	
	$text=~s/&trade;/™/igs;	
	return $text;
}
#Function to get Product Page's Content
sub getcont()
{
    my($url,$method,$cont,$ref,$extra)=@_;
	my $iterr=0;
	Home:
	my $request=HTTP::Request->new("$method"=>$url);
	if($ref ne '')
    {
           $request->header("Referer"=>"$ref");
    }
    if(lc $method eq 'post')
    {
           $request->content($cont);
    }
	$request->header("Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8");
	$request->header("Host"=>"www.forever21.com");
	
	if($extra ne '')
	{
		$request->header("X-Requested-With"=>"$extra");
	}
	
    my $res=$ua->request($request);
	
    $cookie->extract_cookies($res);
    $cookie->save;
    $cookie->add_cookie_header($request);
    my $code=$res->code;
	if($code==200)
    {
       my $content=$res->content();
	   return $content;
	}
    elsif($code=~m/50/is)
    {
		if($iterr==3)
		{
			return;
		}
        $iterr++;
        goto Home;
	}
    elsif($code=~m/30/is)
    {
		my $loc=$res->header("Location");
		$url=url($loc,$url)->abs();
		my $content=getcont($url,"GET","","");
		return $content;
		
    }
    elsif($code=~m/40/is)
    {
        if($iterr==3)
		{
			return;
		}
        $iterr++;
        goto Home;
    }
}
#Function to get page's view state and Event validation values for post content  
sub view_state_Event_val
{
	my $cont=shift;
	my($view_state,$EVENTVALIDATION);
	if($cont=~m/VIEWSTATE\"\s*value\=\"([^~]*?)\"/is)
	{
		$view_state=uri_escape($1);
	}
	elsif($cont=~m/__VIEWSTATE\|([\w\W]+?)\|/is)
	{
		$view_state=uri_escape($1);
	}
	if($cont=~m/EVENTVALIDATION\"\s*value\=\"([^~]*?)\"/is)
	{
		$EVENTVALIDATION=uri_escape($1);
	}
	elsif($cont=~m/EVENTVALIDATION\|([\w\W]+?)\|/is)
	{
		$EVENTVALIDATION=uri_escape($1);
	}
	return $view_state,$EVENTVALIDATION;
} 
#Function to check whether image page is valid(By Response code)
sub image_validate()
{
    my($url,$method,$cont,$ref,$extra)=@_;
	my $iterr=0;
	Home:
	my $request=HTTP::Request->new("$method"=>$url);
	if($ref ne '')
    {
           $request->header("Referer"=>"$ref");
    }
    if(lc $method eq 'post')
    {
           $request->content($cont);
    }
	$request->header("Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8");
	if($extra ne '')
	{
		$request->header("X-Requested-With"=>"$extra");
	}
	my $res=$ua->request($request);
	$cookie->extract_cookies($res);
    $cookie->save;
    $cookie->add_cookie_header($request);
    my $code=$res->code;
	if($code==200)
    {
       my $content=$res->content();
	   return 1;
	}
    else
    {
        return 0;
    }
}
