#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Hm_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";  # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Hm_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Hm-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Hmu';
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
		$product_object_key =~ s/^\s+|\s+$//g;
		$url3='http://www.hm.com/gb/'.$url3 unless($url3=~m/^\s*http\:/is);
		my %AllColor;
		
		my $content2 = get_content($url3);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color,$main_image_url,$alt_image_url,$swatch_image_url,$price_text1);
		
		#Getting Product id
		$product_id=$1 if($url3=~m/\/\s*product\s*\/([^\?]*?)(?:\?article|$)/is);
		my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
	    goto ENDOFF if($ckproduct_id == 1);
	    undef ($ckproduct_id);
		
		#Getting Product name
		if($content2=~m/<h1[^>]*?>\s*([\w\W]*?)\s*</is)
		{
			$product_name = &DBIL::Trim($1);
			$product_name = &clear($product_name);
		}
		#Getting Product  price_text & price
		if($content2=~m/class\s*\=\s*\"\s*price\s*\"[^>]*?>\s*(?:(?:\s*<[^>]*?>\s*)+\s*)?[^<]*?(\£\s*(\d+[^<]*?))</is)
		{
			my $price_te=$1;
			$price_text=&price($price_te);
			$price = &DBIL::Trim($2);
		}
		
		#Getting Product Brand
		if($content2=~m/productBrandLink\"\s*>\s*([^>]*?)\s*</is)
		{
			$brand = DBIL::Trim($1);
			if($brand!~m/^\s*$/g)
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#Getting Product description & details
		my $description = &clear($1) if($content2=~m/<h2[^>]*?>\s*Description\s*<\/h2>\s*([\w\W]*?)\s*<\/p>/is);
		my $prod_detail = &clear($1) if($content2=~m/<h2[^>]*?>\s*Details\s*<\/h2>\s*([\w\W]*?)\s*<\/p>/is);
		$description = &DBIL::Trim($description);
		$prod_detail = &DBIL::Trim($prod_detail);
	
		###Size color out_of_stock	
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key,$tcolor,$clr,@totalColor,$article,$article_url);	
		if($content2=~m/articles\s*\"\s*\:\s*\{([\w\W]*?)<\/script>/is) #Taking Main Block to get Sku Details
		{
			my $b=$1;
			while($b=~m/(?:\"([^\"\']*?)\"\s*\:\s*\{\s*)?(?:\"|\')\s*description\s*(?:\"|\')\s*\:\s*(?:\"|\')?([^\"\'\,]*?)\s*(?:\"|\')?\s*\,\s*(?:\"|\')\s*variants\s*(?:\"|\')[\w\W]*?\s*(?:\"|\')\s*size\s*Sorted\s*Variants\s*(?:\"|\')/igs)
			{
				$article=$1;
				$color=$2;                                               #Getting Colour 
				my $blk_siz2=$&;                                         #Taking Each Block to get Sku Details for Each Article
				$color='' if($color=~m/\bnull\b/is);
				$article_url=$url3."?article=".$article;				 #Forming url for Sku which is changing according to colou	
				#print "article_url: $article_url\t$color\n";
				####Color Duplication Incremented
				if($AllColor{$color}>0)
				{
					$AllColor{$color}++;		
					my $tcolor = $color.'('.$AllColor{$color}.')';
					push @totalColor,$tcolor;
					$clr=$tcolor;
				}
				else
				{
					 push @totalColor,$color;
					 $AllColor{$color}++;
					 $clr=$color;
				}
				my $tcolor2;
				#########To Change color CASE
				$clr = lc($clr);
				
				while($clr =~ m/([^>]*?)(?:\s+|$)/igs)
				{
				 if($tcolor2 eq '')
				 {
				  $tcolor2 = ucfirst($1);
				 }
				 else
				 {
				  $tcolor2 = $tcolor2.' '.ucfirst($1);
				 }
				}
				while($blk_siz2=~m/\{[^\{]*?\"\s*size\s*\"\s*\:\{\s*\"\s*name\s*"\s*:\s*\"\s*([^\"]*?)\"([^\}]*?\}[^\{]*?\{[^\}]*?\}[^\}]*?\})/igs)
				{
					my $size=&clear($1);
					my $blk_siz=$&;
					
					if($blk_siz=~m/\"\s*sold\s*Out\s*"\s*\:\s*\"?([^\}]*?)\s*(?:\,|\}|\")/is) #\,?\"\s*
					{
						$out_of_stock=$1;
						$out_of_stock = "y" if($out_of_stock eq "true");
						$out_of_stock = "n" if($out_of_stock eq "false");
					}
					
					if($blk_siz=~m/\"\s*price\s*\"\s*\:\s*\"([^\"]*?([0-9][^\"]*?))\s*\"/is)
					{
						my $price_tex1=$1;					
						$price_text1=&price($price_tex1);
						$price = &DBIL::Trim($2);
					}
					
					if($blk_siz=~m/\"\s*old\s*Price\s*\"\s*\:\s*\"\s*([^\"]*?)\s*\"/is)
					{
						my $price_tex = $1;
						$price_text=&price($price_tex);
						$price_text="$price_text1"."-"."$price_text";
					}
					$price='null' if($price eq '' or $price eq ' ');
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					if($color)
					{
						$sku_objectkey{$sku_object}=$color;
					}
					else
					{
						$sku_objectkey{$sku_object}='';
					}
					push(@query_string,$query);
				}
				
				if(($blk_siz2 eq "")&&($color ne ""))
				{
					$price='null' if($price eq '' or $price eq ' ');
					$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' ');
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,' ',$tcolor2,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					if($color)
					{
						$sku_objectkey{$sku_object}=$color;
					}
					else
					{
						$sku_objectkey{$sku_object}='';
					}
					push(@query_string,$query);
				}
			}
		}
		else  #If Main Block Not Available
		{
			$price='null' if($price eq '' or $price eq ' ');
			$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' ');
			
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,' ',' ',$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			$sku_objectkey{$sku_object}='';
			push(@query_string,$query);
		}	
		
		##Images Section
		my ($lin,$image_page,@defclr,@alternate_image,%alter,%dupliUrl);
		
		if($content2=~m/>\s*Colour\s*\:\s*<([\w\W]*?)<\/ul>/is)
		{
			my $blk=$1;
			if($content2=~m/\"\s*productLink\s*\"\s*\:\s*\{\s*\"\s*url\s*\"\s*\:\s*\"\s*([^\"]*?)\s*\"/is)
			{
				$lin=$1;
			}
			
			while($blk=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?(?:\=([^<]*?))?)\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?([^<]*?)\s*</igs)
			{
				my $page_url="$lin"."$1";
				my $Skucode=$2;
				my $default1=$3;
				$default1='' if($default1=~m/\bnull\b/is);
				my $main_image_id;
				
				$image_page=get_content($page_url);
				
				#Getting Main Image Urls
				if($image_page=~m/<li[^>]*?class\s*\=\s*(?:\"|\')\s*fullscreen\s*(?:\"|\')[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/is)
				{
					$main_image_url=$1;
					unless($main_image_url=~m/^http\:/is)
					{
						$main_image_url="http:".$1;
					}
					
					$main_image_id=$1 if($main_image_url=~m/source\s*\[\s*([^<]*?)\]/is);   ###Taking Main Image ID to remove Duplicates
					$main_image_url=~s/\/product\/full/\/product\/large/is;
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($main_image_url,'product','h&m-uk');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$main_image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					if($default1)
					{
						$image_objectkey{$img_object}=$default1;
					}
					else
					{
						$image_objectkey{$img_object}='';
					}
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);					
				}
				elsif($image_page=~m/\"\s*product\-image[^\"]*?\"[^>]*?>\s*<img[^>]*?src\=\"\s*([^\"]*?)\"[^>]*?>/is)
				{
					$main_image_url=$1;
					unless($main_image_url=~m/^http\:/is)
					{
						$main_image_url="http:".$1;
					}
					
					$main_image_id=$1 if($main_image_url=~m/source\s*\]\s*\,value\[([^<]*?)\]\&/is);   ###Taking Main Image ID to remove Duplicates
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($main_image_url,'product','h&m-uk');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$main_image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					if($default1)
					{
						$image_objectkey{$img_object}=$default1;
					}
					else
					{
						$image_objectkey{$img_object}='';
					}
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);
				}
				##Getting Alternate Image Urls
				my $count=1;
				if($image_page=~m/<ul[^>]*?id\s*\=\s*\"\s*product\-\s*thumbs\s*\"([\w\W]*?)<\/ul>/is)
				{
					my $blk1=$1;
					
					while($blk1=~m/<img\s*src\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>/igs)
					{
						$alt_image_url="http:$1";
						my $alt_image_id=$1 if($alt_image_url=~m/source\s*\[\s*([^<]*?)\s*]\s*\,/is); ###Taking Alternate Image ID to remove Duplicates
						
						if(($main_image_id eq $alt_image_id)&&($count==1))  ##Removing Duplicate Images of main and Alternate Images by their IDS(If main and 1st alternate Image are same)
						{
							goto COUNT;
						}
						unless($alt_image_url=~m/^http\:/is)
						{
							$alt_image_url="http:".$alt_image_url;
						}
						$alt_image_url=~s/\/product\/thumb/\/product\/large/igs;  ##Changing size of the Alternate images
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image_url,'product','h&m-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						if($default1)
						{
							$image_objectkey{$img_object}=$default1;  
						}
						else
						{
							$image_objectkey{$img_object}='';
						}
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);	
COUNT:						
						$count++;  #To skip Duplication of Alternate Images Removal from 2nd Alternate Image
					}
				}				
				##Getting swatch image Urls
				while($content2=~m/article\s*\-\s*([^\{]*?)\s*\{\s*background\s*\-\s*image\s*\:\s*url\s*\(([^\)]*?)\)/igs)   
				{
					my $swatch_image_code=$1;
					my $swatch_image_url=$2;
					
					unless($swatch_image_url=~m/^http\:/is)
					{
						$swatch_image_url="http:".$swatch_image_url;
					}
					
					if($swatch_image_code eq $Skucode)
					{
						$swatch_image_url='http:'.$swatch_image_url unless($swatch_image_url=~m/^\s*http\:/is);
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($swatch_image_url,'swatch','h&m-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch_image_url,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						if($default1)
						{
							$image_objectkey{$img_object}=$default1;
						}
						else
						{
							$image_objectkey{$img_object}='';
						}
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
			}
		}
		elsif($content2=~m/\"\s*product\-image[^\"]*?\"[^>]*?>\s*<img[^>]*?src\=\"\s*([^\"]*?)\"[^>]*?>/is) #Scenario 2 if colour not availble but images available
		{
			$main_image_url=$1;
			
			unless($main_image_url=~m/^http\:/is)
			{
				$main_image_url="http:".$1;
			}
			my ($imgid,$img_file) = &DBIL::ImageDownload($main_image_url,'product','h&m-uk');
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$main_image_url,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=''; ####Color Not Available
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
			
			##Getting swatch image Urls
			while($content2=~m/article\s*\-\s*[^<]*?\s*\{\s*background\s*\-\s*image\s*\:\s*url\s*\(([^\)]*?)\)/igs)   ##Getting Swatch Image Urls
			{
				my $swatch_image_url=$1;
				
				unless($swatch_image_url=~m/^http\:/is)
				{
					$swatch_image_url="http:".$swatch_image_url;
				}
				
				$swatch_image_url='http:'.$swatch_image_url unless($swatch_image_url=~m/^\s*http\:/is);
				my ($imgid,$img_file) = &DBIL::ImageDownload($swatch_image_url,'swatch','h&m-uk');
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch_image_url,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}='';
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
		}
		
		#Mapping into Sku_has_Image Table from Sku and Image table by their ObejectKeys
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
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
ENDOFF:	
		$dbh->commit();
	}
}1;
#Function to remove Special Character in price
sub price()
{
	my $p=shift;
	my $str='£';
	$p=encode_entities($p);
	$p=~s/\&Acirc\;\&pound\;/eur/igs;
	$p=~s/eur/$str/igs;
	$p=~s/&pound;/£/ if($p=~m/&pound;/is);
	return $p;
}		
##Function to remove Special Characters in Data
sub clear
{
  my $data=shift;
  $data=decode_entities($data);
  $data=~s/š//igs;	
  $data=~s/Ë/°/igs;
  $data=~s/Ã//igs;
  $data=~s/Â//igs;
  return $data;		
}
#Function to get Page's Content
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
