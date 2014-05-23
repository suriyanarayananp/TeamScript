#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Ms_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Ms_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Ms-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='M&S';
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
	my $skuflag = 0;
	my $imageflag = 0;
	my $mflag=0;
	if($product_object_key)
	{		
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$url3='http://www.marksandspencer.com/'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = get_content($url3);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour,$tprice);
		#price_text
		if($content2 =~ m/<div\s*class\=\"pricing\">([\w\W]*?)<\/dl>/is)
		{
			my $PriceCont = $1;
			$price_text = &DBIL::Trim($PriceCont);
			$price_text =~ s/\-|\Â//igs;
		}
		#price
		if($content2 =~ m/data\-mapping\=\"price\"\s*data\-value\=\"([^>]*?)\">/is)
		{
			my $PriceCont = $1;
			$PriceCont =~ s/\-|\Â|\£//igs;
			$price = &DBIL::Trim($PriceCont);
		}
		#product_name
		if ( $content2 =~ m/<h1[^>]*?>\s*([\w\W]*?)\s*<\/h1>/is)
		{
			$product_name = &DBIL::Trim($1);
			$product_name = decode_entities($product_name);
			$product_name =~ s/\Â//igs;
		}
		if ( $content2 =~ m/\"code\">\s*([^>]*?)\s*<\/p>/is)
		{
			$product_id = &DBIL::Trim($1);
			$product_id = decode_entities($product_id);
			$product_id =~ s/\Â//igs;
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#Brand
		if($content2 =~ m/class\=\"sb\-logo\">\s*([^>]*?)\s*<\/li>/is )
		{
			$brand = &DBIL::Trim($1);
			if($brand =~ m/M\&S\s*COLLECTIONN/is)
			{
				$brand='M&S Collection';
			}
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		if($content2 =~ m/class\=\"product\-description\">\s*([^>]*?)\s*</is)
		{
			$description = &DBIL::Trim($1);
		}
		if($content2 =~ m/data\-panel\-id\=\"productInformation\">([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
		{
			$prod_detail = $1;
			$prod_detail =~ s/<li>/* /igs;
			$prod_detail =~ s/<[^>]*?>//igs;
		}
		$description = decode_entities($description);
		$description =~ s/\Â//igs;
		$prod_detail = decode_entities($prod_detail);
		$prod_detail =~ s/\Â//igs;
		my (%swatchHash,%ProductHash, $mainID, %sizeID);
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hashImage);
		if($content2 =~ m/class\=\"product\-code\"\s*type\=\"hidden\"\s*value\=\"([^>]*?)\"[^>]*?>/is)
		{
			while($content2 =~ m/class\=\"product\-code\"\s*type\=\"hidden\"\s*value\=\"([^>]*?)\"[^>]*?>/igs)
			{
				if($product_id eq '')
				{
					$product_id =  $1;
				}
				else
				{
					$product_id =  $1.'+'.$product_id;
				}
			}
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
			if($content2 =~ m/<div\s*class\=\"sets\-price\">([\w\W]*?)<\/dl>/is)
			{
				my $PriceCont = $1;
				$price_text = &DBIL::Trim($PriceCont);
				$price_text =~ s/\-|\Â//igs;
				$price = 'null';
			}
			if($content2 =~ m/class\=\"product\-description\">\s*([\w\W]*?)\s*<\/p>/is)
			{
				$description = &DBIL::Trim($1);
				$description = decode_entities($description);
				$description =~ s/\Â//igs;
				$prod_detail = '';
			}
			my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'','','n',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$skuflag = 1 if($flag);
			$sku_objectkey{$sku_object}='No Color';
			push(@query_string,$query);
			
			my $imageURL = 'http:'.$1 if($content2 =~ m/class\=\"current\"\s*src\=\"([^>]*?)\"/is);
			$imageURL = decode_entities($imageURL);
			if($imageURL ne '')
			{
				my ($imgid,$img_file) = &DBIL::ImageDownload($imageURL,'product','m&s-uk');
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageURL,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}='No Color';
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);
					
			}
			$mflag = 1;
			goto PNF;
		}
		else
		{
			if($content2 =~ m/class\=\"size\-indicator\">\s*<\/div>([\w\W]*?)<\/td>/is)
			{
				while($content2 =~ m/class\=\"size\-indicator\">\s*<\/div>([\w\W]*?)<\/td>/igs)  ##Multiple Sizes
				{
					my $sizeCont = $1;
					while($sizeCont =~ m/name\=\"size\"\s*value\=\"([^>]*?)\"[\w\W]*?<\/span>\s*([^>]*?)\s*<\/label>/igs)
					{
						$sizeID{$1} = decode_entities($2);
					}
				}
			}
			elsif($content2 =~ m/>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is) ##Multiple Sizes
			{
				my $sizeCont = $1;
				while($sizeCont =~ m/data\-product\-option\-label\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs)
				{
					$sizeID{$2} = decode_entities($1);
				}
			}
			else
			{
				while($content2 =~ m/class\=\"size\s*skip\s*single\-size\-accordion\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/igs)  ##OneSize
				{
					my $sizeCont = $1;
					while($sizeCont =~ m/name\=\"size\"\s*value\=\"([^>]*?)\"[\w\W]*?<\/span>\s*([^>]*?)\s*</igs)
					{
						$sizeID{$1} = decode_entities($2);
					}
				}
			}
			## Swatches :
			my $skucount=0;
			$mainID = $1 if($content2 =~ m/class\=\"product\-code\s*mainProdId\"\s*type\=\"hidden\"\s*value\=\"([^>]*?)\"/is);
			if($content2 =~ m/class\=\"swatch\-container\">([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
			{
				my $swatchCont = $1;
				while($swatchCont =~ m/data\-swatch\-name\=\"([^>]*?)\"\s*data\-swatch\-src\=\"([^>]*?)\"/igs)
				{
					my $color = &DBIL::Trim($1);
					my $swatchURL = &DBIL::Trim($2);
					$swatchURL = "http:".$swatchURL unless($swatchURL =~ m/^http/is);
					$swatchURL = decode_entities($swatchURL);
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatchURL,'swatch','m&s-uk');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatchURL,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$color;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
					my $tcolor = $color;
					$tcolor =~ s/\s*//igs;
					if($content2 =~ m/\"$mainID\_$tcolor\"\:\{([\w\W]*?\})\}/is)
					{
						my $StockCont = $1;
						my @sizes = keys %sizeID;
						if(@sizes > 1) ##Multiple Size
						{
							foreach (keys %sizeID)
							{
								my $tempsize = $_;
								my $size = quotemeta($tempsize);
								if($StockCont =~ m/\"$size\"\:\{\"count\"\:(\d+)\.\d+/is)
								{
									my $stcount = $1;
									$skucount++;
									my ($price,$oldprice,$offerprice, $pricetext);
									if($content2 =~ m/\"$mainID\_$tcolor\_$size\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"\"}/is)
									{
										$price = $1;	$oldprice = $2;	$offerprice = $3;
										$pricetext = $price.' '.$oldprice.' '.$offerprice;
										$pricetext = decode_entities($pricetext);
										$price =~ s/\&pound\;//igs;
									}
									print "$skucount :: $color --> $sizeID{$tempsize} ---> $stcount --> $price --> $pricetext\n";
									my $out_of_stock = 'n';
									$out_of_stock = 'y' if($stcount == 0);
									$price = 'null' if($price eq '');
									my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$pricetext,$sizeID{$tempsize},$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
									$skuflag = 1 if($flag);
									$sku_objectkey{$sku_object}=$color;
									push(@query_string,$query);
								}
							}
						}
						elsif(@sizes == 1)  ##One Size
						{
							foreach (keys %sizeID)
							{
								my $size = $_;
								my $tsize = $size;
								$tsize =~ s/\s+//igs;
								print "$size\n";
								if($StockCont =~ m/\"$tsize\"\:\{\"count\"\:(\d+)\.\d+/is)
								{
									my $stcount = $1;
									$skucount++;
									my ($price,$oldprice,$offerprice, $pricetext);
									if($content2 =~ m/\"$mainID\_$tcolor\_$tsize\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"\"}/is)
									{
										$price = $1;	$oldprice = $2;	$offerprice = $3;
										$pricetext = $price.' '.$oldprice.' '.$offerprice;
										$pricetext = decode_entities($pricetext);
										$price =~ s/\&pound\;//igs;
									}
									$size =~ s/DUMMY//igs;
									print "$skucount :: $color --> $size ---> $stcount --> $price --> $pricetext\n";
									my $out_of_stock = 'n';
									$out_of_stock = 'y' if($stcount == 0);
									$price = 'null' if($price eq '');
									my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$pricetext,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
									$skuflag = 1 if($flag);
									$sku_objectkey{$sku_object}=$color;
									push(@query_string,$query);
								}
							}
						}
						else #No Size
						{
							if($StockCont =~ m/\"DUMMY\"\:\{\"count\"\:(\d+)\.\d+/is)
							{
								my $stcount = $1;
								$skucount++;
								my ($price,$oldprice,$offerprice, $pricetext);
								if($content2 =~ m/\"$mainID\_$tcolor\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"\"}/is)
								{
									$price = $1;	$oldprice = $2;	$offerprice = $3;
									$pricetext = $price.' '.$oldprice.' '.$offerprice;
									$pricetext = decode_entities($pricetext);
									$price =~ s/\&pound\;//igs;
								}
								print "$skucount :: $color -->  ---> $stcount --> $price --> $pricetext\n";
								my $out_of_stock = 'n';
								$out_of_stock = 'y' if($stcount == 0);
								$price = 'null' if($price eq '');
								my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$pricetext,'',$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$skuflag = 1 if($flag);
								$sku_objectkey{$sku_object}=$color;
								push(@query_string,$query);
							}
						}
					}
				}
				while($swatchCont =~ m/name\=\"colour\"\s*value\=\"([^>]*?)\"[^>]*?data\-image\-set\=\"([^>]*?)\"/igs)
				{
					my $Color;
					my $ImageUrl = &DBIL::Trim($2);
					$Color = &DBIL::Trim($1) if($swatchCont =~ m/data\-swatch\-name\=\"([^>]*?)\"/is);
					$ImageUrl = "http:".$ImageUrl unless($ImageUrl =~ m/^http/is);
					$ImageUrl = decode_entities($ImageUrl);
					# print $ImageUrl,"\n";
					my $ImageCont  = &get_content($ImageUrl);
					my $imgCount = 0;
					while($ImageCont =~ m/\;([^\;]*?)(?:\,|")/igs)
					{
						my $imageURL = "http://asset1.marksandspencer.com/is/image/".$1.'?$PDP_MAXI_ZOOM$';
						# print $imageURL,"\n";
						$ProductHash{$Color} = decode_entities($imageURL);
						my ($imgid,$img_file) = &DBIL::ImageDownload($imageURL,'product','m&s-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageURL,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$Color;
						if($imgCount == 0)
						{
							$imgCount++;
							$hash_default_image{$img_object} = 'y';
						}
						else
						{
							$hash_default_image{$img_object} = 'n';
						}
						push(@query_string,$query);
					}
					if($imgCount == 0)
					{
						if($content2 =~ m/src\=\"([^>]*?)\?[^>]*?\s*class\=\"btn\s*zoom\"/is)
						{
							my $imageURL = "http:".$1.'?$PDP_MAXI_ZOOM$';
							$ProductHash{$Color} = decode_entities($imageURL);
							my ($imgid,$img_file) = &DBIL::ImageDownload($imageURL,'product','m&s-uk');
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageURL,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}=$Color;
							$hash_default_image{$img_object} = 'y';
							push(@query_string,$query);
						}
					}
				}
			}
			else ## No Swatch or No Color (NO Color & No Size)
			{
				if($content2 =~ m/\"$mainID[^"]*?\"\:\{([\w\W]*?\})\}\;/is)
				{
					my $StockCont = $1;
					if($StockCont =~ m/\"DUMMY\"\:\{\"count\"\:(\d+)\.\d+/is)  ## No Size
					{
						my $stcount = $1;
						$skucount++;
						my ($price,$oldprice,$offerprice, $pricetext);
						if($content2 =~ m/\"$mainID\_[^>]*?\_DUMMY\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"\"}/is)
						{
							$price = $1;	$oldprice = $2;	$offerprice = $3;
							$pricetext = $price.' '.$oldprice.' '.$offerprice;
							$pricetext = decode_entities($pricetext);
							$price =~ s/\&pound\;//igs;
						}
						print "$skucount :: No Color --> No Size ---> $stcount --> $price --> $pricetext\n";
						my $out_of_stock = 'n';
						$out_of_stock = 'y' if($stcount == 0);
						$price = 'null' if($price eq '');
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$pricetext,'','',$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}='No Color';
						push(@query_string,$query);
					}
				}
				elsif($content2 =~ m/>\s*Sorry\,\s*but\s*this\s*item\s*is\s*no\s*longer\s*available\.\s*<\/span>/is) ##No Color->No Size ->Out of stock
				{
					my $out_of_stock = 'y';
					my $price = 'null';
					my $pricetext;
					print "$skucount :: No Color --> No Size ---> $out_of_stock\n";
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,'','','',$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}='No Color';
					push(@query_string,$query);
				}
				if($content2 =~ m/data\-default\-imageset\=\"([^>]*?)\"/is)
				{
					my $ImageUrl = &DBIL::Trim($1);
					my $Color = 'No Color';
					$ImageUrl = "http:".$ImageUrl unless($ImageUrl =~ m/^http/is);
					$ImageUrl = decode_entities($ImageUrl);
					my $ImageCont  = &get_content($ImageUrl);
					my $imgCount = 0;
					while($ImageCont =~ m/\;([^\;]*?)(?:\,|")/igs)
					{
						my $imageURL = "http://asset1.marksandspencer.com/is/image/".$1.'?$PDP_MAXI_ZOOM$';
						# print $imageURL,"\n";
						$ProductHash{$Color} = decode_entities($imageURL);
						my ($imgid,$img_file) = &DBIL::ImageDownload($imageURL,'product','m&s-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageURL,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$Color;
						if($imgCount == 0)
						{
							$imgCount++;
							$hash_default_image{$img_object} = 'y';
						}
						else
						{
							$hash_default_image{$img_object} = 'n';
						}
						push(@query_string,$query);
					}
					if($imgCount == 0)
					{
						if($content2 =~ m/src\=\"([^>]*?)\?[^>]*?\s*class\=\"btn\s*zoom\"/is)
						{
							my $imageURL = "http:".$1.'?$PDP_MAXI_ZOOM$';
							$ProductHash{$Color} = decode_entities($imageURL);
							my ($imgid,$img_file) = &DBIL::ImageDownload($imageURL,'product','m&s-uk');
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageURL,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}=$Color;
							$hash_default_image{$img_object} = 'y';
							push(@query_string,$query);
						}
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
				# print "lc($image_objectkey{$img_obj_key}) eq lc($sku_objectkey{$sku_obj_key})\n";
				if(lc($image_objectkey{$img_obj_key}) eq lc($sku_objectkey{$sku_obj_key}))
				{
					my $query=&DBIL::SaveSkuhasImage($sku_obj_key,$img_obj_key,$hash_default_image{$img_obj_key},$product_object_key,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					push(@query_string,$query);
				}
			}
		}
		PNF:
		my($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id,$mflag);
		push(@query_string,$query1);
		push(@query_string,$query2);

		# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		# push(@query_string,$qry); 
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		ENDOFF:
			$dbh->commit();
	}	
}1;

sub get_content
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