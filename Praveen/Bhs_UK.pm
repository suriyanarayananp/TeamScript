#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
package Bhs_UK;
use strict;

sub Bhs_UK_DetailProcess() 
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
	my $Retailer_Random_String='Bhs';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);
	
	# Setting the environment.
	$utilityobject->SetEnv($ProxyConfig);
	
	# Return to calling script if product object key is not available.
	return if($product_object_key eq ''); 
	
	# Appending home url if url doesn't start with "http".
	$url='http://www.bhs.co.uk/'.$url unless($url=~m/^\s*http\:/is);
	
	# Get the content from the url.
	my $content2 = $utilityobject->Lwp_Get($url);
	
	# Flag to check whether Sku details are available.
	my $skuDetailFlag=0;		
			
	# Declaring required variables.	
	my ($price,$price_text,$brand,$product_id,$product_name,$description,$prod_detail,$out_of_stock,$color,$Item_code,$wasprice_text,$off_price,$size,@string);
	
	# Pattern matches to check whether product page doesn't have product details (Error page).
	if(($content2 =~ m/<h1>\s*We\s*couldn\s*(?:\'|o)\s*t\s*find\s*the\s*page\s*you\s*[^<]*?</is)||($content2 =~ m/<h1>\s*Error\s*Page\s*Exception[^<]*?</is)||($content2 =~ m/<h1>\s*An\s*error\s*has\s*occurred[^<]*?</is)||($content2 =~ m/no\s*longer\s*available\s*for\s*purchase[^<]*?</is))
	{
	  goto PNF;
	}
		
	# Pattern match to store mflag as 1 for multiple products.
	if($content2 =~ m/<div\s*class=\"bundle_display_product([^<]*?)\">/is)
	{
		$mflag=1;
		goto PNF;
	}
		
	# Pattern match to get item code.
	if($content2 =~ m/>\s*Item\s*code\s*\:[^>]*?(?:\s*<[^>]*?>\s*)+\s*([^<]*?)</is)
	{
		$Item_code=$1;
	}
		
	# Pattern match to get product id.	
	if($content2 =~ m/STYLE_CODE\s*\:\s*(?:\"|\')\s*([^\"\']*?)\s*(?:\"|\')/is)   # Taking STYLE_CODE as product id.
	{
		$product_id=$1;
		# my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key, $robotname, $retailer_id);
		# goto ENDOFF if($ckproduct_id == 1);
		# undef ($ckproduct_id);
	}
	elsif($Item_code) # If item code not available get the product id from the item code.
	{
		$product_id = substr($Item_code,0,5);                                     
		# my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key, $robotname, $retailer_id);
		# goto ENDOFF if($ckproduct_id == 1);
		# undef ($ckproduct_id);
	}
		
	# Pattern match to get price text and color.
	if ( $content2 =~ m/<li\s*class\=\"product_colour\"\s*>\s*Colour\s*\:\s*[^>]*?<span>\s*([^<]*?)\s*</is )
	{
		$color = $utilityobject->Trim($1);
	}
	
	# Pattern match to get product name.
	if ( $content2 =~ m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is )
	{
		$product_name = &clear($utilityobject->Trim($1));
	}	
	
	# Pattern match to get brand.
	if ( $content2 =~ m/productAttributes\s*\:[^>]*?SHOP_BY_BRAND[^>]*?\:\"([\w\W]*?)\"\s*[^>]*?}/is )
	{
		$brand = $utilityobject->Trim($1);
		$brand =~ s/\\\'/\'/igs;
		if ( $brand !~ /^\s*$/g )
		{
			$dbobject->SaveTag('Brand',lc($brand),$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	
	# Pattern match to get product description & product detail block.
	if($content2 =~ m/<[^>]*?class\=\"product_description\"(>[\w\W]*?)<div[^>]*?class\s*\=\s*\"\s*cms_content\s*"/is)
	{
		$description=$&;
		
		# Pattern match to get product description & product detail(Pattern 1).
		if($description=~m/>([\w\W]*)<\/p>(?:(?:\s*<[^>]*?>\s*)+\s*)?<[^>]*class\s*=\s*\"\s*product_description\s*\"[^>]*?>([\w\W]*)<div/is)
		{
			$description =$1;
			$prod_detail =$2;
		}
		elsif($description=~m/>([\w\W]*?)<ul[^>]*?>\s*([\w\W]*)<div/is)# Pattern match to get product description & product detail(Pattern 2).
		{
			$description =$1;
			$prod_detail =$2;
		}
		elsif($description=~m/>([^<]*)(?:(?:\s*<[^>]*?>\s*)+\s*)?<\/p>\s*<p[^>]*?>\s*<span[^>]*?>\s*([\w\W]*)<div/is)# Pattern match to get product description & product detail(Pattern 3).
		{
			$description =$1;
			$prod_detail =$2;
		}
		elsif($description=~m/>([\w\W]*)<span[^>]*?>\s*([\w\W]*)<div/is)# Pattern match to get product description & product detail(Pattern 4).
		{
			$description =$1;
			$prod_detail =$2;
		}
		elsif($description=~m/>([\w\W]*)<\/p>\s*<p[^>]*?>\s*(\w[\w\W]*<(?:br\s*\/|li|span|p)>[\w\W]*)<div/is)# Pattern match to get product description & product detail(Pattern 5).
		{
			$description =$1;
			$prod_detail =$2;
		}
		elsif($description=~m/>([\w\W]*?)<br\s*\/?\s*>\s*([\w\W]*)<div/is)# Pattern match to get product description & product detail(Pattern 6).
		{
			$description =$1;
			$prod_detail =$2;
		}
		
		$prod_detail=~s/^\s*<li[^>]*?>//igs;
		$prod_detail=~s/<li[^>]*?>/-/igs;
		$prod_detail=~s/<br\s*\/?>/-/igs if($prod_detail!~m/-/is);		
		$prod_detail=~s/<span[^>]*?>/-/igs if($prod_detail!~m/-/is);		
		$description=~s/^\s*<li[^>]*?>//igs;
		$description=~s/<li[^>]*?>/-/igs;
		
		$prod_detail = $utilityobject->Trim($prod_detail);
		$description = $utilityobject->Trim($description);
		
		if(($description eq "")&&($prod_detail ne ""))
		{
			$description=$prod_detail;
		}
		
		$description=~s/<div[^>]*?$//igs;
		$description=&clear($description);
		$prod_detail=&clear($prod_detail);
	}

	# Pattern match to get price text and price.
	
	if($content2 =~ m/prices\s*\:\s*\{\s*now\s*\:\s*(?:\"|\')([^\"\']*?([\d\.\"\']*))(?:\"|\')\s*(?:\,\s*(was\s*\:\s*(?:\"|\')[^\"\']*?)(?:\"|\'))?\s*}/is)
	{
		$price_text=$1;
		$price=$2;
		$wasprice_text=$3;
		#$wasprice_text = $utilityobject->PriceFormat($wasprice_text, $ccode);
		$wasprice_text =~ s/\"|\://igs;
		$wasprice_text = $utilityobject->Trim($wasprice_text);
		$wasprice_text = $utilityobject->Decode($wasprice_text);
		$price_text = $utilityobject->Trim($price_text);
		$price_text = $utilityobject->Decode($price_text);
		$price_text=~s/\£/\Â\£/igs;	
		$wasprice_text =~ s/\£/\Â\£/igs;
		
		$price_text=$price_text."   $wasprice_text" if($wasprice_text ne '');
	}
	
	# Pattern match to get "Offer Price".
	
	if($content2 =~ m/product\s*Discount[^<]*?(?:\s*<[^>]*?>\s*)+\s*\s*([^<]*?\s*off)\s*</is)
	{
		$off_price=$1;
		 
		# Pattern match to form price text with "offer price" and "was price".
		if($wasprice_text ne '')
		{
		  $price_text=$price_text."   $wasprice_text"."  $off_price";
		}
		else # To form price text with "offer price" if "was price" not available.
		{
		  $price_text=$price_text." $off_price";	
		}
	}
	$price='null' if($price eq '' or $price eq ' ');
    #$price_text = $utilityobject->PriceFormat($price_text, $ccode);	
    #$price_text=~s/\Â//igs; 
	
	# Pattern match to take block for getting price according to size,Out of stock(Scenario 1).
	if($content2  =~ m/var\s*productData([\w\W]*?)<\/script>/is) 
	{
		my $blk=$1;
		my %size_hash;
		
		# Pattern match to check whether size block available.
		if($blk=~m/size\s*\:[^\}]*?\}/is)
		{
			# Looping through to get each size block. 
			while($blk=~m/{\s*size\s*\:[^\}]*?\}/igs)
			{
				my $blk1=$&;
				my %size_hash;
				
				# Pattern match to get size from the size block.
				if($blk1=~m/size\s*\:\s*\"([^>]*?)\"/igs)
				{
					$size=$1;
					$size_hash{$blk1}=$size;
				}
				
				if($size_hash{$size} eq '')  # Checking with hash to remove duplicates.
				{
					
					# Pattern match to get the price and forming price text from size block(Price varies depending on the size).
					if($blk1=~m/now\s*price\s*\:\s*([^\}]*?)\s*(?:\,|\})/is)
					{
						$price=$1;
						$price_text='Â£'.$price;
						$price_text=$price_text."   $wasprice_text" if(($wasprice_text ne '')&&($off_price eq ''));
						$price_text=$price_text."   $off_price" if(($wasprice_text eq '')&&($off_price ne ''));
						$price_text=$price_text."   $wasprice_text"."   $off_price" if(($wasprice_text ne '')&&($off_price ne ''));
						#$price_text = $utilityobject->PriceFormat($price_text, $ccode);	
					}
					
					# Pattern match to take block to get size and out of stock values.
					if ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is )
					{
						my $size_content = $1;
						
						# Pattern match to get instock products first to remove duplication in size.
						while($size_content=~m/<option\s*value\=(?:\"|\')[^\"\']*?(?:\"|\')\s*title\=(?:\"|\')[^\"\']*?(?:\"|\')(?:\s*class\=\"[^\"]*?\")?>\s*$size\s*<\/option>/igs)
						{
							my $out_of_stock 	= 'n';
							
							$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
							$skuDetailFlag=1;
							$size_hash{$size}=1;   # Creating hash to remove Duplicates.
						}
						# Pattern match to get out of stock value products (Given priority to instock products if duplication in size).
						while($size_content=~m/<option\s*disabled\s*\=\s*\"\s*disabled\s*\"\s*title\s*\=\s*(?:\"|\')[^\"\']*?(?:\"|\')\s*[^>]*?>\s*$size\s*<\/option>/igs)
						{
							my $out_of_stock 	= 'y';
							
							if($size_hash{$size} eq '')  # Checking with hash to remove duplicates.
							{
								$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
								$skuDetailFlag=1;
								$size_hash{$size}=1;
							}
						}
					}
				}
			}
		}
		elsif($content2 =~ m/item_out_of_stock\s*(?:\"|\')\s*>[^>]*?this\s*item\s*is\s*out\s*of\s*stock/is) # Pattern match to check if product is in out of stock, if size block not available (Scenario 2).
		{
			$out_of_stock='y';
			$skuDetailFlag=1;
			
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,' ',$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
		}
	}
	elsif ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is ) # Pattern match to get size's block if java script not available((Scenario 3).
	{
		my $size_content = $1;
		
		# Pattern match to get each size and out of stock values.
		while ( $size_content =~ m/<option[^>]*?title\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/option>/igs )
		{
			my $size 			= $utilityobject->Trim($2);
			my $stockstaus   	= $utilityobject->Trim($1);
			my $out_of_stock = 'n';
			$out_of_stock = 'y' if($stockstaus =~ m/\s*Out\s*of\s*stock\s*/is);
			
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
			$skuDetailFlag=1;
		}
	}
	elsif($content2 =~ m/item_out_of_stock\s*(?:\"|\')\s*>[^>]*?this\s*item\s*is\s*out\s*of\s*stock/is) # If product is out of stock and size block(java script) both are not  available((Scenario 4).
	{
		$out_of_stock='y';
		$skuDetailFlag=1;
		
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,"",$color,$out_of_stock,$Retailer_Random_String,$robotname,'');
	}
	elsif($color||$price) # If out of stock and size block not available but colour,price text and price available(Scenario 5).
	{
		$out_of_stock='n';
		$skuDetailFlag=1;
		
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,"",$color,$out_of_stock,$Retailer_Random_String,$robotname,'');
	}
		
	# Pattern match to get main image url.
	if ( $content2 =~ m/<meta\s*property\=\"og\:image\"\s*content\=\"([^>]*?)\"\/\s*>/is )
	{
		my $imageurl_det = $utilityobject->Trim($1);
		my $imageurl_up = (split('_',$imageurl_det))[0]; # Taking url before "_" to take needed part from main image url to make image size huge and to form alternate image url.
		my $imageurl = $imageurl_up."_large.jpg"; # Forming image url from the url taken.
		
		my $image_Domain_url="http://media.bhs.co.uk"; # Image home url.
		
		# Appending image home url if url taken doesn't start with "http".
		$imageurl=$image_Domain_url.$imageurl unless($imageurl=~m/^\s*http\:/is);
		my $staus=$utilityobject->GetCode($imageurl);
		
		if($staus!~m/20/is) 
		{
			$imageurl = $imageurl_det; # Assigning the image url that was taken before if Image url ending with "_large" having page error (leads to downloading Issue in Parent Directory)
			$imageurl=$image_Domain_url.$imageurl unless($imageurl=~m/^\s*http\:/is); # Appending image home url if image url doesn't start with "http".
		}
		
		# Downloading and save entry for product image.
		my $img_file = $imagesobject->download($imageurl,'product',$retailer_name,$ua);
		
		# Save entry to image table ,if image download is successful. Otherwise throw error in log.
		$dbobject->SaveImage($imageurl,$img_file,'product',$Retailer_Random_String,$robotname,$color,'y') if(defined $img_file);
					
		if($content2 =~ /thumbnails:\s*\[([^>]*?)\s*\]/is)
		{
		 @string = split(/,/,$1);
		}
		foreach my $count ( 2 .. $#string+1)
		{
			# Formation of alternate image urls with respect to count value.
			my $imageurl1 = $imageurl_up."\_$count\_large.jpg";
			$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is);
			my $staus=$utilityobject->GetCode($imageurl1);
			
			if($staus!~m/20/is) 
			{
				$imageurl1 = $imageurl_up."\_$count\_normal.jpg"; # Formation of Image url if Image url ending with "_large" having page error in alternate images (leads to downloading Issue in Parent Directory).
				$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is); # Appending image home url if image url doesn't start with "http".
			}
			
			# Downloading and save entry for product image.
			my $img_file = $imagesobject->download($imageurl1,'product',$retailer_name,$ua);
			
			# Save entry to image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($imageurl1,$img_file,'product',$Retailer_Random_String,$robotname,$color,'n') if(defined $img_file);
		}
	}
	
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
	
	# Checking whether $product_name,$product_id are not null and have sku detail(Checking whether Instock Product-should be marked as Product).
	if(($product_name eq '')&&($product_id ne '')&&($skuDetailFlag))
	{
		$product_name='-';
	}
	# Checking whether description,prod_detail are null but product id not null and have sku detail(Checking whether Instock Product-should be marked as 'y' ).
	if((($description eq '') or ($description eq ' '))&&(($prod_detail eq '') or ($prod_detail eq ' '))&&($product_id ne '')&&($skuDetailFlag))
	{
		$description='-';
	}
		
PNF:
	
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url,$retailer_id,$mflag);
	
	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	
ENDOFF:
	
	# Committing transaction and undefine the query array.
	$dbobject->commit();
	$dbobject->Destroy();		
	
	$price=$price_text=$brand=$product_id=$product_name=$description=$prod_detail=$out_of_stock=$color=$Item_code=$wasprice_text=$off_price=$size=@string=undef;
}1;

# Function to remove encoding characters and decoding entities.
sub clear()
{
	my $text=shift;
	$text=~s/Â//igs;
	$text=~s/Â®/®/igs;
	$text=~s/â//igs;
	$text=~s/€¢/•/igs;
	return $text;
}

