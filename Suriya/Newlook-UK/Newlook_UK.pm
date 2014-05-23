#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Newlook_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Newlook_UK_DetailProcess()
{
	####Variable Initialization##############
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Newlook-UK--Detail';
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	my $retailer_name=$robotname;
	my $robotname_detail=$robotname;
	my $robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	my $Retailer_Random_String='New';
	my $pid = $$;
	my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
	$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
	my $excuetionid = $ip.'_'.$pid;
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
	if($product_object_key)  ## If ObjectKey exists in Product.
	{
		my $skuflag = 0;
		my $imageflag = 0;
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$product_object_key =~ s/^\s+|\s+$//g;
		$url3='http://www.newlook.com'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = getcontent($url3);
		goto PNF if($content2 =~ m/Oops\s*\,\s*Page\s*Not\s*Found\s*<\/title>/is);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour);
		my @query_string;
		#product_id
		if($content2 =~ m/Product\s*Code\s*\:\s*<[^>]*?>\s*([^>]*?)\s*</is )
		{
			$product_id = &DBIL::Trim($1);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname, $retailer_id);
			goto ENDOF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#product_name
		if ( $content2 =~ m/prod_info\s*[^>]*?>\s*<[^>]*?>\s*<h[^>]*?>\s*([^>]*?)\s*<\/h\d+>/is )
		{
			$product_name = &DBIL::Trim($1);
		}
		#product_name
		if ( $content2 =~ m/price\"[^>]*?>\s*([\w\W]*?)\s*<[^>]*?end\s*prod_detail_left\s*[^>]*?>/is )
		{
			$price_text = $1;
			if($price_text=~m/price\">\s*([^>]*?)\s*</is)
			{
				$price = &DBIL::Trim($1);
			}
			elsif($price_text=~m/<span\s*[^>]*?\"now\">\s*(?:<span\s*[^>]*?promotext\">\s*Now\s*[\w\W]*?)?<[^>]*?>\s*([\w\W]*?)\s*<span\s*[^>]*?\"was\">\s*/is)
			{
				$price = &DBIL::Trim($1);
			}
			elsif($price_text=~m/<\/span>\s*<span\s*[^>]*?\"price\"[^>]*?>\s*[^>]*?([\d\.]*?)\s*<\/span>\s*<meta/is)
			{
				$price = &DBIL::Trim($1);
			}
			$price_text = &DBIL::Trim($price_text);
			$price=~s/^Â//igs;
			$price=~s/£//igs;
			$price_text =~ s/&nbsp;//igs;
			$price_text =~ s/Â//igs;
			$price_text =~ s/(WAS)/ $1/igs;
		}
		#Brand
		if ( $content2 =~ m/product_brand\s*\:\s*\[\"([\w\W]*?)\"\]?/is )
		{
			$brand = &DBIL::Trim($1);
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#description&details
		if ( $content2 =~ m/description\">\s*([\w\W]*?)\s*<\/p>\s*<\/div>/is )
		{
			my $desc_content = $1;
			if ( $desc_content =~ m/([\w\W]*?)\s*Care\s*guide\s*([\w\W]+)/is )
			{
				$description = &DBIL::Trim($1);
				$prod_detail = &DBIL::Trim($2);
				$prod_detail = "CARE GUIDE ".$prod_detail;
			}
			else
			{
				$description = &DBIL::Trim($desc_content);
				$prod_detail = &DBIL::Trim($desc_content);
			}
		}
		#colour
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key,@totalColor,%AllColor);
		my $content3 = $content2;
		if($content3 =~ m/link\=\'([^>]*?)\'\s*title\=\'([^>]*?)\'>\s*<img[^>]*?src/is)
		{
			while($content3 =~ m/link\=\'([^>]*?)\'\s*title\=\'([^>]*?)\'>\s*<img[^>]*?src/igs)
			{
				my $colorUrl = $1;
				my $DefaultColor = &DBIL::Trim($2);
				my $colorUrl='http://www.newlook.com'.$colorUrl unless($colorUrl=~m/^\s*http\:/is);
				$content2 = getcontent($colorUrl);
				my ($product_name,$price_text,$price);
				# if(grep( /$DefaultColor/, @totalColor ))
				# {
					# $AllColor{$DefaultColor}++;
					# my $tcolor = $DefaultColor.'('.$AllColor{$DefaultColor}.')';
					# push @totalColor,$tcolor;
				# }
				# else
				# {
					# push @totalColor,$DefaultColor;
					# $AllColor{$DefaultColor}++;
				# }
				#product_name
				if ( $content2 =~ m/prod_info\s*[^>]*?>\s*<[^>]*?>\s*<h[^>]*?>\s*([^>]*?)\s*<\/h\d+>/is )
				{
					$product_name = &DBIL::Trim($1);
				}
				#product_name
				if ( $content2 =~ m/price\"[^>]*?>\s*([\w\W]*?)\s*<[^>]*?end\s*prod_detail_left\s*[^>]*?>/is )
				{
					$price_text = $1;
					if($price_text=~m/price\">\s*([^>]*?)\s*</is)
					{
						$price = &DBIL::Trim($1);
					}
					elsif($price_text=~m/<span\s*[^>]*?\"now\">\s*(?:<span\s*[^>]*?promotext\">\s*Now\s*[\w\W]*?)?<[^>]*?>\s*([\w\W]*?)\s*<span\s*[^>]*?\"was\">\s*/is)
					{
						$price = &DBIL::Trim($1);
					}
					elsif($price_text=~m/<\/span>\s*<span\s*[^>]*?\"price\"[^>]*?>\s*[^>]*?([\d\.]*?)\s*<\/span>\s*<meta/is)
					{
						$price = &DBIL::Trim($1);
					}
					$price_text = &DBIL::Trim($price_text);
					$price=~s/^Â//igs;
					$price=~s/£//igs;
					$price_text =~ s/&nbsp;//igs;
					$price_text =~ s/Â//igs;
					$price_text =~ s/(WAS)/ $1/igs;
				}
				if($content2 =~ m/class\=\"selected_colour\s*colour\-option\">\s*<a[^>]*?href\=[^>]*?link\=[^>]*?title\=\'([^>]*?)\'>/is)
				{
					my $color = &DBIL::Trim($1);
					my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
					if($color eq "")
					{
						$color="no raw colour";
					}
					my $size_temp = $1 if($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is);
					$size_temp =~ s/\&quot\;/\"/igs;
					while($size_temp =~ m/<option\s*class\=\"[^>]*?\"\s*value\=\"([^>]*?)\"[^>]*?data-stock\=\"([^>]*?)\"|<option[^>]*?data-stock\=\"([^>]*?)\"[^>]*?\"\s*value\=\"([^>]*?)\"/igs)
					{
						my $size = $1.$4;
						my $stocklevel = $2.$3;
						$size = &DBIL::Trim($size);	$stocklevel = &DBIL::Trim($stocklevel);
						my $out_of_stock = 'n';
						$out_of_stock = 'y' if($stocklevel <= 0);
						
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$colorUrl,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$colorid;
						push(@query_string,$query);
					}
				}
				elsif(($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is) && ($content2 !~ m/var\s*skus\s*\=\s*\'\[\{([\w\W]*?)\]/is))
				{
					my $color = &DBIL::Trim($1) if($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is);
					if($color eq "")
					{
						$color="no raw colour";
					}
					my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
					my $out_of_stock = 'y';
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$colorUrl,$product_name,$price,$price_text,'',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$colorid;
					push(@query_string,$query);
				}
				elsif(($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is) && ($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is))
				{
					my $color = &DBIL::Trim($1) if($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is);
					if($color eq "")
					{
						$color="no raw colour";
					}
					my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
					my $size_temp = $1 if($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is);
					$size_temp =~ s/\&quot\;/\"/igs;
					while($size_temp =~ m/<option\s*class\=\"[^>]*?\"\s*value\=\"([^>]*?)\"[^>]*?data-stock\=\"([^>]*?)\"|<option[^>]*?data-stock\=\"([^>]*?)\"[^>]*?\"\s*value\=\"([^>]*?)\"/igs)
					{
						my $size = $1.$4;
						my $stocklevel = $2.$3;
						$size = &DBIL::Trim($size);	$stocklevel = &DBIL::Trim($stocklevel);
						my $out_of_stock = 'n';
						$out_of_stock = 'y' if($stocklevel <= 0);
						
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$colorUrl,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$colorid;
						push(@query_string,$query);
					}	
				}
				#swatchimage
				if ( $content2 =~ m/>COLOUR\s*([\w\W]*?)\s*<\/div>\s*<\/div>/is )
				{
					my $swatch_content = $1;
					my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
					if ( $swatch_content=~ m/<li\s*[^>]*?\=\"selected_colour[^>]*?>\s*<a\s*[^>]*?link\=\'([^>]*?)\'[^>]*?>\s*<img\s*[^>]*?src\=\s*\"\s*([^<]*?)\s*\"\s*alt\=\s*\"\s*([^<]*?)\s*\([^>]*?\s*\"\s*[^>]*?>/is )
					{
						my $img_file = 'http://www.newlook.com'.&DBIL::Trim($1);
						my $swatch 	= &DBIL::Trim($2);
						$swatch='http:'.$swatch unless($swatch=~m/^\s*http\:/is);
						
						my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch',$retailer_name);
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object} = $colorid;
						$hash_default_image{$img_object} = 'n';	
						push(@query_string,$query);						
					}
				}
				#Image
				if ( $content2 =~ m/<li\s*class\=\"li_thumb\">\s*([\w\W]*?)\s*<div\s*[^>]*?image_viewer/is )
				{
					my $alt_image_content = $1;
					my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
					my $count;
					while ( $alt_image_content =~ m/<img[^<]*?src\=\"([^<]*?)\"[^>]*?/igs )
					{
						$count++;
						my $alt_image = &DBIL::Trim($1);
						$alt_image='http:'.$alt_image unless($alt_image=~m/^\s*http\:/is);
						$alt_image =~ s/\$//g;
						$alt_image=~s/^([^>]*?)\?([^>]*?)$/$1?&hei=1000&wid=1000/igs;
						my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','newlook-uk');			
						if ($count == 1)
						{
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object} = $colorid;
							$hash_default_image{$img_object} = 'y';
							push(@query_string,$query);
						}
						else
						{
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object} = $colorid;
							$hash_default_image{$img_object} = 'n';
							push(@query_string,$query);
						}
					}
				}
			}
		}
		else
		{
			if($content2 =~ m/class\=\"selected_colour\s*colour\-option\">\s*<a\s*href\=[^>]*?link\=[^>]*?title\=\'([^>]*?)\'>/is)
			{
				my $color = &DBIL::Trim($1);
				my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
				if($color eq "")
				{
					$color="no raw colour";
				}
				my $size_temp = $1 if($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is);
				$size_temp =~ s/\&quot\;/\"/igs;
				while($size_temp =~ m/<option\s*class\=\"[^>]*?\"\s*value\=\"([^>]*?)\"[^>]*?data-stock\=\"([^>]*?)\"|<option[^>]*?data-stock\=\"([^>]*?)\"[^>]*?\"\s*value\=\"([^>]*?)\"/igs)
				{
					my $size = $1.$4;
					my $stocklevel = $2.$3;
					$size = &DBIL::Trim($size);	$stocklevel = &DBIL::Trim($stocklevel);
					my $out_of_stock = 'n';
					$out_of_stock = 'y' if($stocklevel <= 0);
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$colorid;
					push(@query_string,$query);
				}
			}
			elsif(($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is) && ($content2 !~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is))
			{
				my $color = &DBIL::Trim($1) if($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is);
				if($color eq "")
				{
					$color="no raw colour";
				}
				my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
				my $out_of_stock = 'y';
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$colorid;
				push(@query_string,$query);
			}
			elsif(($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is) && ($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is))
			{
				my $color = &DBIL::Trim($1) if($content2 =~ m/s\.eVar17\=\"([^>]*?)\"/is);
				if($color eq "")
				{
					$color="no raw colour";
				}
				my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
				my $size_temp = $1 if($content2 =~ m/>\s*Choose\s*your\s*size\s*<\/option>([\w\W]*?)<\/select>/is);
				$size_temp =~ s/\&quot\;/\"/igs;
				while($size_temp =~ m/<option\s*class\=\"[^>]*?\"\s*value\=\"([^>]*?)\"[^>]*?data-stock\=\"([^>]*?)\"|<option[^>]*?data-stock\=\"([^>]*?)\"[^>]*?\"\s*value\=\"([^>]*?)\"/igs)
				{
					my $size = $1.$4;
					my $stocklevel = $2.$3;
					$size = &DBIL::Trim($size);	$stocklevel = &DBIL::Trim($stocklevel);
					my $out_of_stock = 'n';
					$out_of_stock = 'y' if($stocklevel <= 0);
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$colorid;
					push(@query_string,$query);
				}	
			}
			#swatchimage
			if ( $content2 =~ m/>COLOUR\s*([\w\W]*?)\s*<\/div>\s*<\/div>/is )
			{
				my $swatch_content = $1;
				my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
				if ( $swatch_content=~ m/<li\s*[^>]*?\=\"selected_colour[^>]*?>\s*<a\s*[^>]*?link\=\'([^>]*?)\'[^>]*?>\s*<img\s*[^>]*?src\=\s*\"\s*([^<]*?)\s*\"\s*alt\=\s*\"\s*([^<]*?)\s*\([^>]*?\s*\"\s*[^>]*?>/is )
				{
					my $img_file = 'http://www.newlook.com'.&DBIL::Trim($1);
					my $swatch 	= &DBIL::Trim($2);
					$swatch='http:'.$swatch unless($swatch=~m/^\s*http\:/is);
					
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object} = $colorid;
					$hash_default_image{$img_object} = 'n';
					push(@query_string,$query);					
				}
			}
			#Image
			if ( $content2 =~ m/<li\s*class\=\"li_thumb\">\s*([\w\W]*?)\s*<div\s*[^>]*?image_viewer/is )
			{
				my $alt_image_content = $1;
				my $colorid =&DBIL::Trim($1) if($content2 =~ m/s\.eVar22\=\"([^>]*?)\"/is);
				my $count;
				while ( $alt_image_content =~ m/<img[^<]*?src\=\"([^<]*?)\"[^>]*?/igs )
				{
					$count++;
					my $alt_image = &DBIL::Trim($1);
					$alt_image='http:'.$alt_image unless($alt_image=~m/^\s*http\:/is);
					$alt_image =~ s/\$//g;
					$alt_image=~s/^([^>]*?)\?([^>]*?)$/$1?&hei=1000&wid=1000/igs;
					my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','newlook-uk');			
					if ($count == 1)
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object} = $colorid;
						$hash_default_image{$img_object} = 'y';
						push(@query_string,$query);
					}
					else
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object} = $colorid;
						$hash_default_image{$img_object} = 'n';
						push(@query_string,$query);
					}
				}
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
		PNF:
		my($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		# push(@query_string,$qry); 
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		ENDOF:
			$dbh->commit();
	}
}1;
sub getcontent() 
{ 
    my $url = shift;
	my $rerun_count=0;
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp;//igs;
	Home:
	my $req = HTTP::Request->new(GET=>$url);
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	open JJ,">>$retailer_file";
	print JJ "$url->$code\n";
	close JJ;
	my $content;
	if($code =~m/20/is)
	{
		$content = $res->content;
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto Home;
		}
	}
	return $content;
}