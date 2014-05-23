#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Coaststores_UK;
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";  # USER DEFINED MODULE DBIL.PM
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm";  
#require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm"; 
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
###########################################
my ($retailer_name,$robotname_detail,$robotname_list,$Retailer_Random_String,$pid,$ip,$excuetionid,$country,$ua,$cookie_file,$retailer_file,$cookie);
sub Coaststores_UK_DetailProcess()
{
	my $product_object_key=shift;
	my $url=shift;
	my $dbh=shift;
	my $robotname=shift;
	my $retailer_id=shift;
	$robotname='Coaststores-UK--Detail';
	####Variable Initialization##############
	$robotname =~ s/\.pl//igs;
	$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
	$retailer_name=$robotname;
	$robotname_detail=$robotname;
	$robotname_list=$robotname;
	$robotname_list =~ s/\-\-Detail/--List/igs;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$Retailer_Random_String='Coa';
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
		$url3='http://www.coast-stores.com'.$url3 unless($url3=~m/^\s*http\:/is);
		my $content2 = get_content($url3);
	
		my ($id,$price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color,$prodful_id);

		#Product id
		if ( $content2 =~ m/>\s*Product\s*code\s*\:\s*(?:(?:<[^>]*?>\s*)+\s*)?\s*([^<]*?)\s*</is )
		{
			$prodful_id = &DBIL::Trim($1); 
			$product_id = substr($prodful_id,0,8);
		}
		
		#Product price text
		if ( $content2 =~ m/<p[^<]*class\=\"product_price\">([\w\W]*?)<\/p>/is )
		{
			$price_text=$1;
			$price_text =~ s/\&pound\;/£/ig;
			
			if($price_text=~m/(\d[^>]*?)\s*<[^>]*?(?:\"|\')\s*was_price\s*(?:\"|\')\s*>/is)
			{
				$price=$1;
			}
			elsif($price_text=~m/Original\s*\:\s*\£\s*(\d[^>]*?)\s*From/is)
			{
				$price=$1;
			}
			elsif($price_text=~m/From\s*\:\s*\£\s*(\d[^>]*?)\s*to/is)
			{
				$price=$1;
			}
			elsif($price_text=~m/\£\s*(\d[^>]*?)$/)
			{
				$price=$1;
			}
			$price_text = &DBIL::Trim($price_text);
		}
		
		#Product name
		if ( $content2 =~ m/<h\d+[^<]*?\"product_title\">\s*([\w\W]*?)\s*<\/h1>/is )
		{
			$product_name = &DBIL::Trim($1);
		}
		#Product Brand
		if ( $content2 =~ m/<input[^<]*?name\=\"brand\"[^>]*? value\=\"([^<]*?)\"[^>]*?>/is )
		{
			$brand = &DBIL::Trim($1);
			
			if ( $brand !~ /^\s*$/g )
			{
				&DBIL::SaveTag('Brand',$brand,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		#Product Description
		if ( $content2 =~ m/<meta[^<]*?name\=\"description\"[^<]*?content\=\"([^>]*?)\"[^>]*?>/is )
		{
			$description = &DBIL::Trim($1);
		}
		#Product Detail
		if ( $content2 =~ m/<dd[^<]*?class\=\"product_specifics\">\s*([\w\W]*?)\s*<\/dd>/is )
		{
			$prod_detail = &DBIL::Trim($1);
		}
		#Product colour
		if ( $content2 =~ m/<p>\s*colo(?:u*)r\:\s*<\/p>\s*<ul[^>]*?>\s*([\w\W]*?)\s*<\/ul>/is )  	
		{ 		
			my $c=$1;
			
			if($c=~m/<li[^>]*?class\s*\=\s*\"\s*selected\s*\"[^>]*?>\s*(?:\s*<[^>]*?>\s*)+\s*(\w[^<]*)</is)
			{
				$color = &DBIL::Trim($1);
				&DBIL::SaveTag('Colour',$color,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
		}
		my (%sku_objectkey,%image_objectkey,%hash_default_image,@colorsid,@image_object_key,@sku_object_key);
		#Product swatch Image Url
		if ( $content2 =~ m/<p>\s*colo(?:u)r\:\s*<\/p>\s*<ul[^>]*?>\s*([\w\W]*?)\s*<\/ul>/is )
		{
			my $swatch_content=$1;
			
			if($swatch_content=~m/<li[^>]*?class\s*\=\s*\"\s*selected\s*\"[^>]*?>\s*(?:(?:\s*<[^>]*?>\s*)+\s*\w[^<]*<[^>]*?>\s*)?<img[^<]*?src\=\"([^<]*?)\"/is)
			{
				my $imageurl=$1;
				
				unless($imageurl=~m/^\s*http/is)
				{
					$imageurl='http://www.coast-stores.com'.$imageurl;
				}
				
				$imageurl='http:'.$imageurl unless($imageurl=~m/^\s*http\:/is);
				my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'swatch',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'swatch',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$color;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
		}
		#Product size & out_of_stock
		if ( $content2 =~ m/>\s*select\s*size\s*<[^>]*?>[\w\W]*?<ul>([\w\W]*?)\s*<\/ul>/is )
		{
			my $size_content = $1;
			while ( $size_content =~ m/<li[^>]*?class\=\"([^<]*?)\">\s*<a[^>]*?>([\w\W]*?)\s*<\/a>|<li[^>]*?class\=\"([^<]*?)\">\s*<label[^>]*?>([\w\W]*?)<\/label>/igs )
			{
				my $size = &DBIL::Trim($2.$4);
				my $out_of_stock = &DBIL::Trim($1.$3);
				$out_of_stock=~s/^\s*no_stock\s*$/y/ig;
				$out_of_stock=~s/\s*in_stock\s*$/n/ig;
				$out_of_stock=~s/\s*in_stock\s*low_stock\s*/n/ig;
				
				my ($sku_object,$flag,$query) = &DBIL::SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$skuflag = 1 if($flag);
				$sku_objectkey{$sku_object}=$color;
				push(@query_string,$query);
			}
		}
		#Main Image url
		if ( $content2 =~ m/<img[^<]*?id\=\s*\Wmain_image\W[^<]*?src\=\"([^<]*?)\"/is )
		{
			my $imageurl = &DBIL::Trim($1);
			unless($imageurl=~m/^\s*http/is)
			{
				$imageurl='http://www.coast-stores.com'.$imageurl;
			}
			my ($imgid,$img_file) = &DBIL::ImageDownload($imageurl,'product',$retailer_name);
			my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$imageurl,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
			$imageflag = 1 if($flag);
			$image_objectkey{$img_object}=$color;
			$hash_default_image{$img_object}='y';
			push(@query_string,$query);
		}
		#Alternate Image url
		if ( $content2 =~ m/<img[^<]*?id\=\s*\Wmain_image\W[^<]*?src\=\"([^<]*?)\"/is )
		{
			my $altimagecontent = $1;
			unless($altimagecontent=~m/^\s*http/is)
			{
				$altimagecontent='http://www.coast-stores.com'.$altimagecontent;
			}
			my $altimagecontent1=$altimagecontent;
			my $altimagecontent2=$altimagecontent;
			my $altimagecontent3=$altimagecontent;
			my $altimagecontents=$altimagecontent;
			$altimagecontent1=~s/(\.[\w]{3,4})$/_1$1/igs;
			$altimagecontent2=~s/(\.[\w]{3,4})$/_2$1/igs;
			$altimagecontent3=~s/(\.[\w]{3,4})$/_3$1/igs;
			my $staus=get_content_status($altimagecontent1);
			if($staus == 200)
			{
				my ($imgid,$img_file) = &DBIL::ImageDownload($altimagecontent1,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$altimagecontent1,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$color;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
			my $staus=get_content_status($altimagecontent2);
			if($staus == 200)
			{
				my ($imgid,$img_file) = &DBIL::ImageDownload($altimagecontent2,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$altimagecontent2,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
				$imageflag = 1 if($flag);
				$image_objectkey{$img_object}=$color;
				$hash_default_image{$img_object}='n';
				push(@query_string,$query);
			}
			my $staus=get_content_status($altimagecontent3);
			if($staus == 200)
			{		
				my ($imgid,$img_file) = &DBIL::ImageDownload($altimagecontent3,'product',$retailer_name);
				my ($img_object,$flag,$query) = &DBIL::SaveImage($imgid,$altimagecontent3,$img_file,'product',$dbh,$Retailer_Random_String,$robotname,$excuetionid);
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
        
		my ($query1,$query2)=&DBIL::UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$dbh,$robotname,$excuetionid,$skuflag,$imageflag,$url3,$retailer_id);
		push(@query_string,$query1);
		push(@query_string,$query2);
		&DBIL::ExecuteQueryString(\@query_string,$robotname,$dbh);
		$dbh->commit();
	}
}1;
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
