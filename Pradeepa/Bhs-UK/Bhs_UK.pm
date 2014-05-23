#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Bhs_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie,$nowpriceflag);
sub Bhs_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Bhs-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Bhs';
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
	my $skuflag = 0;my $imageflag = 0;my $mflag=0;$nowpriceflag=0;
	if($product_object_key)
	{
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		
		$url3='http://www.bhs.co.uk/'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = get_content($url3);
			
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color,$temp,$color1,$product_id1,$Item_code,%dupliUrl);
		
	    #If Product Page Doesnot have product Details (Error Page)
		if(($content2 =~ m/<h1>\s*We\s*couldn\s*(?:\'|o)\s*t\s*find\s*the\s*page\s*you\s*[^<]*?</is)||($content2 =~ m/<h1>\s*Error\s*Page\s*Exception[^<]*?</is)||($content2 =~ m/<h1>\s*An\s*error\s*has\s*occurred[^<]*?</is))
	    {
		  goto PNF;
	    }
		
		#Getting Multiple Product Items			
		 if($content2 =~ m/<div\s*class=\"bundle_display_product([^<]*?)\">/is)
		 {
			 $mflag=1;
			 goto PNF;
		 }
		
		#Itemcode
		if($content2 =~ m/>\s*Item\s*code\s*\:[^>]*?(?:\s*<[^>]*?>\s*)+\s*([^<]*?)</is)
		{
			$Item_code=$1;
		}
		
		#Product id	
		if($content2 =~ m/STYLE_CODE\s*\:\s*(?:\"|\')\s*([^\"\']*?)\s*(?:\"|\')/is)   ##Taking STYLE_CODE as product_id
		{
			$product_id=$1;
			# my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id,$product_object_key,$dbh,$robotname,$retailer_id);
			# goto ENDOFF if($ckproduct_id == 1);
			# undef ($ckproduct_id);
		}
		elsif($Item_code)
		{
			$product_id = substr($Item_code,0,5);                                     ##Taking product_id from Item_code if no STYLE_CODE
			# my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id,$product_object_key,$dbh,$robotname,$retailer_id);
			# goto ENDOFF if($ckproduct_id == 1);
			# undef ($ckproduct_id);
		}
		
		# if($content2 =~ m/>\s*Colour\s*\:\s*(?:[^>]*?(?:\s*<[^>]*?>\s*)+\s*)?([^<]*?)\s*</is)
		# {
			# $color1=$1;
		# }
		
		###To remove Duplicates By Item_code and Color
		# if(lc($dupliUrl{$Item_code}) eq lc($color1))
		# {
			#skip if same style code,same color
			# my $ckproduct_id = DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
			# next if($ckproduct_id == 1);
			# undef ($ckproduct_id);
		# }
		# else
		# {
			# $dupliUrl{$Item_code}=$color1;	
		# }
		###############################
		#Getting Price Text and Color
		if ( $content2 =~ m/<ul\s*class\=\"product_summary">\s*<li[^>]*?>\s*([\w\W]*?)\s*<li\s*class\=\"product_colour\"\s*>Colour\s*\:\s*[^>]*?<span>\s*([\w\W]*?)\s*</is )
		{
			$price_text=&DBIL::Trim($1);
			$color = &DBIL::Trim($2);
		}
		#product_name
		if ( $content2 =~ m/<h1[^>]*?>\s*([\w\W]*?)\s*<\/h1>/is )
		{
			$product_name = &clear(&DBIL::Trim($1));
		}
		#price
		if($content2 =~ m/product_price\s*\"\s*>\s*Price\s*\:[^>]*?(?:\s*<[^>]*?>\s*)+\s*[^<]*?(\d[^<]*?)</is)
		{
			$price=$1;
		}
		elsif($content2 =~ m/\"\s*now_price\s*product_price[^>]*?>\s*Now\s*\W*(?:[^>]*?(?:\s*<[^>]*?>\s*)+\s*[^>]*?)?(\d[^>]*?)</is)
		{
			$price=$1;
			$nowpriceflag=1;
		}
		elsif($content2 =~ m/product\s*Discount[^<]*?(?:\s*<[^>]*?>\s*)+\s*Now[^<]*?(\d[^<]*?)</is)
		{
			$price=$1;
			$nowpriceflag=1;
		}
		elsif($content2 =~ m/>\s*now\s*(?:Price\s*\:)?[^>]*?(?:\s*<[^>]*?>\s*)+\s*[^<]*?(\d[^<]*?)</is)
		{
			$price=$1;
			$nowpriceflag=1;
		}
		#Getting "Was Price" and "Offer Price"
		my ($was_price1,$off_price1);
		
		if($content2 =~ m/\"\s*was_price\s*product_price[^>]*?>\s*Was\s*\W*(?:[^>]*?(?:\s*<[^>]*?>\s*)+\s*[^>]*?)?(\d[^>]*?)</is)
		{
			$was_price1=$1;
		}
		
		if($content2 =~ m/product\s*Discount[^<]*?(?:\s*<[^>]*?>\s*)+\s*\s*([^<]*?\s*off)\s*</is)
		{
			$off_price1=$1;
		}
		
		#Brand
		if ( $content2 =~ m/productAttributes\s*\:[^>]*?SHOP_BY_BRAND[^>]*?\:\"([\w\W]*?)\"\s*[^>]*?}/is )
		{
			$brand = &DBIL::Trim($1);
			$brand =~ s/\\\'/\'/igs;
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',lc($brand),$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#Product Description & Product Detail
		if($content2 =~ m/<p\s*class\=\"product_description\"(>[\w\W]*?)<div[^>]*?class\s*\=\s*\"\s*cms_content\s*"/is)
		{
			$description=$&;
			
				if($description=~m/>([\w\W]*)<\/p>(?:(?:\s*<[^>]*?>\s*)+\s*)?<[^>]*class\s*=\s*\"\s*product_description\s*\"[^>]*?>([\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
				elsif($description=~m/>([\w\W]*?)<ul[^>]*?>\s*([\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
				elsif($description=~m/>([^<]*)(?:(?:\s*<[^>]*?>\s*)+\s*)?<\/p>\s*<p[^>]*?>\s*<span[^>]*?>\s*([\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
				elsif($description=~m/>([\w\W]*)<span[^>]*?>\s*([\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
				elsif($description=~m/>([\w\W]*)<\/p>\s*<p[^>]*?>\s*(\w[\w\W]*<(?:br\s*\/|li|span|p)>[\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
				elsif($description=~m/>([\w\W]*?)<br\s*\/?\s*>\s*([\w\W]*)<div/is)
				{
					$description =$1;
					$prod_detail =$2;
				}
			
			$prod_detail=~s/^\s*<li[^>]*?>//igs;
			$prod_detail=~s/<li[^>]*?>/-/igs;
			$prod_detail=~s/<br\s*\/?>/-/igs if($prod_detail!~m/-/is);		
			$prod_detail=~s/<span[^>]*?>/-/igs if($prod_detail!~m/-/is);		
			$description=~s/^\s*<li[^>]*?>//igs;
			$description=~s/<li[^>]*?>/-/igs;
			
			$prod_detail = &DBIL::Trim($prod_detail);
			$description = &DBIL::Trim($description);
			
			if(($description eq "")&&($prod_detail ne ""))
			{
				$description=$prod_detail;
			}
			
			$description=~s/<div[^>]*?$//igs;
			$description=&clear($description);
			$prod_detail=&clear($prod_detail);
		}
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@image_object_key,@sku_object_key,@string);	
		#Getting Size & Out of stock
		my $size1;
		if($content2 =~ m/var\s*productData([\w\W]*?)<\/script>/is) ###Price according to Size
		{
			my $blk=$1;
			
			if($blk=~m/s*size\s*\:[^\}]*?\}/is)
			{
				while($blk=~m/{\s*size\s*\:[^\}]*?\}/igs)
				{
					my $blk1=$&;
					
					if($blk1=~m/size\s*\:\s*(?:\"|\')\s*([^\"\']*?)\s*(?:\"|\')/igs)
					{
						$size1=$1;
					}
					if($blk1=~m/now\s*price\s*\:\s*([^\}]*?)\s*(?:\,|\})/is)
					{
						$price=$1;
						$price_text=&price_text($price,$was_price1,$off_price1);
					}
					if ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is )
					{
						my $size_content = $1;
						while ( $size_content =~ m/<option[^>]*?title\=\"([\w\W]*?)\"[^>]*?>\s*([\w\W]*?)\s*<\/option>/igs )
						{
							my $size 			= &DBIL::Trim($2);
							my $out_of_stock 	= &DBIL::Trim($1);
							$out_of_stock=~s/\s*In\s*stock\s*$/n/igs;
							$out_of_stock=~s/\s*Low\s*stock\s*$/n/igs;
							$out_of_stock=~s/\s*Out\s*of\s*stock\s*$/y/igs;
							$out_of_stock=~s/^\s*$/y/igs;
							$price='null' if($price eq '' or $price eq ' ');
							
							# Matching Size1 and size to get the corresponding Out of stock values
							if($size1 eq $size)
							{
								my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$skuflag = 1 if($flag);
								$sku_objectkey{$sku_object}=$color;
								push(@query_string,$query);
							}
						}
					}
				}
			}
			else
			{
				if($content2 =~ m/item_out_of_stock\s*(?:\"|\')\s*>[^>]*?this\s*item\s*is\s*out\s*of\s*stock/is)
				{
					$out_of_stock='y';
				}
				my $price_text=&price_text($price,$was_price1,$off_price1);
				
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,' ',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$color;
				push(@query_string,$query);
			}
		}
		elsif ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is )
		{
			my $size_content = $1;
			while ( $size_content =~ m/<option[^>]*?title\=\"([\w\W]*?)\"[^>]*?>\s*([\w\W]*?)\s*<\/option>/igs )
			{
				my $size 			= &DBIL::Trim($2);
				my $out_of_stock 	= &DBIL::Trim($1);
				$out_of_stock=~s/\s*In\s*stock\s*$/n/igs;
				$out_of_stock=~s/\s*Low\s*stock\s*$/n/igs;
				$out_of_stock=~s/\s*Out\s*of\s*stock\s*$/y/igs;
				$out_of_stock=~s/^\s*$/y/igs;
				$price='null' if($price eq '' or $price eq ' ');
				
				$price_text=&price_text($price,$was_price1,$off_price1);
				
				if(($size1 eq $size)||$out_of_stock)
				{
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$color;
					push(@query_string,$query);
				}
			}
		}
		else  
		{
			if($content2 =~ m/item_out_of_stock\s*(?:\"|\')\s*>[^>]*?this\s*item\s*is\s*out\s*of\s*stock/is)
			{
				$out_of_stock='y';
			}
			$price_text=&price_text($price,$was_price1,$off_price1);
			$price='null' if($price eq '' or $price eq ' ');
				
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,"",$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			$sku_objectkey{$sku_object}='';
			push(@query_string,$query);
		}
		undef $price_text;
		#Getting Main Image & Alternate Images
		if ( $content2 =~ m/<meta\s*property\=\"og\:image\"\s*content\=\"([\w\W]*?)\"\/\s*>/is )
		{
			my $imageurl_det = &DBIL::Trim($1);
			my $imageurl_up = (split('_',$imageurl_det))[0];
			my $imageurl = $imageurl_up."_large.jpg";
			my $image_Domain_url="http://media.bhs.co.uk";
			$imageurl=$image_Domain_url.$imageurl unless($imageurl=~m/^\s*http\:/is);
			my $staus=get_content_status($imageurl);
			
			if($staus!~m/20/is) ##Formation of Image url if Image url ending with "_large" having page error (leads to downloading Issue in Parent Directory)
			{
				$imageurl = $imageurl_det;
				unless($imageurl=~m/^\s*http\:/is)
				{
					$imageurl=$image_Domain_url.$imageurl ;
				}	
			}
			
			#Main Image
			my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=$color;
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
						
			if($content2 =~ /thumbnails:\s*\[([\w\W]*?)\s*\]/is)
			{
			 @string = split(/,/,$1);
			}
			foreach my $count ( 2 .. $#string+1)
			{
				#Alternate Image urls
				my $imageurl1 = $imageurl_up."\_$count\_large.jpg";
				$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is);
				my $staus=get_content_status($imageurl1);
				
				if($staus!~m/20/is) ##Formation of Image url if Image url ending with "_large" having page error (leads to downloading Issue in Parent Directory)
				{
					$imageurl1 = $imageurl_up."\_$count\_normal.jpg";;
					$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is);
				}
				
				my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl1,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl1,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$color;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
		}
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
		
		if(($description eq '') or ($description eq ' '))
		{
			$description=' ';
		}
		if(($prod_detail eq '') or ($prod_detail eq ' '))
		{
			$prod_detail=' ';
		}
		
PNF:
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id,$mflag);
		push(@query_string,$query1);
		push(@query_string,$query2);
		#my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		#push(@query_string,$qry); 
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
ENDOFF:
		$dbh->commit();	
	}
}1;

# Function to form Price Text from Price including "was price" and "off price"
sub price_text()
{
	my $pt=shift;
	my $was_price=shift;
	my $off_price=shift;
	my $price_text1;
	
	if(($was_price)&&($off_price))
	{
		if($nowpriceflag)
		{
			$price_text1= "Now".'£'."$pt"."-"."Was".'£'."$was_price"."-"."$off_price";
		}
		else
		{
			$price_text1='£'."$pt"."-"."Was".'£'."$was_price"."-"."$off_price";
		}
	}
	elsif($was_price)
	{
		if($nowpriceflag)
		{
			$price_text1="Now".'£'."$pt"."-"."Was".'£'."$was_price";
		}
		else
		{
			$price_text1='£'."$pt"."-"."Was".'£'."$was_price";
		}
	}
	elsif($off_price)
	{
		if($nowpriceflag)
		{
			$price_text1="Now".'£'."$pt"."-"."$off_price" ;
		}
		else
		{
			$price_text1='£'."$pt"."-"."$off_price" ;
		}
	}
	else
	{
	      $price_text1='£'."$pt";
	}
	
	return $price_text1;
}

# Function to remove Encoding Characters and decoding Entities
sub clear()
{
	my $text=shift;
	$text=decode_entities($text);	
	$text=~s/Â//igs;
	$text=~s/Â®/®/igs;
	return $text;
}

#Function to get Page Content
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
#Function to get Page's Status Code
sub get_content_status
{
	my $url = shift;
	my $rerun_count=0;
	Home:
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp\;//g;
	my $req = HTTP::Request->new(GET=>"$url");
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
	$req->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	if($code =~m/20/is)
	{
	 return $code;
	}
	else
	{
	   if ( $rerun_count <= 1 )
	   {
			$rerun_count++;
			goto Home;
	   }
	}
}
