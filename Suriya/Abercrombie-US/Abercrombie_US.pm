#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Abercrombie_US;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use String::Random;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";  # USER DEFINED MODULE DBIL.PM
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Abercrombie_US_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;	
	my $retailer_id=shift;
	my $logger = shift;
	$robotname='Abercrombie-US--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Abe';
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
	my @query_string;
	####Variable Initialization##############
	my $url3=$url;
	$url3 =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	$url3='http://www.abercrombie.com'.$url3 unless($url3=~m/^\s*http\:/is);
	my $content2 = &get_content($url3);
	goto PNF if($content2 =~ m/PAGE\s*MAY\s*NO\s*LONGER\s*EXIST/is);
	my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour);
	if ( $content2 =~ m/<h1\s*class\=\"name\"[^>]*?>\s*([\w\W]*?)<\/h1>/is)
	{
		$product_name = &DBIL::Trim($1);
	}
	#price_text 
	if($content2 =~ m/data\-priceFlag\=\"\d+\">\s*([\w\W]*?)<\/div>/is) 
	{ 
		my $PriceCont = $1; 
		$price_text = &DBIL::Trim($PriceCont); 
	} 
	#price 
	if($content2 =~ m/data\-priceFlag\=\"\d+\">\s*([\w\W]*?)<\/div>/is) 
	{ 
		my $PriceCont = $1; 
		$price = &DBIL::Trim($1) if($PriceCont =~ m/class\=\"offer\-price\">\s*\$([^>]*?)\s*<\/h4>/is); 
		if(($price eq '') or ($price =~ m/\|/is) )
		{
			if($PriceCont =~ m/\"offer\-price\">\s*\$([^>]*?)\s*\|/is)
			{
				$price = &DBIL::Trim($1);
				$price =~ s/\$//igs;
			}
			elsif($PriceCont =~ m/class\=\"offer\-price\">\s*\$([^>]*?)\s*<\/h4>/is)
			{
				$price = &DBIL::Trim($1);
				$price =~ s/\$//igs;
			}
		}
	}
	# my $pcount = 0;
	my $mflag=0;
	# $pcount = () = $content2 =~ m/<h1\s*class\=\"name\"[^>]*?>\s*([\w\W]*?)<\/h1>/igs;
	# if($pcount > 1)
	# {
		# $mflag = 1;
		# goto PNF;
	# }
	#product_id 
	if ( $content2 =~ m/>\s*web\s*item\s*\:\s*<span\s*class\=\"number\">\s*([^>]*?)\s*<\/span>/is) 
	{ 
		$product_id = &DBIL::Trim($1); 
		my $ckproduct_id = &DBIL::UpdateProducthasTag($product_id, $product_object_key, $dbh,$robotname, $retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	} 
	#Brand 
	if ( $content2 =~ m/type\=\"hidden\"\s*name\=\"brand\"\s*value\=\"([^>]*?)\"/is ) 
	{ 
		$brand = &DBIL::Trim($1); 
		$brand='Abercrombie & Fitch';
		if ( $brand !~ /^\s*$/g ) 
		{ 				
			&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		} 
	}
	#description&details 
	if ( $content2 =~ m/class\=\'details\-accordion\-content\'>\s*([\w\W]*?)<\/div>/is ) 
	{ 
		my $desc_content = $1; 
		if ( $desc_content =~ m/itemprop\=\"description\">\s*([\w\W]*?)<br>\s*<br>\s*([\w\W]*?)<\/p>/is ) 
		{ 
			$description = &DBIL::Trim($1); 
			$prod_detail = &DBIL::Trim($2); 
		} 
		else
		{ 
			$description = &DBIL::Trim($desc_content); 
			$prod_detail = &DBIL::Trim($desc_content); 
		} 
	}
	#colour 
	my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key,@seqno,$storeid,$catlogid);
	$storeid = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"storeId\"\s*value\=\"([^>]*?)\"/is); 
	$catlogid = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"catalogId\"\s*value\=\"([^>]*?)\"/is);
	my $poids = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"productId\"\s*value\=\"([^>]*?)\"/is);
	if($content2 =~ m/\"swatch\-link\"\s*href\=\"([^>]*?)\"\s*data\-seq\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"\s*data\-categoryid\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\"/is) 
	{
		while($content2 =~ m/\"swatch\-link\"\s*href\=\"([^>]*?)\"\s*data\-seq\=\"([^>]*?)\"\s*data\-productId\=\"([^>]*?)\"\s*data\-categoryid\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\"/igs) 
		{ 
			my $swatchlink = $1; 
			my $dataseq = $2; 
			my $poid = $3; 
			my $catid = $4; 
			my $color = &DBIL::Trim($5); 
			next if($poids ne $poid);
			push @seqno, $dataseq;
			my $colorURL = "http://www.abercrombie.com/webapp/wcs/stores/servlet/GetColorJSON?storeId=$storeid&catalogId=$catlogid&categoryId=$catid&productId=$poid&seq=$dataseq"; 
			my $colorCont = &get_content($colorURL); 
			if($colorCont =~ m/\"items\"\s*\:\s*\[([\w\W]*?)\]/is) 
			{ 
				my $colorBlock1 = $1; 
				my %sizeHash;
				while($colorBlock1 =~ m/\{([\w\W]*?)\}/igs) 
				{ 
					my $colorBlock2 = $1; 
					my $size = &DBIL::Trim($1) if($colorBlock2 =~ m/\"size\"\s*\:\s*\"([^>]*?)\"/is); 
					my $out_of_stock; 
					if($colorBlock2 =~ m/\"soldOut\"\:\s*\"true\"/is) 
					{ 
						$out_of_stock = 'y'; 
					} 
					elsif($colorBlock2 =~ m/\"soldOut\"\:\s*\"false\"/is) 
					{ 
						$out_of_stock = 'n'; 
					}
					$sizeHash{$size}=$out_of_stock;
				} 
				foreach (keys %sizeHash)
				{
					my $tsize = $_;
					
					my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$tsize,$color,$sizeHash{$tsize},$dbh,$Retailer_Random_String,$robotname,$excuetionid);
					$skuflag = 1 if($flag);
					$sku_objectkey{$sku_object}=$dataseq;
					push(@query_string,$query);
				}
				
			} 
			# &DBIL::SaveTag('Color',lc($color),$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
	}
	else
	{
		my($dataseq, $poid, $catid, $color, $colorURL);
		$dataseq = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"cseq\"\s*value\=\"([^>]*?)\"/is); 
		$poid = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"productId\"\s*value\=\"([^>]*?)\"/is); 
		$catid = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"catId\"\s*value\=\"([^>]*?)\"/is); 
		$color = &DBIL::Trim($1) if($content2 =~ m/type\=\"hidden\"\s*name\=\"color\"\s*value\=\"([^>]*?)\"/is); 
		$colorURL = "http://www.abercrombie.com/webapp/wcs/stores/servlet/GetColorJSON?storeId=$storeid&catalogId=$catlogid&categoryId=$catid&productId=$poid&seq=$dataseq"; 
		my $colorCont = &get_content($colorURL); 
		push @seqno, $dataseq;
		if($colorCont =~ m/\"items\"\s*\:\s*\[([\w\W]*?)\]/is) 
		{ 
			my $colorBlock1 = $1; 
			my %sizeHash;
			while($colorBlock1 =~ m/\{([\w\W]*?)\}/igs) 
			{ 
				my $colorBlock2 = $1; 
				my $size = &DBIL::Trim($1) if($colorBlock2 =~ m/\"size\"\s*\:\s*\"([^>]*?)\"/is); 
				my $out_of_stock; 
				if($colorBlock2 =~ m/\"soldOut\"\:\s*\"true\"/is) 
				{ 
					$out_of_stock = 'y'; 
				} 
				elsif($colorBlock2 =~ m/\"soldOut\"\:\s*\"false\"/is) 
				{ 
					$out_of_stock = 'n'; 
				}
				$sizeHash{$size}=$out_of_stock;
			} 
			foreach (keys %sizeHash)
			{
				my $tsize = $_;
				
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$tsize,$color,$sizeHash{$tsize},$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$dataseq;
				push(@query_string,$query);
			}
		} 
		# &DBIL::SaveTag('Color',lc($color),$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	#Image
	my $dftseqno = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"cseq\"\s*value\=\"([^>]*?)\"/is);
	my $DimageURL;
	$DimageURL = "http:".$1 if($content2 =~ m/class\=\"prod\-img\"\s*src\=\"([^>]*?)\?[^>]*?alt\=\"([^>]*?)\"/is);
	my $collection_id = $1 if($content2 =~ m/type\=\"hidden\"\s*name\=\"collection\"\s*value\=\"([^>]*?)\"/is); 
	foreach(@seqno)
	{
		my $seqid = $_;
		my $imageCollectionURL = "http://anf.scene7.com/is/image/anf?imageset={anf/anf_".$collection_id."_".$seqid.",anf/anf_".$collection_id."_".$seqid."_video1,anf/anf_".$collection_id."_".$seqid."_video2,anf/anf_".$collection_id."_".$seqid."_video3,anf/anf__video1,anf/anf__video2,anf/anf__video3}&req=set,json&defaultimage=anf/anf_".$collection_id."_".$seqid."_prod1&handler=scene7JSONResponse&id=colorSet&callback=jQuery1707709266603571354_1387185889160&_=1387185889637";
		my $colorCont = &get_content($imageCollectionURL); 
		my $defaultImg = $1 if($colorCont =~ m/\"i\"\:\{\"isDefault\"\:\"1\"\,\"n\"\:\"([^>]*?)\"/is);
		my @ImgArray;
		while($colorCont =~ m/\"i\"\:\{\"n\"\:\"([^>]*?)\"/igs)
		{
			push @ImgArray, $1;
		}
		my $viewcount = 0;
		foreach (@ImgArray)
		{
			my $imgSet = $_;
			$viewcount++;
			if($viewcount == 1)
			{
				my $alt_image;
				$alt_image = "http://anf.scene7.com/is/image/".$imgSet;
				my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$seqid;
				$hash_default_image{$img_object}='y';
				push(@query_string,$query);
			}
			else
			{ 
				my $alt_image;
				$alt_image = "http://anf.scene7.com/is/image/".$imgSet;
				my ($imgid,$img_file) = &DBIL::ImageDownload($alt_image,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$alt_image,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$seqid;
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
	my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id,$mflag);
	push(@query_string,$query1);
	push(@query_string,$query2);
	# my $qry=&DBIL::SaveProductCompleted($product_object_key,$retailer_id);
	# push(@query_string,$qry); 
	&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		
	ENDOFF:
	$dbh->commit();
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
