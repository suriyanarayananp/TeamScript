#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Walmart_US;
use strict;
###########################################

sub Walmart_US_DetailProcess()
{
	my $product_object_key = shift;
	my $url = shift;
	my $robotname = shift;
	my $retailer_id = shift;
	my $logger = shift;
	my $ProxyConfig = shift;
	my $ua = shift;
	my $dbobject = shift;
	my $imagesobject = shift;
	my $utilityobject = shift;
	my $Retailer_Random_String='Wal';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;

	# Setting the Environment
	$utilityobject->SetEnv($ProxyConfig);

	# Returning the function, if product_object_key is nothing
	return if($product_object_key eq '');	
		
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;		
	$url='http://www.walmart.com'.$url unless($url=~m/^\s*http\:/is);	
	my $content2 = $utilityobject->Lwp_Get($url);
	
	# Global variable declaration.
	my ($price,$price_text,$brand,$sub_category,$item_no,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour);
	
	# ItemNo / Product ID collection
	if($url=~m/^[^>]*?\/([\d]+)[^>]*?$/is)
	{
		$item_no=$1;
		# Checking Duplication using item number
		my $ckproduct_id = $dbobject->UpdateProducthasTag($item_no, $product_object_key, $robotname, $retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}	
	
	#Collecting the price
	if($content2 =~ m/class\=js-product-offer-summary>([\w\W]*?)<\/div>\s*(?:<div\s*class\=price\-fulfillment>|<\/div>)/is)
	{
		$price_text = $utilityobject->Trim($1);
	}
	elsif($content2=~m/<div\s*class\=\"js\-price\-display\s*price\s*price\-display\">([\w\W]*?)<\/div>/is) 
	{
		$price_text = $utilityobject->Trim($1);
	}
	elsif($content2 =~ m/<span\s*class\=\"bigPriceText1\">([^<]*?)<\/span>\s*<span\s*class\=\"smallPriceText1\">([^<]*?)</is)
	{
		$price_text = $utilityobject->Trim($1.$2);
	}
	# elsif($content2=~m/<span\s*class\=old\-price>([\W\w]*?)<\/div>/is) 
	# {
		# $price_text=$price_text.' '.$1;
	# }	
	if($price_text eq '')
	{
		if($content2 =~ m/itemprop\=price[^>]*?content\=\"([^>]*?)\"/is)
		{
			$price_text = $utilityobject->Trim($1);
		}
	}
	if($content2 =~ m/itemprop\=price[^>]*?content\=\"([^>]*?)\"/is)
	{
		$price = $utilityobject->Trim($1);
	}
	if($price_text =~ m/item\s*not\s*available|Add\s*to\s*cart\s*for\s*price/is)
	{
		$price_text = '';
		$price_text = $utilityobject->Trim($1) if($content2 =~ m/itemprop\=price[^>]*?content\=\"([^>]*?)\"/is);
		$price_text = '' if($price_text eq '');
	}
	$price_text =~ s/out\s*of\s*stock|in\s*stock|low\s*stock/ /igs;
	$price_text =~ s/\s+//igs;
	$price_text =~ s/was\:/ was\: /igs;
	if($price eq '')
	{
		$price = $price_text;
	}
	$price =~ s/\$//igs;
	$price =~ s/\,//igs;
	if($price =~ m/^\s*$/is)
	{		
		$price = 'NULL';
	}
		
	##Brand Tag from Product Name##
	if ( $content2 =~ m/itemprop\=brand[^>]*?content\=\s*(?:\")?([^>]*?)\s*(?:\")?\s*\//is )
	{
		$brand = $utilityobject->Trim($1);
		$brand = $utilityobject->Decode($brand);
		if ( $brand !~ /^\s*$/g ) 
		{ 
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		} 
	}	
	
	# Product_name
	if($content2 =~ m/<h1[^>]*?>\s*([^>]*?)\s*<\/h1>/is )
	{
		$product_name = $utilityobject->Trim($1);		
	}
	elsif ( $content2 =~ m/productName\"\:\"([\w\W]*?)\"\,\"/is )
	{
		$product_name = $utilityobject->Trim($1);		
	}
	elsif($content2 =~ m/name\=\"title\"\s*content\=\"([^>]*?)\"\/>/is)
	{
		$product_name = $utilityobject->Trim($1);
	}
	$product_name = $utilityobject->Decode($product_name);		
	# Description
	if ( $content2 =~ m/About\s*this\s*item<\/h2>[\w\W]*?<p>([\w\W]*?)<\/div>/is )
	{
		$description = $utilityobject->Trim($1);
	}
	elsif($content2 =~ m/itemprop\=\"description\">\s*<div>([\w\W]*?)<\/div>\s*<\/div>/is)
	{
		$description = $utilityobject->Trim($1);
	}
	elsif($content2 =~ m/class\=\"product\-about\s*js\-about\-bundle\">([\w\W]*?)<\/div>/is)
	{
		$description = $utilityobject->Trim($1);
	}
	$description= $utilityobject->Decode($description);
	
	# Detail
	if($content2 =~ m/product\-specs\">\s*<div\s*class\=specs\-table>([\w\W]*?)<\/div>/is)
	{
		$prod_detail = $utilityobject->Trim($1);
	}
	$prod_detail = $utilityobject->Decode($prod_detail);
	
	# Description and detail are empty.
	if(($product_name ne '' or $item_no ne '' ) && ($description eq '' and $prod_detail eq ''))
	{
		$description='-';		
	}
	
	#### Multi-Product Check
	if(($content2 =~ m/<button\s*class\=\"choose\-button\s*btn\s*btn\-primary\s*js\-start\-choosing\">Start\s*choosing\s*now<\/button>/is)||($content2 =~ m/<\/strong>\s*on\s*this\s*bundle\s*<\/div>/is))
	{
		$mflag=1;
		goto PNF;
	}
	
	###Out of Stock
	if($content2=~m/<p\s*class\=price\-oos>([^>]*?)<\/p>|<meta\s*itemprop\=availability[^>]*?content\=([^>]*?)\s*\/>/is)
	{
		$out_of_stock=$1.$2;
	}
	$out_of_stock =~ s/^\s*InStock\s*$/n/igs;
	$out_of_stock =~ s/^\s*Out\s*of\s*Stock\s*Online\s*$/y/igs;
	$out_of_stock =~ s/\s*Out\s*of\s*Stock\s*/y/igs;
	$out_of_stock =~ s/^\s*$/y/igs;
	
	# Colour
	my $colour_code;
	my %colours;
	if($content2=~m/\{\"variantTypes\"\:\[\{\"id\"\:\"actual_color([\w\W]*?)(?:\"id\"\:\"size\"|\"variantProducts)/is)
	{
		my $image_Block=$1;
		while($image_Block=~m/\{\"id\"\:\"actual_color\-([^>]*?)\"\,\"name\"\:\"\s*([^>]*?)\s*\"\,/igs)
		{
			$colour_code=$1;
			$colour=$2;			
			$colours{$colour_code}=$colour;
		}	
	}
	else
	{
		$colour='No raw colour';
	}
	
	# Sku collection.
	my $size;
	if($content2=~m/\"variants\"\:\{\"actual_color\"\:\{\"id\"\:\"actual_color\-[^>^\s]*?\"\,[\w\W]*?\"fetched\"/is)
	{
		while($content2=~m/\"variants\"\:\{\"actual_color\"(\:\{\"id\"\:\"actual_color\-[^>^\s]*?\"\,[\w\W]*?\")fetched\"/igs)
		{
			my $colour_code_block=$1;
			if($colour_code_block=~m/\{\"id\"\:\"actual_color\-([^>^\s]*?)\"\,\"type\"\:\"actual_color\"\,\"valueRank\"\:[\d]+\,\"available\"\:[^>]*?\}\,\"size\"\:\{\"id\"\:\"size\-([^>]*?)\"\,\"type\"\:\"size\"\,\"valueRank\"\:[\d]+\,[^>]*?\"storeOnlyItem\"\:[^>]*?\,\"available\"\:([^>]*?)\}/is)
			{
				$colour_code=$1;
				$size=$utilityobject->Trim($2);
				$size=$utilityobject->Decode($size);
				$out_of_stock=$3;
				
				$out_of_stock =~ s/false/y/igs;
				$out_of_stock =~ s/true/n/igs;
				$colour=$colours{$colour_code};		
				print "$colour -> $size\n";
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour_code);			
			}
			elsif($colour_code_block=~m/\{\"id\"\:\"actual_color\-([^>^\s]*?)\"\,\"type\"\:\"actual_color\"\,\"valueRank\"\:[\d]+\,\"available\"\:[^>]*?\}\,\"size\"\:\{\"id\"\:\"size\-([^>]*?)\"\,\"type\"\:\"size\"\,[^>]*?\"available\"\:([^>]*?)\,/is)
			{
				$colour_code=$1;
				$size=$utilityobject->Trim($2);
				$size=$utilityobject->Decode($size);
				$out_of_stock=$3;
				
				$out_of_stock =~ s/false/y/igs;
				$out_of_stock =~ s/true/n/igs;
				$colour=$colours{$colour_code};		
				print "$colour -> $size\n";
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour_code);			
			}
			elsif($colour_code_block=~m/\{\"id\"\:\"actual_color\-([^>^\s]*?)\"\,\"type\"\:\"actual_color\"\,[\w\W]*?priceMismatch\"\:[^>]*?available\"\:([^>]*?)\}/is)
			{
				$colour_code=$1;
				$out_of_stock=$2;
				
				$out_of_stock =~ s/false/y/igs;
				$out_of_stock =~ s/true/n/igs;
				$colour=$colours{$colour_code};		
				print "$colour -> No Size -> $colour_code\n";
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour_code);			
			}
		}
	}
	elsif($content2=~m/<option\s*disabled\s*selected>\s*Choose\s*Size\s*<\/option>([\W\w]*?)<\/select>/is)	
	{
		my $size_block=$1;	
		while($size_block=~m/>\s*([^>]*?)\s*<\/option>/igs)
		{
			$size=$utilityobject->Trim($1);
			$size=$utilityobject->Decode($size);
			$out_of_stock = 'n';
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour);			
		}
	}
	elsif($content2=~m/>Select\s*Size<\/option>([\w\W]*?)<\/div>/is)	
	{
		my $size_block=$1;	
		while($size_block=~m/>\s*([^>]*?)\s*<\/option>/igs)
		{
			$size=$utilityobject->Trim($1);
			$size=$utilityobject->Decode($size);
			$out_of_stock = 'n';
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour);
		}
	}
	else
	{
		$out_of_stock = 'n' if($out_of_stock eq '');
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'',$colour,$out_of_stock,$Retailer_Random_String,$robotname,$colour);			
	}

	# Image
	# if($content2=~m/\{\"variantTypes\"\:\[\{\"id\"\:\"actual_color([\w\W]*?)\"id\"\:\"size\"/is)
	if($content2=~m/\{\"variantTypes\"\:\[\{\"id\"\:\"actual_color([\w\W]*?)(?:\"id\"\:\"size\"|\"variantProducts)/is)
	{
		my $image_Block=$1;
		
		if($image_Block=~m/\{\"id\"\:\"actual_color\-([^>]*?)\"\,\"name\"\:\"\s*([^>]*?)\s*\"\,\"type\"\:\"actual_color\"\,[^>]*?\"imageUrl\"\:\"([^>]*?)\"([\w\W]*?)\}\}\]/is)
		{
			my $img_count=0;
			while($image_Block=~m/\{\"id\"\:\"actual_color\-([^>]*?)\"\,\"name\"\:\"\s*([^>]*?)\s*\"\,\"type\"\:\"actual_color\"\,[^>]*?\"imageUrl\"\:\"([^>]*?)\"([\w\W]*?)\}\}\]/igs)
			{
				my $colour_code=$1;
				my $colour=$2;
				my $swatch_image=$3;
				my $image_block=$4;
						
				while($image_block=~m/hero\"\:(?:\'|\")([^>]*?)(?:\'|\")/igs)
				{
					my $image_url = $1;
					next if($image_url =~ m/no\-image\.jpg/is);
					if($img_count==0)
					{
						$img_count++;
						my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
						$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'y') if(defined $img_file);
					}
					else
					{
						my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);		
						$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'n') if(defined $img_file);
					}			
				}	
			}
			if($img_count == 0)
			{
				my $colour_code = $1 if($content2 =~ m/\{\"id\"\:\"actual_color\-([^>]*?)\"\,\"name\"\:\"\s*([^>]*?)\s*\"\,/is);
				while($content2 =~ m/class\=\"product\-thumb\s*js\-product\-thumb[^>]*?\"\s*href\=\"([^>]*?)\"/igs)
				{
					my $image_url = $1;
					next if($image_url =~ m/no\-image\.jpg/is);
					if($img_count == 0)
					{
						$img_count++;
						my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
						$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'y') if(defined $img_file);
					}
					else
					{
						my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);		
						$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'n') if(defined $img_file);
					}			
				}	
				
			}
		}
		elsif($content2 =~ m/class\=\"product\-thumb\s*js\-product\-thumb[^>]*?\"\s*href\=\"([^>]*?)\"/is)
		{
			my $img_count = 0;
			my $colour_code = $1 if($content2 =~ m/data\-id\=actual_color\-([^>]*?)\s*selected>\s*([^>]*?)\s*<\/option>/is);
			while($content2 =~ m/class\=\"product\-thumb\s*js\-product\-thumb[^>]*?\"\s*href\=\"([^>]*?)\"/igs)
			{
				my $image_url = $1;
				next if($image_url =~ m/no\-image\.jpg/is);
				if($img_count == 0)
				{
					$img_count++;
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'y') if(defined $img_file);
				}
				else
				{
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);		
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour_code,'n') if(defined $img_file);
				}			
			}	
		}
	}
	elsif($content2=~m/id\=product\-media\-json\s*type\=\"application\/json\">\s*([\w\W]*?)<\/script>/is)
	{
		my $imgblock = $1;  # No Color & One Sku & Multiple Images.,
		my $img_count = 0;
		while($imgblock =~ m/hero\"\:(?:\'|\")([^>]*?)(?:\'|\")/igs)
		{
			my $image_url = $1;
			next if($image_url =~ m/no\-image\.jpg/is);
			if($img_count==0)
			{
				$img_count++;
				my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
				$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour,'y') if(defined $img_file);
			}
			else
			{
				my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);		
				$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$colour,'n') if(defined $img_file);
			}			
		}
	}
	elsif($content2=~m/\{\"versions\"\:\{\"hero\"\:\"([^>]*?)\"\,/is)
	{
		my $default_image=$1;
		goto SkipImag if($default_image =~ m/no\-image\.jpg/is);
		my $img_file = $imagesobject->download($default_image,'product',$retailer_name,$ua);
		$dbobject->SaveImage($default_image,$img_file,'product',$Retailer_Random_String,$robotname,$colour,'y') if(defined $img_file);					
		SkipImag:
			print "No Image\n";
	}
	elsif($content2 =~ m/itemprop\=\"image\"\s*src\=\"([^\"]*?)\"/is)
	{
		my $default_image=$1;
		goto SkipImag2 if($default_image =~ m/no\-image\.jpg/is);
		my $img_file = $imagesobject->download($default_image,'product',$retailer_name,$ua);
		$dbobject->SaveImage($default_image,$img_file,'product',$Retailer_Random_String,$robotname,$colour,'y') if(defined $img_file);
		SkipImag2:
			print "No Image\n";
	}
	
	# Sku has image mapping
	my $logstatus=$dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
	
	PNF:
	# updating the product table details
	$dbobject->UpdateProductDetail($product_object_key, $item_no, $product_name, $brand, $description, $prod_detail, $robotname, $url, $retailer_id, $mflag);		
	# Executing all the queries created
	$dbobject->ExecuteQueryString($product_object_key);
	
	ENDOFF:
	#Commiting DB object
	$dbobject->commit();
	#Destroy DB object
	$dbobject->Destroy();	
}1;