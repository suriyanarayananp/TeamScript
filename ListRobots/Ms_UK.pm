#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
package Ms_UK;
use strict;

sub Ms_UK_DetailProcess()
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
	my $Retailer_Random_String='m&s';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);
	$retailer_name = 'm&s-uk';
	
	# Setting the Environment.
	$utilityobject->SetEnv($ProxyConfig);
	
	# Return to calling script if product object key is not available.
	return if($product_object_key eq ''); 
	
	$url =~ s/^\s+|\s+$//g;
	
	# Get the Content from the urls'.
	my $content2 = $utilityobject->Lwp_Get($url);
	
	# Directly branch off to save only the product information.
	goto PNF if($content2=~m/Sorry\!\s*This\s*item\s*is\s*currently\s*not\s*available\.\s*Here\s*is\s*a\s*list\s*of\s*other\s*products\s*you\s*may\s*like\./is);
		
	# Declaring all required variables.
	my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$colour,$tprice,%ProductHash, $mainID, %sizeID);
	
	# Pattern match to get the Price Text for the product.
	if($content2 =~ m/<div\s*class\=\"pricing\">([\w\W]*?)<\/dl>/is)
	{
		$price_text = $1;
		
		# Encode the Pricetext using country code.
		$price_text = $utilityobject->PriceFormat($price_text, $ccode);
		$price_text =~ s/\Ã‚//igs;
		$price_text =~ s/Â//igs;
	}
	
	# Pattern match to get the Price for the product.
	if($content2 =~ m/data\-mapping\=\"price\"\s*data\-value\=\"([^>]*?)\">/is)
	{
		my $PriceCont = $1;
		$PriceCont =~ s/\-|\Ã‚|\Â£|\&pound\;//igs;
		$price = $utilityobject->Trim($PriceCont);
	}
	
	# Pattern match to get the Product Name for the product.
	if ( $content2 =~ m/<h1\s*itemprop\=\"name\"[^>]*?>\s*([\w\W]*?)\s*<\/h1>/is)
	{
		$product_name = $utilityobject->Trim($1);
		$product_name = $utilityobject->DecodeText($product_name);
		$product_name =~ s/\Ã‚//igs;
	}
	
	# Get the Retailer_Product_Reference and call the UpdateProducthasTag to check if the same product reference exists.
	if ( $content2 =~ m/\"code\">\s*([^>]*?)\s*<\/p>/is)
	{
		$product_id = $utilityobject->Trim($1);
		$product_id =~ s/\Ã‚//igs;
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	
	# Pattern match to get the Brand for the product.
	if($content2 =~ m/class\=\"sb\-logo\">\s*([^>]*?)\s*<\/li>/is )
	{
		$brand = $utilityobject->Trim($1);
		$brand=~s/COLLECTIONN/COLLECTION/igs;
		if($brand !~ /^\s*$/g)
		{
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	
	# Pattern match and get the Details and Description for the product.
	if($content2 =~ m/class\=\"product\-description\">\s*([^>]*?)\s*</is)
	{
		$description = $utilityobject->Trim($1);
		$description = $utilityobject->DecodeText($description);
	}
	if($content2 =~ m/data\-panel\-id\=\"productInformation\">([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
	{
		$prod_detail = $1;
		$prod_detail =~ s/<li>/* /igs;
		$prod_detail =~ s/<[^>]*?>//igs;
		$prod_detail = $utilityobject->DecodeText($prod_detail);
	}
	$description = $utilityobject->Trim($description);
	$description =~ s/\Ã‚//igs;
	$prod_detail = $utilityobject->Trim($prod_detail);
	$prod_detail =~ s/\Ã‚//igs;
	
	# Pattern match to check whether the product have muliptle prodcut, If yes mark it 'detail_collected='m'.
	if($content2 =~ m/class\=\"product\-code\"\s*type\=\"hidden\"\s*value\=(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/is)
	{
		# Pattern match to get the productId for the mulitple product.
		while($content2 =~ m/class\=\"product\-code\"\s*type\=\"hidden\"\s*value\=(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/igs)
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
		
		# Get the Retailer_Product_Reference and call the UpdateProducthasTag to check if the same product reference exists.
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key, $robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
		
		# Pattern match to get the pricetext for the multiple product.
		if($content2 =~ m/<div\s*class\=\"sets\-price\">([\w\W]*?)<\/dl>/is)
		{
			$price_text = $1;
			
			# Encode the Pricetext using country code.
			$price_text = $utilityobject->PriceFormat($price_text, $ccode);
			# $price_text = $utilityobject->Trim($price_text);
			$price_text =~ s/\Ã‚//igs;
			$price_text =~ s/Â//igs;
			$price = 'null';
		}
		
		# Pattern  match to get the detail and description for the multiple product.
		if($content2 =~ m/class\=\"product\-description\">\s*([\w\W]*?)\s*<\/p>/is)
		{
			$description = $utilityobject->Trim($1);
			$description =~ s/\Ã‚//igs;
			$prod_detail = '';
		}
		
		# Save the collected Sku.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'','','n',$Retailer_Random_String,$robotname,'No Color');
		
		# Pattern match to get the Default Image for the product.
		my $imageURL = 'http:'.$1 if($content2 =~ m/class\=\"current\"\s*src\=\"([^>]*?)\"/is);
		$imageURL = $utilityobject->Trim($imageURL);
		if($imageURL ne '')
		{
			# Downloading and save entry for product images
			my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
			
			# save entry to Image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,'No Color','y') if(defined $img_file);				
		}
		$mflag = 1;
		goto PNF;
	}
	else  
	{
		# Pattern match to check whether the product have multiple sizes.
		if($content2 =~ m/class\=\"size\-indicator\">\s*<\/div>([\w\W]*?)<\/td>/is)
		{
			# Pattern match to get the size block for the product.
			while($content2 =~ m/class\=\"size\-indicator\">\s*<\/div>([\w\W]*?)<\/td>/igs)  ##Multiple Sizes
			{
				my $sizeCont = $1;
				
				# Pattern match to get the size and sizeID from the Size block stored into hash.
				while($sizeCont =~ m/name\=\"size\"\s*value\=\"([^>]*?)\"[\w\W]*?<\/span>\s*([^>]*?)\s*<\/label>|<label\s*for\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/label>/igs)
				{
					# $sizeID{$1} = $utilityobject->Trim($2);  # Size stored into hash based on sizeID.
					my $key = $1.$3;
					my $val = $2.$4;
					$val =~ s/\&frac12\;/½/igs;
					$val =~ s/\&\#x3a\;/\:/igs;
					$sizeID{$key} = $val;
					undef($key); undef($val);
				}
			}
		}
		elsif($content2 =~ m/>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is) ##Multiple Sizes
		{
			# Pattern match to get the size block for the product.
			my $sizeCont = $1;
			
			# Pattern match to get the size and sizeID from the Size block stored into hash.
			while($sizeCont =~ m/data\-product\-option\-label\=\"([^>]*?)\"\s*value\=\"([^>]*?)\">/igs)
			{
				# $sizeID{$2} = $utilityobject->Trim($1);  # Size stored into hash based on sizeID.
				my $key = $2;
				my $val = $1;
				$val =~ s/\&frac12\;/½/igs;
				$val =~ s/\&\#x3a\;/\:/igs;
				$sizeID{$key} = $val;
				undef($key); undef($val);
			}
		}
		else
		{
			# Check whether the product have One Size only.
			while($content2 =~ m/class\=\"size[^>]*?skip\s*single\-size\-accordion[^>]*?>([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/igs)  ##OneSize
			{
				my $sizeCont = $1;
				
				# Pattern match to get the size and sizeID from the Size block stored into hash.
				while($sizeCont =~ m/name\=\"size\"\s*value\=\"([^>]*?)\"[\w\W]*?<\/span>(?:\s*<span[^>]*?>)?\s*([^>]*?)\s*</igs)
				{
					# $sizeID{$1} = $utilityobject->Trim($2);  # Size stored into hash based on sizeID.
					my $key = $1;
					my $val = $2;
					
					$val =~ s/\&frac12\;/½/igs;
					$val =~ s/\&\#x3a\;/\:/igs;
					$sizeID{$key} = $val;
					undef($key); undef($val);
				}
			}
		}

		my $skucount=0;

		# Pattern match to get the prdouctID for the product.
		$mainID = $1 if($content2 =~ m/class\=\"product\-code\s*mainProdId\"\s*type\=\"hidden\"\s*value\=\"([^>]*?)\"/is);
		
		# Pattern match to get the Swatch block for the product.
		if($content2 =~ m/class\=\"swatch\-container\">([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
		{
			my $swatchCont = $1;
			
			# Loop through for collecting the swatch URLs and color for the product.
			while($swatchCont =~ m/data\-swatch\-name\=\"([^>]*?)\"[^>]*?style\=\"background\-image\:url\(([^>]*?)\)|data\-swatch\-name\=\"([^>]*?)\"\s*data\-swatch\-src\=\"([^>]*?)\"/igs)
			{
				my $color = $utilityobject->Trim($1.$3);
				my $swatchURL = $utilityobject->Trim($2.$4);
				$swatchURL = "http:".$swatchURL unless($swatchURL =~ m/^http/is);
				$swatchURL = $utilityobject->Trim($swatchURL);
				
				# Downloading and save entry for product images
				my $img_file  = $imagesobject->download($swatchURL,'swatch',$retailer_name,$ua);
				
				# save entry to Image table ,if image download is successful. Otherwise throw error in log.
				$dbobject->SaveImage($swatchURL,$img_file,'swatch',$Retailer_Random_String,$robotname,$color,'n') if(defined $img_file);
				
				my $tcolor = $color;
				$tcolor =~ s/\s*//igs;		
				$tcolor = quotemeta($tcolor);				
				
				# Pattern match to get the out of stock block based on productID and ColorID.				
				if($content2 =~ m/\"$mainID\_$tcolor\"\:\{([\w\W]*?\})\}/is)
				{					
					my $StockCont = $1;
					
					# Get the sizes from Hash and push into an array.
					my @sizes = keys %sizeID;
					
					# If size array have more than 1 values then process it.
					if(@sizes > 1) ##Multiple Size
					{
						# Loop through all the collected sizes.
						foreach (keys %sizeID)
						{
							my $tempsize = $_;
							my $size = quotemeta($tempsize);
							
							# Pattern match to get the stock count based on the size.
							if($StockCont =~ m/\"$size\"\:\{\"count\"\:(\d+)\.\d+/is)
							{
								my $stcount = $1;
								$skucount++;
								my ($price,$oldprice,$offerprice, $pricetext, $unitprice);
								
								# Pattern match to get the current Price and Price text based on the colorID, SizeID and ProductID.
								if($content2 =~ m/\"$mainID\_$tcolor\_$size\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"([^>]*?)\"}/is)
								{
									$price = $1;	$oldprice = $2;	$offerprice = $3;	$unitprice = $4;
									$pricetext = $price.' '.$oldprice.' '.$offerprice.' '.$unitprice;
									
									# Encode the Pricetext using country code.
									$pricetext = $utilityobject->PriceFormat($pricetext, $ccode);
									# $pricetext = $utilityobject->Trim($pricetext);
									$pricetext =~ s/\Ã‚//igs;
									$pricetext =~ s/Â//igs;
									$price =~ s/\&pound\;//igs;
								}
								
								my $out_of_stock = 'n';
								
								# Check if the quantity is equal to '0' it should considered it as out of stock.
								$out_of_stock = 'y' if($stcount == 0);
								$price = 'null' if($price eq '');
								
								# Save the collected sku.
								$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,$sizeID{$tempsize},$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
							}
						}
					}
					elsif(@sizes == 1)# If size array contains only one value then proceed it.
					{
						# Loop through for all the collected sizes.
						foreach (keys %sizeID)
						{
							my $size = $_;
							my $tsize = $size;
							$tsize =~ s/\s+//igs;
							
							$tsize = quotemeta($tsize);
							
							# Pattern match to get the stock count based on the size.
							if($StockCont =~ m/\"$tsize\"\:\{\"count\"\:(\d+)\.\d+/is)
							{
								my $stcount = $1;
								$skucount++;
								my ($price,$oldprice,$offerprice, $pricetext, $unitprice);
								
								# Pattern match to get the current Price and Price text based on the colorID, SizeID and ProductID.
								if($content2 =~ m/\"$mainID\_$tcolor\_$tsize\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"([^>]*?)\"}/is)
								{
									$price = $1;	$oldprice = $2;	$offerprice = $3;	$unitprice = $4;
									$pricetext = $price.' '.$oldprice.' '.$offerprice.' '.$unitprice;
									
									# Encode the Pricetext using country code.
									$pricetext = $utilityobject->PriceFormat($pricetext, $ccode);
									# $pricetext = $utilityobject->Trim($pricetext);
									$pricetext =~ s/\Ã‚//igs;
									$pricetext =~ s/Â//igs;
									$price =~ s/\&pound\;//igs;
								}
								$size =~ s/DUMMY//igs;
								my $out_of_stock = 'n';
								
								# Check if the quantity is equal to '0' it should considered it as out of stock.
								$out_of_stock = 'y' if($stcount == 0);
								$price = 'null' if($price eq '');
								
								# Save the collected sku.
								$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
							}
						}
					}
					else # If there is No Size for the product.
					{
						
						# Pattern match to get the stock count.
						if($StockCont =~ m/\"DUMMY\"\:\{\"count\"\:(\d+)\.\d+/is)
						{
							my $stcount = $1;
							$skucount++;
							my ($price,$oldprice,$offerprice, $pricetext, $unitprice);
							
							# Pattern match to get the current Price and Price text based on the colorID and ProductID.
							if($content2 =~ m/\"$mainID\_$tcolor\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"([^>]*?)\"}/is)
							{
								$price = $1;	$oldprice = $2;	$offerprice = $3;	$unitprice = $4;
								$pricetext = $price.' '.$oldprice.' '.$offerprice.' '.$unitprice;								
								
								# Encode the Pricetext using country code.
								$pricetext = $utilityobject->PriceFormat($pricetext, $ccode);
								# $pricetext = $utilityobject->Trim($pricetext);
								$pricetext =~ s/\Ã‚//igs;
								$pricetext =~ s/Â//igs;
								$price =~ s/\&pound\;//igs;
							}
							my $out_of_stock = 'n';
							
							# Check if the quantity is equal to '0' it should considered it as out of stock.
							$out_of_stock = 'y' if($stcount == 0);
							$price = 'null' if($price eq '');
							
							# Save the collected sku.
							$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,'',$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
						}						
					}
				}
			}
			
			# Loop through for collecting all alternate images for the product.
			while($swatchCont =~ m/name\=\"colour\"\s*value\=\"([^>]*?)\"[^>]*?data\-image\-set\=\"([^>]*?)\"/igs)
			{
				my $Color;
				my $ImageUrl = $utilityobject->Trim($2);
				$Color = $utilityobject->Trim($1) if($swatchCont =~ m/data\-swatch\-name\=\"([^>]*?)\"/is);
				$ImageUrl = "http:".$ImageUrl unless($ImageUrl =~ m/^http/is);
				$ImageUrl = $utilityobject->Decode($ImageUrl);
				my $refetchCount = 0;
				
				ReFetchImage:
				# Get the Image Content for the Product based on Ajax ImageURL.
				my $ImageCont  = $utilityobject->Lwp_Get($ImageUrl);
				my $imgCount = 0;
				
				# Get the Image URL's from the Image Content.
				while($ImageCont =~ m/\;([^\;]*?)(?:\,|")/igs)
				{
					my $imageURL = "http://asset1.marksandspencer.com/is/image/".$1.'?$PDP_MAXI_ZOOM$';
					$ProductHash{$Color} = $utilityobject->Trim($imageURL);
					if($imgCount == 0)
					{
						$imgCount++;
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'y') if(defined $img_file);
					}
					else
					{
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'n') if(defined $img_file);
					}
				}
				if($imgCount == 0 && $refetchCount == 0)
				{
					if($content2 =~ m/src\=\"([^>]*?)\?[^>]*?\s*class\=\"btn\s*zoom\"/is)
					{
						my $imageURL = "http:".$1.'?$PDP_MAXI_ZOOM$';
						$ProductHash{$Color} = $utilityobject->Trim($imageURL);
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'y') if(defined $img_file);
					}
					elsif($content2 =~ m/data\-imgdimenstiontype\=\"portrait\"\s*data\-default\-imageset\=\"([^>]*?)\"/is)
					{
						$ImageUrl = $1;
						$ImageUrl = "http:".$ImageUrl unless($ImageUrl =~ m/^http/is);
						$ImageUrl = $utilityobject->Decode($ImageUrl);
						$refetchCount++;
						goto ReFetchImage;
					}
				}
			}
		}
		else ## No Swatch or No Color (NO Color & No Size)
		{
			# This block contains there is no swatch & color for the product.
			# Pattern match to get the out of stock block based on productID.
			
			# Get the sizes from Hash and push into an array.
			my @sizes = keys %sizeID;
			if(@sizes == 1)# If size array contains only one value then proceed it.
			{				
				# Loop through for all the collected sizes.
				foreach (keys %sizeID)
				{
					my $size = $_;
					my $tsize = $size;
					$tsize =~ s/\s+//igs;
					
					$tsize = quotemeta($tsize);
										
					# Pattern match to get the stock count based on the size.
					if($content2 =~ m/\"$tsize\"\:\{\"count\"\:(\d+)\.\d+/is)
					{
						my $stcount = $1;
						$skucount++;
						my ($price,$oldprice,$offerprice, $pricetext, $unitprice);
						
						# Pattern match to get the current Price and Price text based on the colorID, SizeID and ProductID.
						if($content2 =~ m/\"$mainID(?:\_NC)?\_$tsize\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"([^>]*?)\"}/is)
						{
							$price = $1;	$oldprice = $2;	$offerprice = $3;	$unitprice = $4;
							$pricetext = $price.' '.$oldprice.' '.$offerprice.' '.$unitprice;
							
							# Encode the Pricetext using country code.
							$pricetext = $utilityobject->PriceFormat($pricetext, $ccode);
							# $pricetext = $utilityobject->Trim($pricetext);
							$pricetext =~ s/\Ã‚//igs;
							$pricetext =~ s/Â//igs;
							$price =~ s/\&pound\;//igs;
						}
						$size =~ s/DUMMY//igs;
						my $out_of_stock = 'n';
						
						# Check if the quantity is equal to '0' it should considered it as out of stock.
						$out_of_stock = 'y' if($stcount == 0);
						$price = 'null' if($price eq '');
						
						# Save the collected sku.
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,$size,'',$out_of_stock,$Retailer_Random_String,$robotname,'No Color');
					}
				}
			}
			if($content2 =~ m/\"$mainID[^"]*?\"\:\{([\w\W]*?\})\}\;/is)
			{
				my $StockCont = $1;
				
				# Pattern match to get the stock count based on the DUMMY size.
				if($StockCont =~ m/\"DUMMY\"\:\{\"count\"\:(\d+)\.\d+/is)  ## No Size
				{
					my $stcount = $1;
					$skucount++;
					my ($price,$oldprice,$offerprice, $pricetext, $unitprice);
					
					# Pattern match to get the current Price and Price text based on the ProductID.
					if($content2 =~ m/\"$mainID\_[^>]*?\_DUMMY\"\:\{\"price\"\:\"([^>]*?)\"\,\"prevPrice\"\:\"([^>]*?)\"\,\"offerText\"\:\"([^>]*?)\"\,\"unitPrice\"\:\"([^>]*?)\"}/is)
					{
						$price = $1;	$oldprice = $2;	$offerprice = $3;	$unitprice = $4;
						$pricetext = $price.' '.$oldprice.' '.$offerprice.' '.$unitprice;
						
						# Encode the Pricetext using country code.
						$pricetext = $utilityobject->PriceFormat($pricetext, $ccode);
						# $pricetext = $utilityobject->Trim($pricetext);
						$pricetext =~ s/\Ã‚//igs;
						$pricetext =~ s/Â//igs;
						$price =~ s/\&pound\;//igs;
					}
					my $out_of_stock = 'n';
					
					# Check if the quantity is equal to '0' it should considered it as out of stock.
					$out_of_stock = 'y' if($stcount == 0);
					$price = 'null' if($price eq '');
					
					# Save the collected sku.
					$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,'','',$out_of_stock,$Retailer_Random_String,$robotname,'No Color');
				}
			}
			elsif($content2 =~ m/>\s*Sorry\,\s*but\s*this\s*item\s*is\s*no\s*longer\s*available\.\s*<\/span>/is) ##No Color->No Size ->Out of stock
			{
				# This block mentioned at out of stock product.
				my $out_of_stock = 'y';
				my $price = 'null';
				my $pricetext;
				
				# Save the collected sku.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$pricetext,'','',$out_of_stock,$Retailer_Random_String,$robotname,'No Color');
			}
			elsif($content2=~m/<div\s*id\=\"[^\"]*?\"\s*class\=\"out\-of\-stock\">/is)
			{
				# This block mentioned at out of stock product.
				my $out_of_stock = 'y';
				my $price = 'null';				
				
				# Save the collected sku.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'','',$out_of_stock,$Retailer_Random_String,$robotname,'No Color');
			}
			
			# Pattern match to get the Default Image URL's.
			if($content2 =~ m/data\-default\-imageset\=\"([^>]*?)\"/is)
			{
				my $ImageUrl = $utilityobject->Trim($1);
				my $Color = 'No Color';
				$ImageUrl = "http:".$ImageUrl unless($ImageUrl =~ m/^http/is);
				$ImageUrl = $utilityobject->Trim($ImageUrl);
				my $ImageCont  = $utilityobject->Lwp_Get($ImageUrl);
				my $imgCount = 0;
				
				# Pattern match to get all alternate Images.
				while($ImageCont =~ m/\;([^\;]*?)(?:\,|")/igs)
				{
					my $imageURL = "http://asset1.marksandspencer.com/is/image/".$1.'?$PDP_MAXI_ZOOM$';
					$ProductHash{$Color} = $utilityobject->Trim($imageURL);
					if($imgCount == 0)
					{
						$imgCount++;
						
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'y') if(defined $img_file);
					}
					else
					{
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'n') if(defined $img_file);
					}
				}
				if($imgCount == 0)
				{
					if($content2 =~ m/src\=\"([^>]*?)\?[^>]*?\s*class\=\"btn\s*zoom\"/is)
					{
						my $imageURL = "http:".$1.'?$PDP_MAXI_ZOOM$';
						$ProductHash{$Color} = $utilityobject->Trim($imageURL);
						
						# Downloading and save entry for product images
						my $img_file  = $imagesobject->download($imageURL,'product',$retailer_name,$ua);
						
						# save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($imageURL,$img_file,'product',$Retailer_Random_String,$robotname,$Color,'y') if(defined $img_file);
					}
				}
			}
		}
	}
	
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
	
	PNF:
	
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,lc($product_id),$product_name,$brand,$description,$prod_detail,$robotname,$url,$retailer_id,$mflag);
	
	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	
	ENDOFF:
	
	# Committing transaction and undefine the query array
	$dbobject->commit();
	$dbobject->Destroy();
}1;