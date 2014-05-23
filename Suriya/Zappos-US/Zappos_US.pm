#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Zappos_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Zappos_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;	
	my $retailer_id=shift;
	my $logger = shift;
	$robotname='Zappos-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Zap';
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
	if($product_object_key)
	{
		my $skuflag = 0;
		my $imageflag = 0;
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$product_object_key =~ s/^\s+|\s+$//g;
		$url3='http://www.Zappos.com'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = &getcontent($url3);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour); 
		my $mflag=0;
		#product_id 
		if ( $content2 =~ m/type\=\"hidden\"\s*name\=\"productId\"\s*value\=\"([^>]*?)\"/is) 
		{ 
			$product_id = &DBIL::Trim($1);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname,$retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		} 
		#product_name 
		if ( $content2 =~ m/itemprop\=\"name\">([^>]*?)<\/a>\s*<\/h1>|<h1[^>]*?>([\w\W]*?)<\/h1>/is) 
		{ 
			$product_name = &DBIL::Trim($1.$2);
			$product_name = decode_entities($product_name);
		} 
		#Brand 
		if ($content2 =~ m/var\s*brandName\s*\=\s*\"([^>]*?)\"\;|id\=\"brandName\"\s*name\=\"brandName\"\s*value\=\"([^>]*?)\"/is) 
		{ 
			$brand = &DBIL::Trim($1.$2); 
			$brand =~ s/\\//igs;
			$brand = decode_entities($brand);
			if ( $brand !~ /^\s*$/g ) 
			{ 
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			} 
		} 
		#description&details 
		if ( $content2 =~ m/<div\s*class\=\"description\">([\w\W]*?)<\/div>|>\s*Description\s*<\/h2>([\w\W]*?)<\/ul>/is ) 
		{ 
			my $desc_content = $1.$2; 
			$desc_content =~ s/<li>/* /igs;
			$description = &DBIL::Trim($desc_content);
			$prod_detail; 
			$description = decode_entities($description);
		}
		my ($dimcont,@dimension,$dimcont2,%dimname,$dimcont3,%dimsize,$dimcont4,%sizes, %size, %inseam,@StockVal,%colorHash,%width);
		my (%sku_objectkey,%image_objectkey,%hash_default_image,%hashImage);
		$dimcont = $1 if($content2 =~ m/dimensions\s*\=\s*\[([\w\W]*?)\]/is);
		$dimcont2 = $1 if($content2 =~ m/dimensionIdToNameJson\s*\=\s*\{([\w\W]*?)\}/is);
		$dimcont3 = $1 if($content2 =~ m/dimToUnitToValJSON\s*\=\s*\{([\w\W]*?)\;/is);
		$dimcont4 = $1 if($content2 =~ m/valueIdToNameJSON\s*\=\s*\{([\w\W]*?)\;/is);
		if($content2 =~ m/var\s*stockJSON\s*\=\s*\[([\w\W]*?)\]/is)
		{
			my $stockCont = $1;
			while($stockCont =~ m/\{([\w\W]*?)\}/igs)
			{
				push @StockVal, $1;
			}
		}
		my $colorCont = $1 if($content2 =~ m/var\s*colorNames\s*\=\s*\{([\w\W]*?)\}/is);
		$colorCont =~ s/\\\"//igs;
		while($colorCont =~ m/\'([^>]*?)\'\:\"([^>]*?)\"/igs)
		{
			my $key = $1;
			my $val = $2;
			$val =~ s/\\//igs;
			$val =~ s/\'/\'\'/igs;
			$colorHash{$key} = $val;
		}
		$dimcont =~ s/\"//igs;
		@dimension = split /\,/,$dimcont;
		foreach (@dimension)
		{
			my $key = $_;
			$dimname{$key} = $1 if($dimcont2 =~ m/\"$key\"\:\"([^>]*?)\"/is);
			if($dimcont3 =~ m/\"$key\"\:\{\"[^>]*?\"\:\s*\[([^>]*?)\]/is)
			{
				my $tval = $1;
				my @tstsize = split /\,/,$tval;
				foreach (@tstsize)
				{
					my $tszie = $_.'_'.$dimname{$key};
					$dimsize{$tszie} = $key;
				}
			}
		}
		foreach (keys %dimsize)
		{
			my $sizeid = $_;
			my $sizetempid = $sizeid;
			$sizetempid =~ s/_size|_inseam|_width//igs;
			if($dimcont4 =~ m/\"$sizetempid\"\:\{\"value\"\:\"([^>]*?)\"\,/is)
			{
				my $sizkey = $1;
				$sizkey =~ s/\\//igs;
				$sizkey =~ s/\'/\'\'/igs;
				if($sizeid =~ m/_size/is)
				{
					$sizkey = $sizkey.'_size';
				}
				elsif($sizeid =~ m/_inseam/is)
				{
					$sizkey = $sizkey.'_inseam';
				}
				elsif($sizeid =~ m/_width/is)
				{
					$sizkey = $sizkey.'_width';
				}
				$sizes{$sizkey} = $sizeid;
			}
		}
		foreach( keys %sizes)
		{
			my $key = $_;
			# print "$key => $sizes{$key} => $dimsize{$sizes{$key}} => $dimname{$dimsize{$sizes{$key}}}\n";
			if($dimname{$dimsize{$sizes{$key}}} =~ m/Size/is)
			{
				$size{$key}=$sizes{$key};
			}
			elsif($dimname{$dimsize{$sizes{$key}}} =~ m/Inseam/is)
			{
				$inseam{$key}=$sizes{$key};
			}
			elsif($dimname{$dimsize{$sizes{$key}}} =~ m/Width/is)
			{
				$width{$key}=$sizes{$key};
			}
		}
		# print "********************\n";
		my $count = 0;
		if(@dimension > 1)
		{	
			if(keys %size and keys %inseam)
			{
				foreach (keys %colorHash)
				{
					my $colorId = $_;
					my ($price_text,$price);
					if($content2 =~ m/\'$colorId\'\:\s*\{\s*\"(now)\"\:\s*\'([^>]*?)\'\,\s*\"(was)\"\:\s*\'([^>]*?)\'\,\s*\"(nowInt)\"\:\s*([^>]*?)\s*\,\s*\"(wasInt)\"\:\s*([^>]*?)\s*}/is)
					{
						my $now = $2;	my $was = $4;	my $cp = $6;
						if($now eq $was)
						{
							$price_text = $now;
						}
						else
						{
							$price_text = $now." ".$was;
						}
						$price_text = $price_text; 
						$price = $cp;	$price = $price; 	
					}
					foreach (keys %size)
					{
						my $tsize = $_;
						my $tsizeid = $size{$_};
						foreach (keys %inseam)
						{
							my $tseam = $_;
							my $tseamid = $inseam{$_};
							my $out_of_stock = 'y';
							my $size;
							foreach (@StockVal)
							{
								
								my $stockStatus = $_;
								$tsize =~s/_size//igs;
								$tseam =~s/_inseam//igs;
								$size = 'size: '.$tsize.'/ inseam:'.$tseam;
								$tsizeid =~s/_size//igs;
								$tseamid =~s/_inseam//igs;
								if(($stockStatus =~ m/\"$tseamid\"/is) and ($stockStatus =~ m/\"$tsizeid\"/is) and ($stockStatus =~ m/\"$colorId\"/is))
								{
									$out_of_stock = 'n'; last;					
								}
							}
							$count++;
							# print "$count :: $size-->$out_of_stock-->$colorHash{$colorId}-->$price_text-->$price\n";
							my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$colorHash{$colorId},$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag = 1 if($flag);
							$sku_objectkey{$sku_object}=lc($colorId);
							push(@query_string,$query);
						}
					}
				}
			}
			elsif(keys %size and keys %width)
			{
				foreach (keys %colorHash)
				{
					my $colorId = $_;
					my ($price_text,$price);
					if($content2 =~ m/\'$colorId\'\:\s*\{\s*\"(now)\"\:\s*\'([^>]*?)\'\,\s*\"(was)\"\:\s*\'([^>]*?)\'\,\s*\"(nowInt)\"\:\s*([^>]*?)\s*\,\s*\"(wasInt)\"\:\s*([^>]*?)\s*}/is)
					{
						my $now = $2;	my $was = $4;	my $cp = $6;
						if($now eq $was)
						{
							$price_text = $now;
						}
						else
						{
							$price_text = $now." ".$was;
						}
						$price_text = $price_text; 
						$price = $cp;	$price = $price; 	
					}
					foreach (keys %size)
					{
						my $tsize = $_;
						my $tsizeid = $size{$_};
						foreach (keys %width)
						{
							my $tseam = $_;
							my $tseamid = $width{$_};
							my $out_of_stock = 'y';
							my $size;
							foreach (@StockVal)
							{
								my $stockStatus = $_;
								$tsize =~s/_size//igs;
								$tseam =~s/_width//igs;
								$size = 'Size: '.$tsize.'/ Width:'.$tseam;
								$tsizeid =~s/_size//igs;
								$tseamid =~s/_width//igs;
								if(($stockStatus =~ m/\"$tseamid\"/is) and ($stockStatus =~ m/\"$tsizeid\"/is) and ($stockStatus =~ m/\"$colorId\"/is))
								{
									$out_of_stock = 'n'; last;					
								}
							}
							$count++;
							# print "Step 1: $count :: $size-->$out_of_stock-->$colorHash{$colorId}-->$price_text-->$price\n";
							my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$colorHash{$colorId},$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag = 1 if($flag);
							$sku_objectkey{$sku_object}=lc($colorId);
							push(@query_string,$query);

						}
					}
				}
			}
		}
		else
		{
			if(keys %size)
			{
				foreach (keys %colorHash)
				{
					my $colorId = $_;
					my ($price_text,$price);
					if($content2 =~ m/\'$colorId\'\:\s*\{\s*\"(now)\"\:\s*\'([^>]*?)\'\,\s*\"(was)\"\:\s*\'([^>]*?)\'\,\s*\"(nowInt)\"\:\s*([^>]*?)\s*\,\s*\"(wasInt)\"\:\s*([^>]*?)\s*}/is)
					{
						my $now = $2;	my $was = $4;	my $cp = $6;
						if($now eq $was)
						{
							$price_text = $now;
						}
						else
						{
							$price_text = $now." ".$was;
						}
						$price_text = $price_text; 
						$price = $cp;	$price = $price; 	
					}
					foreach (keys %size)
					{
						my $tsize = $_;
						my $tsizeid = $size{$_};
						my $out_of_stock = 'y';
						$tsize =~s/_size//igs;
						$tsizeid =~s/_size//igs;
						my $size = $tsize;
						foreach (@StockVal)
						{	
							my $stockStatus = $_;
							if(($stockStatus =~ m/\"$tsizeid\"/is) and ($stockStatus =~ m/\"$colorId\"/is))
							{
								$out_of_stock = 'n'; last;					
							}
						}
						$count++;
						# print "$count :: $size-->$out_of_stock-->$colorHash{$colorId}-->$price_text-->$price\n";
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$colorHash{$colorId},$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=lc($colorId);
						push(@query_string,$query);
					}
				}
			}
			else
			{
				foreach (keys %colorHash)
				{
					my $colorId = $_;
					my ($price_text,$price);
					if($content2 =~ m/\'$colorId\'\:\s*\{\s*\"(now)\"\:\s*\'([^>]*?)\'\,\s*\"(was)\"\:\s*\'([^>]*?)\'\,\s*\"(nowInt)\"\:\s*([^>]*?)\s*\,\s*\"(wasInt)\"\:\s*([^>]*?)\s*}/is)
					{
						my $now = $2;	my $was = $4;	my $cp = $6;
						if($now eq $was)
						{
							$price_text = $now;
						}
						else
						{
							$price_text = $now." ".$was;
						}
						$price_text = $price_text; 
						$price = $cp;	$price = $price; 	
					}
					my $out_of_stock = 'y';
					foreach (@StockVal)
					{	
						my $stockStatus = $_;
						if($stockStatus =~ m/\"color\"\:\"$colorId\"\,\"onHand\"\:\s*(\d+)\s*}/is)
						{
							my $stcount = $1;
							if($stcount >= 1)
							{
								$out_of_stock = 'n';
								last;
							}
						}
					}
					# print "$count :: $size-->$out_of_stock-->$colorHash{$colorId}-->$price_text-->$price\n";
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,'',$colorHash{$colorId},$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=lc($colorId);
					push(@query_string,$query);
				}
			}
		}
		foreach (keys %colorHash)
		{
			my $colorId = $_;
			if($content2 =~ m/\.swatch\-$colorId\s*span\s*\{background\-image\:\s*url\(([^>]*?)\)/is)  ##Swatches..
			{
				my $swatch = $1;
				my $img_file;
				if($content2 =~ m/<option\s*value\=\"$colorId\"\s*selected\=\"selected\"/is)
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch','zappos-us');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$colorId;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
				else
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch','zappos-us');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$colorId;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
			}
		}
		my $stylecont = $1 if($content2 =~ m/var\s*styleIds\s*\=\s*\{([\w\W]*?)\}/is);
		my %styleids;
		while($stylecont =~ m/\'([^>]*?)\'\:\s*([^>]*?)\s*(?:\,|$)/igs)
		{
			$styleids{$1} = $2;
		}
		foreach (keys %styleids)
		{
			my $colorid = $_;
			my $key = $styleids{$colorid};
			if($content2 =~ m/filename\:\s*\'([^>]*?)\'/is)
			{
				my $defaultFlag = 0;
				while($content2 =~ m/pImgs\[$key\]\s*\[\'4x\']\s*\[[^>]*?\]\s*\=\s*\{\s*filename\:\s*\'([^>]*?)\'/igs)
				{
					my $alt_image = $1;
					my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','zappos-us');
					if($alt_image =~ m/\s*$key\-p\s*\-/is)
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='Y';
						push(@query_string,$query);
						$defaultFlag++;
					}
					else
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
				if($defaultFlag == 0)
				{
					if($content2 =~ m/src\=\"([^>]*?)\"\s*class\=\"gae\-click\*Product\-Page\*Zoom\-In\*Image\-Click\"/is)
					{
						my $alt_image = $1;
						my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','zappos-us');			
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
				}
				
			}
			elsif($content2 =~ m/pImgs\s*\[$key]\s*\[\'MULTIVIEW\'\]\s*\[\'\w+\'\]\s*\=\s*\'([^>]*?)\'/is)
			{
				my $defaultFlag = 0;
				while($content2 =~ m/pImgs\s*\[$key]\s*\[\'MULTIVIEW\'\]\s*\[\'\w+\'\]\s*\=\s*\'([^>]*?)\'/igs)
				{
					my $alt_image = $1;
					my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','zappos-us');
					if($alt_image =~ m/\s*$key\-p\s*\-/is)
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='Y';
						push(@query_string,$query);
						$defaultFlag++;
					}
					else
					{
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='n';
						push(@query_string,$query);
					}
				}
				if($defaultFlag == 0)
				{
					if($content2 =~ m/src\=\"([^>]*?)\"\s*class\=\"gae\-click\*Product\-Page\*Zoom\-In\*Image\-Click\"/is)
					{
						my $alt_image = $1;
						my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','zappos-us');			
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
				}
			}
			elsif($content2 =~ m/src\=\"([^>]*?)\"\s*class\=\"gae\-click\*Product\-Page\*Zoom\-In\*Image\-Click\"/is)
			{
				my $alt_image = $1;
				my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product','zappos-us');			
				my ($img_object,$flag) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object} = $colorid;
				$hash_default_image{$img_object} = 'y';
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
		my($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		# push(@query_string,$qry); 
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		ENDOFF:
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
