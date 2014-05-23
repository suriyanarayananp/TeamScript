#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Zalando_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Zalando_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;	
	my $retailer_id=shift;
	my $logger = shift;
	$robotname='Zalando-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Zal';
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
	
	my $skuflag = 0;
	my $imageflag = 0;
	
	if($product_object_key)
	{		
		$url =~ s/^\s+|\s+$//g;
		my $url3=$url;
		my $passing_url=$url3;
		my $content2 = get_content($passing_url);
		my $id;
		my @query_string;
		if($content2=~m/Sorry\!\s*This\s*item\s*is\s*currently\s*not\s*available\.\s*Here\s*is\s*a\s*list\s*of\s*other\s*products\s*you\s*may\s*like\./is)
		{
			goto PNF;
		}
		if($url3 =~ m/\.co\/([^<]*?)\s*(?:\?|$)/is )
		{
			$id = &DBIL::Trim($1);
		}
		my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color);
		if ( $content2 =~ m/class\=\"boxPrice\">([\w\W]*?)<\/div>\s*<\/div>/is )
		{
			$price_text=$1;
			$price_text =~ s/Saving//igs if($price_text =~ m/<div\s*class\=\"overflow\s*hidden\">/is);
			$price_text=~s/<[^>]*?>/ /igs;
			$price_text =~ s/\&euro\;/€/ig;
			$price_text =~ s/\,/./ig;
			$price_text =~ s/\Â//ig;
			$price_text =~ s/\s+/ /ig;
			$price_text = &DBIL::Trim($price_text);
		}	
		if ( $content2 =~ m/<span\s*class\=\"price\s*specialPrice\s*nowrap\"\s*id\=\"articlePrice\">([^>]*?)<\/span>/is )
		{
			$price=$1;
			$price=~s/<span[\w\W]*?$//igs;
			$price=~s/[^\d\.\,]+//igs;
			$price=~s/\,//igs;
			$price = &DBIL::Trim($price);		
		}
		elsif ( $content2 =~ m/<span\s*itemprop\=\"price\">([^>]*?)<\/span>/is )
		{
			$price=$1;
			$price=~s/<span[\w\W]*?$//igs;
			$price=~s/[^\d\.\,]+//igs;
			$price=~s/\,//igs;
			$price = &DBIL::Trim($price);
		}
		#product_id
		if ( $content2=~m/\"sku\:([^>]*?)\-/is )
		{
			$product_id =$1;
			$product_id=~s/<[^>]*?>//igs;
			$product_id=&DBIL::Trim($product_id);
			my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname, $retailer_id);
			goto ENDOFF if($ckproduct_id == 1);
			undef ($ckproduct_id);
		}
		#product_name
		$product_name = &DBIL::Trim($1) if ( $content2 =~ m/itemprop\=\"name\">\s*([^>]*?)\s*<\/span>/is );
		$product_name =~ s/\'/\'\'/igs;
		#Brand
		if ( $content2 =~ m/itemprop\=\"brand\">\s*([^>]*?)\s*<\/span>/is )
		{
			$brand = &DBIL::Trim($1);
			print "brand::$brand\n";
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);				
			}
		}
		#Product_Detail
		if ( $content2 =~ m/Product\s*details<\/h2>([\w\W]*?)<\/ul>\s*<\/div>/is )
		{
			$prod_detail =$1;
			$prod_detail=~s/<[^>]*?>//igs;
			$prod_detail=~s/&#034;/"/igs;
			$prod_detail = &DBIL::Trim($prod_detail);
		}
		if($prod_detail eq '')
		{
			$prod_detail = '-';
		}
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);
		#swatched
		my $DefaultSwatch;
		$DefaultSwatch = $1 if($content2 =~ m/class\=\"[^>]*?active\s*\">\s*<a\s*[^>]*?>\s*<img\s*src\=\"([^>]*?)\"\s*alt\=\"([^>]*?)\"\s*title\=\"([^>]*?)\"/is);
		my (@colors, @colorList);
		if($content2 =~ m/<ul\s*class\=\"colorList[^>]*?>([\w\W]*?)<\/ul>/is)
		{
			my $SwatchCont = $1;
			while($SwatchCont =~ m/href\=\"([^>]*?)\"/igs)
			{
				push @colorList,"http://www.zalando.co.uk".$1;
			}
			while ($SwatchCont =~ m/src\=\"([^>]*?)\"\s*alt\=\"[^>]*?\"\s*title\=\"([^>]*?)\"/igs)
			{
				my $swatch = $1;
				my $colorid;
				$colorid = &DBIL::Trim($1) if($swatch =~ m/\-([^>]*?)\@/is);
				if($swatch eq $DefaultSwatch)
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch','zalando-uk');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$colorid;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
				else
				{
					my ($imgid,$img_file) = &DBIL::ImageDownload($swatch,'swatch','zalando-uk');
					my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$swatch,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$imageflag = 1 if($flag);
					$image_objectkey{$img_object}=$colorid;
					$hash_default_image{$img_object}='n';
					push(@query_string,$query);
				}
			}
		}
		my ($DefaultColor,%AllColor,@totalColor);
		$DefaultColor = &DBIL::Trim($1) if($content2 =~ m/\"productColor\"\:\"([^>]*?)\"/is);
		if(@colorList)
		{
			foreach(@colorList)
			{
				# size & out_of_stock
				my $colorUrl = $_;
				my $content3 = &get_content($colorUrl);
				my ($DefaultColor,$colorid);
				if ( $content3 =~ m/class\=\"boxPrice\">([\w\W]*?)<\/div>\s*<\/div>/is )
				{
					$price_text=$1;
					$price_text =~ s/Saving//igs if($price_text =~ m/<div\s*class\=\"overflow\s*hidden\">/is);
					$price_text=~s/<[^>]*?>/ /igs;
					$price_text =~ s/\&euro\;/€/ig;
					$price_text =~ s/\,/./ig;
					$price_text =~ s/\Â//ig;
					$price_text =~ s/\s+/ /ig;
					$price_text = &DBIL::Trim($price_text);
				}	
				$DefaultColor = &DBIL::Trim($1) if($content3 =~ m/\"productColor\"\:\"([^>]*?)\"/is);
				if(grep( /$DefaultColor/, @totalColor ))
				{
					$AllColor{$DefaultColor}++;
					my $tcolor = $DefaultColor.'('.$AllColor{$DefaultColor}.')';
					push @totalColor,$tcolor;
					$DefaultColor = $tcolor;
				}
				else
				{
					push @totalColor,$DefaultColor;
					$AllColor{$DefaultColor}++;
					$DefaultColor = $DefaultColor;
				}
				if($DefaultColor eq '')
				{
					$DefaultColor = $1 if($product_name =~ m/\-\s*([^\-]*?)\s*$/is);
				}
				my ($product_name,@size_ID);
				$product_name = &DBIL::Trim($1) if($content3=~ m/\"productName\"\:\"([^>]*?)\"/is);
				$colorid = $1 if($content3=~ m/\"productSku\"\:\"[^>]*?\-([^>]*?)\"/is);
				while($content3 =~ m/<option\s*value\=\"([^>]*?)\"\s*data\-quantity[^>]*?>\s*([^>]*?)\s*<\/option>/igs)
				{
					push @size_ID, $1;
				}
				if(@size_ID)
				{
					foreach (@size_ID)
					{
						my $sizeID = $_;
						my ($price,$qty,$size);
						if($content3 =~ m/\"$sizeID\"\:\s*\{([\w\W]*?)\}/is)
						{
							my $skuCont = $1;
							$price = $1 if($skuCont =~ m/price\:\s*\"([^>]*?)\"\,/is);
							$qty = $1 if($skuCont =~ m/quantity\:\s*\"([^>]*?)\",/is);
							$size = $1 if($skuCont =~ m/\bsize\:\s*\"([^>]*?)\",/is);
							my $out_of_stock = 'n';
							if($qty <= 0)
							{
								$out_of_stock = 'y';
							}
							$price =~ s/\./dot/igs;
							$price =~ s/\W+//igs;
							$price =~ s/dot/\./igs;
							print "$size -- $price -- $out_of_stock -- $price_text\n";
							my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$colorUrl,$product_name,$price,$price_text,$size,$DefaultColor,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$skuflag = 1 if($flag);
							$sku_objectkey{$sku_object}=$colorid;
							push(@query_string,$query);
						}
					}
				}
				elsif($content3 =~ m/Availability\s*\:\s*<\/strong>\s*<[^>]*?>\s*Not\s*in\s*stock<\/strong>/is) ##No Size with Out of Stock
				{
					my $out_of_stock = 'y';
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$colorUrl,$product_name,$price,$price_text,'',$DefaultColor,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$colorid;
					push(@query_string,$query);
				}
				my $defaulImage;
				$defaulImage = &DBIL::Trim($1) if($content3 =~ m/href\=\"([^>]*?)\"\s*[^>]*?class\=\"pdsImage\"\s*name\=\"pds\.productviewcontent\.image\.full\"/is);
				if($content3 =~ m/<div\s*id\=\"moreImages\"([\w\W]*?)<\/div>/is)
				{
					my $ImageCont = $1;
					while ($ImageCont =~ m/href\=\"([^>]*?)\"/igs)
					{
						my $imageurl = &DBIL::Trim($1);
						if($defaulImage eq $imageurl)
						{
							my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product','zalando-uk');
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}=$colorid;
							$hash_default_image{$img_object}='y';
							push(@query_string,$query);
						}
						else
						{
							my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product','zalando-uk');
							my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
							$imageflag = 1 if($flag);
							$image_objectkey{$img_object}=$colorid;
							$hash_default_image{$img_object}='n';
							push(@query_string,$query);
						}
					}
				}
			}
		}
		else
		{
			my ($colorid,$size,@size_ID);
			my ($DefaultColor);
			$DefaultColor = &DBIL::Trim($1) if($content2 =~ m/\"productColor\"\:\"([^>]*?)\"/is);
			if($DefaultColor eq '')
			{
				$DefaultColor = $1 if($product_name =~ m/\-\s*([^\-]*?)\s*$/is);
			}
			$colorid = $1 if($content2=~ m/\"productSku\"\:\"[^>]*?\-([^>]*?)\"/is);
			while($content2 =~ m/<option\s*value\=\"([^>]*?)\"\s*data\-quantity[^>]*?>\s*([^>]*?)\s*<\/option>/igs)
			{
				push @size_ID, $1;
			}
			if(@size_ID)
			{
				foreach (@size_ID)
				{
					my $sizeID = $_;
					my ($price,$qty,$size);
					if($content2 =~ m/\"$sizeID\"\:\s*\{([\w\W]*?)\}/is)
					{
						my $skuCont = $1;
						$price = $1 if($skuCont =~ m/price\:\s*\"([^>]*?)\"\,/is);
						$qty = $1 if($skuCont =~ m/quantity\:\s*\"([^>]*?)\",/is);
						$size = $1 if($skuCont =~ m/\bsize\:\s*\"([^>]*?)\",/is);
						my $out_of_stock = 'n';
						if($qty <= 0)
						{
							$out_of_stock = 'y'
						}
						$price =~ s/\./dot/igs;
						$price =~ s/\W+//igs;
						$price =~ s/dot/\./igs;
						print "$size -- $price -- $out_of_stock -- $price_text\n";
						my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$DefaultColor,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$skuflag = 1 if($flag);
						$sku_objectkey{$sku_object}=$colorid;
						push(@query_string,$query);
					}
				}
			}
			else
			{
				my $avail = $1 if($content2 =~ m/itemprop\=\"availability\"\s*content\=\"([^>]*?)\">/is);
				my $out_of_stock = 'y' if($avail =~ m/\s*out_of_stock\s*/is);
				$out_of_stock = 'n' if($avail =~ m/\s*in_stock\s*/is);
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$DefaultColor,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$colorid;
				push(@query_string,$query);
			}
			my $defaulImage;
			$defaulImage = &DBIL::Trim($1) if($content2 =~ m/href\=\"([^>]*?)\"\s*[^>]*?class\=\"pdsImage\"\s*name\=\"pds\.productviewcontent\.image\.full\"/is);
			if($content2 =~ m/<div\s*id\=\"moreImages\"([\w\W]*?)<\/div>/is)
			{
				my $ImageCont = $1;
				while ($ImageCont =~ m/href\=\"([^>]*?)\"/igs)
				{
					my $imageurl = &DBIL::Trim($1);
					if($defaulImage eq $imageurl)
					{
						my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product','zalando-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='y';
						push(@query_string,$query);
					}
					else
					{
						my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product','zalando-uk');
						my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
						$imageflag = 1 if($flag);
						$image_objectkey{$img_object}=$colorid;
						$hash_default_image{$img_object}='n';
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
		my($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,lc($product_id),$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
		# push(@query_string,$qry);
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		ENDOFF:
			print "";
	}
}1;
sub get_content
{
	my $url = shift;
	my $rerun_count;
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp\;//g;
	$url =~ s/^\"|\"$//g;
	Home:
	my $req = HTTP::Request->new(GET=>$url);
    $req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $res = $ua->request($req);
	my $code=$res->code;
	print "CODE :: $code\n";
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