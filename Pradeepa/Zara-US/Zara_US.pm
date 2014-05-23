#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Zara_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Zara_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Zara-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Zau';
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
	my $skuflag = 0;my $imageflag = 0;my $mflag=0;
	if($product_object_key)
	{
		my $url3=$url;
		my $skuflag = 0;
		my $imageflag = 0;
		my $mflag=0;
		my %AllColor;
		
		$url3 =~ s/^\s+|\s+$//g;
		$url3='http://www.zara.com/us/'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content1=&get_content("$url3");
		my %AllColor;
		
		if($content1=~ m/<li\s*class=\"bundle-item\"\s*[\w\W]*?\s*<div\s*class=\"bundle\-item\-description\"\s*>/is)
		{
			$mflag=1;
		}
		
		if($content1=~m/>\s*We\s*are\s*sorry\s*\.\s*The\s*item\s*you\s*are\s*looking\s*for\s*is\s*no\s*longer\s*available\s*\.\s*/is)
		{
			goto PNF;
		}
		
		my ($image,$price,$price_text,$brand,$item_no,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,@colour,$Url1_inside,$size,$blk,@colour1,$clr1,$ckproduct_id);
		#Getting product ItemNo or ProductID 
		if($content1=~m/<p[^>]*?class\s*\=\s*\"reference\s*\"\s*>\s*Ref(?:\.|\:)\s*([^<]*?)\s*</is)
		{
			$item_no=&DBIL::Trim($1);
			$ckproduct_id = &DBIL::UpdateProducthasTag($item_no, $product_object_key, $dbh,$robotname,$retailer_id);
            goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		elsif($content1=~m/<div\s*id\s*\=\s*\"\s*page\s*\-\s*container\"[^>]*?\s*product\s*Ref\s*\:\s*(?:\'|\")([^\'\"]*?)(?:\'|\")/is)
		{
			$item_no=&DBIL::Trim($1);
			$ckproduct_id = &DBIL::UpdateProducthasTag($item_no, $product_object_key, $dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		
		# Getting product price
		if ( $content1 =~ m/<span[^>]*?data\-price\s*\=\s*\"\s*(\d+[^\"]*?\s*(?:USD)?)\"[^>]*?>(?:[^>]*?(?:\s*<[^>]*?>\s*)+\s*-\s*<span[^>]*?data\s*\-\s*price\s*\=\s*\"(\d+[^\"]*?\s*(?:USD)?)\s*\"\s*>)?/is )
		{
			$price_text=&DBIL::Trim($1);
			my $price_text1=&DBIL::Trim($2);
			if($price_text=~m/(\d[^<]*)\s*USD/is)
			{
				$price=$1;
			}
			
			if($price_text1)
			{
				$price_text="$price_text"."-"."$price_text1";
			}
		}
		
		## Getting colour (Under Swatch Images)
		if ( $content1 =~ m/Choose\s*a\s*colour\s*<([\w\W]*?)(?:<\/label>\s*<\/div>|<h2)/is )
		{
			$blk=$1;
			while($blk=~m/title\s*\=\s*(?:\"|\')([^>]*?)\s*(?:\"|\')[^>]*?>/igs)
			{
				my $colour1 = &DBIL::Trim($1);
				push(@colour,$colour1);
				####Color Duplication Incremented
				if($AllColor{$colour1}>0)
				{
					$AllColor{$colour1}++;		
					my $tcolor1 = $colour1.'('.$AllColor{$colour1}.')';
					$clr1=$tcolor1;
				}
				else
				{
					$AllColor{$colour1}++;
					$clr1=$colour1;
				}
				push(@colour1,$clr1);
			}
		}
		# Getting product name
		if ( $content1 =~ m/<h1[^>]*?>([^<]*?)</is )
		{
			$product_name = &DBIL::Trim($1);
			$product_name=&clear($product_name);
		}
		# Getting product description
		if ( $content1 =~ m/<\s*p\s*(?:class|id)\s*\=\s*(?:\"|\')\s*description\s*(?:\"|\')\s*>([^<]*?)<(?:[\w\W]*?<div\s*class\s*\=\s*\"\s*bundle\s*\-\s*item\s*\-\s*description\s*\"\s*>(?:(?:\s*<[^>]*?>\s*)+\s*)?([^<]*?)<)?/is )
		{
			$description = &DBIL::Trim($1." $2");
			$description=&clear($description);
			$description='' if($mflag);
		}
		# Getting product detail
		if ( $content1 =~ m/<div\s*class=\"hidden\-content\"\s*>\s*<h2>\s*Composition\s*<\/h2>\s*<ul>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>\s*<\/div>/is )
		{
			$prod_detail = &DBIL::Trim($1);
			$prod_detail=&clear($prod_detail);
		}
		# size & out_of_stock & Color
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);
		if(@colour)	  ##@colour to match with sku_objectkey		
		{
			my $i=0;
			while($content1=~m/\{\"\s*sizes\s*\"\s*\:([\w\W]*?)\"pColorImgNames\"/igs)   #Block to get size and Out of stock
			{
				my $blk_clr=$1;
				while($blk_clr=~m/\{\s*[^\}]*?\,\s*\"\s*availability\s*\"\s*\:\s*\"([^\,]*?)\s*\"\,[^\}]*?\s*\"\s*description\s*\"\s*\:\s*\"([^\"]*?)\"\}/igs) #Getting each size and their corresponding Out of stock
				{
					$out_of_stock=$1;
					$size=&clear($2);   ##clear function to remove special Characters					
					$out_of_stock =~ s/^\s*In\s*Stock\s*$/n/igs;
					$out_of_stock =~ s/^\s*Out\s*Of\s*Stock\s*$/y/igs;
					$out_of_stock =~ s/^\s*Coming\s*Soon\s*$/y/igs;
					$out_of_stock =~ s/^\s*Back\s*Soon\s*$/y/igs;	
					
					$price="null" if($mflag or $price eq '' or $price eq ' ');
					$size=' ' if($size eq '' or $size eq ' ');
					$out_of_stock='n' if($mflag or $out_of_stock eq '' or $out_of_stock eq ' ');
					
					#print "In Blk1 price :$price\t$size$out_of_stock\n";
					
					my $clr;
					#########To Change color CASE
					$clr = lc($colour1[$i]);
					my $tcolor;
					while($clr =~ m/([^>]*?)(?:\s+|\-|$)/igs)
					{
						if($tcolor eq '')
						{
						  $tcolor = ucfirst($&);
						}
						else
						{
							$tcolor = $tcolor.ucfirst($&)
						}
					}
					
					$tcolor=~s/\- /-/igs if($clr=~m/[^<]*\w+\-\w+[^<]*/is);					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$colour[$i];
					push(@query_string,$query);
				}
				$i++;
			}
		}
		else
		{
			$price="null" if($mflag or $price eq '' or $price eq ' ');
			$out_of_stock='n' if($mflag or $out_of_stock eq '' or $out_of_stock eq ' ');			
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'','',$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			$sku_objectkey{$sku_object}='';    ###Color Not Available
			push(@query_string,$query);
		}	
		
		###Getting Swatch image urls
		my $j=0;
		my (@swa_clr,$blk1);

		if ( $content1 =~ m/Choose\s*a\s*colour\s*<([\w\W]*?)(?:<\/label>\s*<\/div>|<h2)/is )  #Swatch Images Block
		{
			$blk1=$1;
			
			while($blk1=~m/title\s*\=\s*(?:\"|\')([^>]*?)\s*(?:\"|\')[^>]*?>\s*<img[^>]*?src\s*\=\s*(?:\"|\')\s*([^\"\'\?]*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/igs)#Getting Each swatch image urls
			{
				my $swa_clr=$1;
				my $Swatch_image_url=$2;
				
				$Swatch_image_url =~ s/photos\/\//photos\//igs;
				
				push(@swa_clr,$swa_clr);

				if($Swatch_image_url ne "")
				{
					$Swatch_image_url="http:"."$Swatch_image_url" unless($Swatch_image_url=~m/^\s*http\:/is);					
					my ($imgid,$img_file) = &DBIL::ImageDownload($Swatch_image_url,'swatch',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$Swatch_image_url,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$swa_clr;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
			}	
		}	
		#Images Section
		if($content1 =~ m/\{\s*subscribeLabel\s*\}\s*\}\s*(?:\s*<[^>]*?>\s*)+\s*([\w\W]*?)<\/script>/igs) #Images Block 
		{
			my $block=$&;
			my $k="0";
			while($block=~m/{\s*\"\s*xmedias\s*\"\s*\:\s*\[\s*\{\s*\"\s*datatype\s*\"\s*\:([\w\W]*?)\}\s*\]/igs)  #Images Block for Separate colours
			{
				my $block1=$&;
				my $count=1;
				
				while ( $block1 =~ m/(?:\"|\')\s*url\s*(?:\"|\')\s*\:\s*(?:\"|\')\s*([^\"\'\?]*)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^\}]*?\}/igs ) #Getting Each Image urls with respect to colours
				{
					$image = &DBIL::Trim($1);
					$image =~ s/photos\/\//photos\//igs;
					$image="http:"."$image" unless($image=~m/^\s*http\:/is);
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($image,'product',$retailer_name);						
					if($count==1)
					{
						#Main image urls Collection
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$swa_clr[$k];
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
						$count++;
					}
					else
					{		
						#Alternate image urls Collection
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$swa_clr[$k];
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
				$k++;	
			}
		}
		elsif($content1=~m/<div[^>]*?class\s*\=\s*\"big\s*Image\s*Container\s*\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/is)
		{
			$main_image = $1;
			$main_image =~ s/\$//g;			
			$main_image =~ s/photos\/\//photos\//igs;
			$main_image="http:"."$main_image" unless($main_image=~m/^\s*http\:/is);
			
			my ($imgid,$img_file) = &DBIL::ImageDownload($main_image,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$main_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}='';
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
			
			if($mflag)
			{
				my $count=1;
				if($content1=~m/<div\s*class\s*\=\s*\"\s*bigImageContainer\"[^>]*?>\s*[\w\W]*?<\/div>\s*<\/div>\s*<\/div>/is)
				{
					my $blkimg=$&;
					
					while($blkimg=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/igs)
					{
						my $image = &DBIL::Trim($1);
						$image =~ s/photos\/\//photos\//igs;
					    $image="http:"."$image" unless($image=~m/^\s*http\:/is); 
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($image,'product',$retailer_name);
						if($count==1)
						{
							#Main image urls Collection
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}='';
							$hash_default_image{$img_object}='y';
							push(@query_string,$query);
							$count++;
						}
						else
						{		
							#Alternate image urls Collection
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}='';
							$hash_default_image{$img_object}='n';
							push(@query_string,$query);
						}
					}
				}
				elsif($content1=~m/<div[^>]*?class\s*\=\s*\"big\s*Image\s*Container\s*\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/is)
				{
					$main_image = $1;
					$main_image =~ s/\$//g;	
					$main_image =~ s/photos\/\//photos\//igs;
					$main_image="http:"."$main_image" unless($main_image=~m/^\s*http\:/is);
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($main_image,'product',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$main_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}='';
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);
				}
			}
		}
		undef(@colour);	
		undef(@colour1);	
		
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
		if(($product_name eq '')&&($item_no ne '')&&($skuflag))
		{
			$product_name='Blank';
		}
		if((($description eq '') or ($description eq ' '))&&(($prod_detail eq '') or ($prod_detail eq ' '))&&($skuflag)&&($item_no ne ''))
		{
			$description='Blank';
		}
PNF:
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$item_no,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id,$mflag);
		push(@query_string,$query1);
		push(@query_string,$query2);
		if($description eq 'Blank')
		{
			my $query3=&DBIL::SaveDB("update Product set product_description='' where retailer_id=\'$retailer_id\' and product_description='Blank'",$dbh,$robotname);
			push(@query_string,$query3);
		}
		if($product_name eq 'Blank')
		{
			my $query4=&DBIL::SaveDB("update Product set product_name='' where retailer_id=\'$retailer_id\' and product_name='Blank'",$dbh,$robotname);
			push(@query_string,$query4);
		}
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		$image=$price=$price_text=$brand=$item_no=$product_name=$description=$main_image=$prod_detail=$out_of_stock=@colour=$size=$blk=@colour1=$clr1=$ckproduct_id=undef;
ENDOFF:	
		$dbh->commit();
	}
}1;



sub clear()
{
	my $text=shift;
	$text=decode_entities($text);	
	$text=~s/ร/ษ/igs;
	$text=~s/ยบ/บ/igs;
	$text=~s/ย//igs;
	return $text;
}		

sub get_content()
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