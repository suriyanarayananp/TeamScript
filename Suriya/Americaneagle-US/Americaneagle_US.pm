#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Americaneagle_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Americaneagle_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;	
	my $retailer_id=shift;
	my $logger = shift;
	$robotname='Americaneagle-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Ame';
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
	if($product_object_key)
	{
		my $url3=$url;
		$url3 =~ s/^\s+|\s+$//g;
		$product_object_key =~ s/^\s+|\s+$//g;
		$url3='http://www.ae.com'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = &get_content($url3);
		goto PNF if($content2 =~ m/>\s*Our\s*Apologies\s*<\/h2>/is);
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour);
		#price_text
		if($content2 =~ m/<div\s*class\=\"listPrice\">([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $PriceCont = $1;
			# $PriceCont =~ s/<span\s*class\=\"cents\">/\./igs;
			$PriceCont =~ s/<[^>]*?>|USD//igs;
			$price_text = &DBIL::Trim($PriceCont);
			$price_text =~ s/\s+\./\./igs;
			$price_text =~ s/\s+/ /igs;
		}
		elsif($content2 =~ m/<div\s*class\=\"price\s*(?:salePrice)?\">([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $PriceCont = $1;
			# $PriceCont =~ s/<span\s*class\=\"cents\">/\./igs;
			$PriceCont =~ s/<[^>]*?>|USD//igs;
			$price_text = &DBIL::Trim($PriceCont);
			$price_text =~ s/\s+\./\./igs;
			$price_text =~ s/\s+/ /igs;
		}
		elsif($content2 =~ m/<div\s*class\=\"price\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $PriceCont = $1;
			# $PriceCont =~ s/<span\s*class\=\"cents\">/\./igs;
			$PriceCont =~ s/<[^>]*?>|USD//igs;
			$price_text = &DBIL::Trim($PriceCont);
			$price_text =~ s/\s+\./\./igs;
			$price_text =~ s/\s+//igs;
		}
		#price
		if($content2 =~ m/<div\s*class\=\"price\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $PriceCont = $1;
			$PriceCont =~ s/\$//igs;
			# $PriceCont =~ s/<span\s*class\=\"cents\">/\./igs;
			$PriceCont =~ s/[^\d\.]+|\,//igs;
			$price = &DBIL::Trim($PriceCont);
		}
		elsif($content2 =~ m/<div\s*class\=\"price\s*salePrice\"[^>]*?>([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $PriceCont = $1;
			$PriceCont =~ s/\$//igs;
			# $PriceCont =~ s/<span\s*class\=\"cents\">/\./igs;
			$PriceCont =~ s/[^\d\.]+|\,//igs;
			$price = &DBIL::Trim($PriceCont);
		}
		#product_id
		if ( $content2 =~ m/s\.products\=\'([^>]*?)\'\;/is)
		{
			$product_id = &DBIL::Trim($1);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname, $retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#product_name
		if ( $content2 =~ m/<h1[^>]*?>\s*([^>]*?)\s*<\/h1>/is)
		{
			$product_name = &DBIL::Trim($1);
		}
		#Brand
		if ( $content2 =~ m/\"brandName\"\:\"([^>]*?)\"/is )
		{
			$brand = &DBIL::Trim($1);
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#description&details
		if ($content2 =~ m/leadingEquity\">([\w\W]*?)<\/div>([\w\W]*?)<div\s*class\=\"pBVoverall\">/is)
		{
			$description = &DBIL::Trim($1);
			$prod_detail = &DBIL::Trim($2);
		}
		elsif ($content2 =~ m/leadingEquity\">([\w\W]*?)<\/div>([\w\W]*?)<\/span>/is)
		{
			$description = &DBIL::Trim($1);
			$prod_detail = &DBIL::Trim($2);
		}
		$prod_detail =~ s/\&bull\;/*/igs;
		#colour
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);
		my ($s1, $l1);
		my ($totalsize, $totallength);
		my $scount == 0;
		while($content2 =~ m/\"values\"\:\[([^<]*?)\]\,\"label\"\:\"([^>]*?)\"/igs)
		{
			if($scount == 0)
			{
				$totalsize = $1;
				$l1 = &DBIL::Trim($2);
				$scount++;
			}
			else
			{
				$totallength = $1;
				$s1 = &DBIL::Trim($2);
				$scount++;
			}
		}
		my (@tsizes,@tlength);
		$s1 = ucfirst($s1);
		$l1 = ucfirst($l1);
		if($scount == 1)
		{
			@tsizes = split(/\,/, $totalsize);
		}
		elsif($scount > 1)
		{
			@tsizes = split(/\,/, $totallength);
			@tlength = split(/\,/, $totalsize);
		}
		if($content2 =~ m/swatch_link\s*selected/is)
		{
			my $colorids;
			$colorids = $1 if($content2 =~ m/\"availableColorIds\"\:\[([^>]*?)\]/is);
			@colorsid = split(/\,/, $colorids);
			foreach (@colorsid)
			{
				my $colorvalue = $_;
				$colorvalue =~ s/\"//igs;
				if($content2 =~ m/\"$colorvalue\"\:([\w\W]*?)factoryExclusive/is)   ##Size
				{
					my $colorCont = $1;
					my $color;
					$color = &DBIL::Trim($1) if($colorCont =~ m/colorName\"\:\"([^>]*?)\"/is);
					if(@tsizes > 0 and @tlength>0)
					{
						foreach (@tsizes)
						{
							my $ts = $_;
							foreach(@tlength)
							{
								my $tl = $_;
								if($colorCont=~m/\"sizeName\"\:\[$ts\,$tl\]\,(?:\"canShipCanTerr\"\:[a-z]+\,)?\"isAvailable\"\:([^>]*?)\}/is)
								{
									my $avail = &DBIL::Trim($1);
									my $out_of_stock;
									if($avail eq 'true')
									{
										$out_of_stock = 'n';
									}
									else
									{
										$out_of_stock = 'y';
									}
									my $size = "$s1 $ts $l1 $tl";
									$size =~ s/\"|\'//igs;
									$price = 'null' if($price eq '');
									my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,	$Retailer_Random_String,$robotname,$excuetionid);
									$skuflag = 1 if($flag);
									$sku_objectkey{$sku_object}=$colorvalue;
									push(@query_string,$query);
								}
								else
								{
									my $out_of_stock='y';
									my $size = "$s1 $ts $l1 $tl";
									$size =~ s/\"|\'//igs;
									$price = 'null' if($price eq '');
									my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,	$Retailer_Random_String,$robotname,$excuetionid);
									$skuflag = 1 if($flag);
									$sku_objectkey{$sku_object}=$colorvalue;
									push(@query_string,$query);
								}
							}
						}
					}
					else
					{
						foreach (@tsizes)
						{
							my $ts = $_;
							if($colorCont =~ m/\"sizeName\"\:\[$ts\]\,(?:\"canShipCanTerr\"\:[a-z]+\,)?\"isAvailable\"\:([^>]*?)\}/is)
							{
								my $avail = &DBIL::Trim($1);
								my $out_of_stock;
								if($avail eq 'true')
								{
									$out_of_stock = 'n';
								}
								else
								{
									$out_of_stock = 'y';
								}
								my $size = "$ts";
								$size =~ s/\"|\'//igs;
								$price = 'null' if($price eq '');
								my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,	$Retailer_Random_String,$robotname,$excuetionid);
								$skuflag = 1 if($flag);
								$sku_objectkey{$sku_object}=$colorvalue;
								push(@query_string,$query);
							}
							else
							{
								my $out_of_stock = 'y';
								my $size = "$ts";
								$size =~ s/\"|\'//igs;
								$price = 'null' if($price eq '');
								my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
								$skuflag = 1 if($flag);
								$sku_objectkey{$sku_object}=$colorvalue;
								push(@query_string,$query);
							}
						}
					}
				}
				if($content2 =~ m/class\=\"swatch_link\s*([^>]*?)\"[^>]*?data\-colorid\=\"$colorvalue\">\s*<img\s*class\=\"swatch\"\s*src\=\"([^>]*?)\"/is)  ## Swatches
				{
					my $swatchcheck = $1;
					my $swatch = &DBIL::Trim($2);
					$swatch='http:'.$swatch unless($swatch=~m/^\s*http\:/is);
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$colorvalue;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
				my $colors = &DBIL::Trim($1) if($content2 =~ m/\"$colorvalue\"\:\{\"colorName\"\:\"([^>]*?)\"\,/is);
				###Insert Tag values
				# &DBIL::SaveTag('Color',lc($colors),$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		elsif($content2 =~ m/\"displaySizes\"\:\[\{\"values\"\:\[([^>]*?)\]\,/is)
		{
			my $sizeVal = $1;
			my @sizes = split(/\,/, $sizeVal);
			my $colorvalue;
			$colorvalue = &DBIL::Trim($1) if($content2 =~ m/class\=\"color\">\s*([^>]*?)\s*<\/span>/is);
			my $color;
			if($content2 =~ m/\"$colorvalue\"\:([\w\W]*?)factoryExclusive/is)   ##Size
			{
				my $colorCont = $1;
				$color = &DBIL::Trim($1) if($colorCont =~ m/colorName\"\:\"([^>]*?)\"/is);
			}
			my $colorv;
			my $out_of_stock = 'n';
			foreach (@sizes)
			{
				my $sizevalue = $_;
				$sizevalue =~ s/\"//igs;
				my ($s, $l);
				if($scount > 0)
				{
					if($sizevalue =~ m/\,/is)
					{
						($s, $l) = split(/\,/, $sizevalue);
						$sizevalue = "$s1 $s $l1 $l";
						undef($s);	undef($l);
					}
				}
				$price = 'null' if($price eq '');
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$sizevalue,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$colorvalue;
				push(@query_string,$query);
			}
		}
		#Image
		my $DefaultImg;
		$DefaultImg = "http:".$1 if($content2 =~ m/fullImage\s*pdpSize_img\">\s*<img\s*src\=\"([^>]*?)\"\s*alt\=\"([^>]*?)\"/is);
		while($content2 =~ m/newArrival\s*\"\s*\:[^>]*?\,\s*\"colorPrdId\"\:\"([^>]*?)\"\,[^>]*?\"imgViews\":\[([^>]*?)\]/igs)
		{
			my $cid = $1;
			my $views = $2;
			$views =~ s/\"//igs;
			my @view = split(/\,/, $views);
			my $color_id=$1 if($cid=~m/_([^_]+)?$/is);
			my $viewcount = 0;
			foreach (@view)
			{
				my $finalView = $_;
				my $alt_image = "http://pics.ae.com/is/image/aeo/".$cid.$finalView."?maskuse=off&wid=1119&size=1121,1254&fit=crop&qlt=70,0";
				$viewcount++;
				if($viewcount == 1)
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$color_id;
					$hash_default_image{$img_object}='y';
					push(@query_string,$query);
				}
				else
				{
					# $alt_image =~ s/\?[^>]*?$//igs;
					# my $tval = $1 if($DefaultImg =~ m/(\?[^>]*?)$/is);
					# $alt_image = $alt_image.$tval;
					my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product',$retailer_name);
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$color_id;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
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
		ENDOFF:
		$dbh->commit();
	}
}1;
sub get_content()
{
	my $url = shift;
	my $rerun_count=0;
	$url =~ s/^\s+|\s+$//g;
	Home:
	my $req = HTTP::Request->new(GET=>$url);
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	print "\nCODE :: $code";
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
