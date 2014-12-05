#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
package Hm_DE;
use strict;

sub Hm_DE_DetailProcess()
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
	my $Retailer_Random_String='H&m';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	my $country=$retailer_name;
	$country=$1 if($country =~ m/[^>]*?\-([^>]*?)\s*$/is);
	$country=uc($country);
	$country="GE";
	
	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);
	print "Code:: $ccode\n";
	
	# Setting the Environment.
	$utilityobject->SetEnv($ProxyConfig);
	
	# Return to calling script if product object key is not available.
	return if($product_object_key eq ''); 
	
	# Get the Page Content.
	my $content2 = $utilityobject->Lwp_Get("$url");
	
	# Declaring all required variables.
	my ($price,$price_text,$brand,$product_id,$product_name,$description,$prod_detail,$out_of_stock,$color,$main_image_url,$alt_image_url,$swatch_image_url);
	
	# Pattern match to get Product id. 
	$product_id=$1 if($url=~m/\/\s*product\s*\/([^\?]*?)(?:\?article|$)/is);
	
	print "Product ID:: $product_id\n";
	
	# Call UpdateProducthasTag to update tag information of the new product if product id already exists. 
	my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key, $robotname,$retailer_id);
	goto ENDOFF if($ckproduct_id == 1);
	undef ($ckproduct_id);
	
	# Pattern match to get Product name.
	if($content2=~m/<h1[^>]*?>\s*([^<]*?)\s*</is)
	{
		$product_name = $1;		
	}
	$product_name=$utilityobject->Translate($product_name,$country);
	print "Product Name:: $product_name\n";
	
	# Pattern match to get Product  price text & price.
	if($content2=~m/class\s*\=\s*\"\s*price\s*\"[^>]*?>\s*(?:(?:\s*<[^>]*?>\s*)+\s*)?[^<]*?([\w\W]*?)<\/h1>/is)
	{
		my $price_text=$&;
		$price = $utilityobject->Trim($2);
		if($price_text=~m/new\s*\"\s*>[^<]*?([\d+\.]*?)\s*<\/span>/is)
		{	
		  $price=$1;
		}
		elsif($price_text=~m/text\-price\"\s*>\s*<\s*span\s*>[^<]*?([\d+\.]*?)\s*<\/span>/is)
		{
		  $price=$1;
		}
		
		$price_text = $utilityobject->PriceFormat($price_text, $ccode);			
	}
	### $price_text=$utilityobject->Translate($price_text,$country);
	print "Price Text: $price_text\n";
	# Pattern match to get Product Brand.
	if($content2=~m/productBrandLink\"\s*>\s*([^>]*?)\s*</is)
	{
		$brand = $utilityobject->Trim($1);
		if($brand!~m/^\s*$/g)
		{
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	## $brand=$utilityobject->Translate($brand,$country); 
	# Pattern match to get Product description.
	$description = $utilityobject->Trim($1) if($content2=~m/<h4[^>]*?>Beschreibung\s*<\/h4>\s*([\w\W]*?)\s*<\/p>/is);
	$description=$utilityobject->Translate($description,$country);
	# Pattern match to get Product details.
	$prod_detail = $utilityobject->Trim($1) if($content2=~m/<h4[^>]*?>\s*Details\s*<\/h4>\s*([\w\W]*?)\s*<\/p>/is);
	$prod_detail=$utilityobject->Translate($prod_detail,$country);
	print "Product Desc:: $description\n";
	print "Product Detail:: $prod_detail\n";

	if(($description=~m/^\s*$/is)&&($prod_detail=~m/^\s*$/is))
	{
		print "Product Detail and Desc are empty\n";
		$prod_detail = $utilityobject->Trim($1) if($content2=~m/<h4[^>]*?>\s*Details\s*<\/h4>\s*[\w\W]*?\s*<\/p>\s*<p>\s*([\w\W]*?)\s*<\/span>\s*<\/p>/is);
		$prod_detail=$utilityobject->Translate($prod_detail,$country);	
		$prod_detail='-' if($prod_detail=~m/^\s*$/is);	
	}
	
	# Declaring all required variables to take Sku details.
	my ($tcolor,$clr,@totalColor,$article,$article_url,%AllColor);	
	# Pattern match to take main block to get sku details.
	if($content2=~m/articles\s*\"\s*\:\s*\{([\w\W]*?)<\/script>/is) 
	{
		my $b=$1;
		print "Inside the articles block\n";
		# Loop through each block to get the sku detail for each article.
		while($b=~m/(?:\"([^\"\']*?)\"\s*\:\s*\{\s*)?(?:\"|\')\s*description\s*(?:\"|\')\s*\:\s*(?:\"|\')?([^\"\'\,]*?)\s*(?:\"|\')?\s*\,\s*(?:\"|\')\s*variants\s*(?:\"|\')[\w\W]*?\s*(?:\"|\')\s*size\s*Sorted\s*Variants\s*(?:\"|\')/igs)
		{
			$article=$1;
			$color=$2;         #Getting colour 
			my $blk_siz2=$&;   
			$color='' if($color=~m/\bnull\b/is); 
			$article_url=$url."?article=".$article; #Forming url for Sku which is changing according to colour.	
			print "Colour......:: $color\n";
			print "Inside the articles inner block\n";
			my $color1=lc($color);
			# Color Duplication Incremented.
			if($AllColor{$color1}>0)
			{
				$AllColor{$color}++; # To increment colour value. 
				my $tcolor = $color.'('.$AllColor{$color}.')'; 
				push @totalColor,$tcolor; 
				$clr=$tcolor;			
			}
			else
			{
				 push @totalColor,$color;
				 $AllColor{$color1}++; # To increment colour value.  
				 $clr=$color;				 
			}
			
			print "COLOUR AFTER THE INCREMENT:: $clr\n";
			my $tcolor2;
			# To Change color case.
			$clr = lc($clr);
			
			while($clr =~ m/([^>]*?)(?:\s+|$)/igs) # Splitting colour to get colour value to make case sensitive.
			{
				my $colour_id=$1;
				 if($tcolor2 eq '')
				 {
				  $tcolor2 = ucfirst($colour_id);
				 }
				 else
				 {
				  $tcolor2 = $tcolor2.' '.ucfirst($colour_id);
				 }
			}
						
			# Pattern match to get size and it's corresponding block.
			while($blk_siz2=~m/\{[^\{]*?\"\s*size\s*\"\s*\:\{\s*\"\s*name\s*"\s*:\s*\"\s*([^\"]*?)\"([^\}]*?\}[^\{]*?\{[^\}]*?\}[^\}]*?\})/igs)
			{
				my $size=$utilityobject->Trim($1);
				## $size=$utilityobject->Translate($size,$country);	 Removed to save trans
				my $blk_siz=$&;
				print "Size GOT:: $size\n";
				# Pattern match to get the out of stock.
				if($blk_siz=~m/\"\s*sold\s*Out\s*"\s*\:\s*\"?([^\}]*?)\s*(?:\,|\}|\")/is)
				{
					$out_of_stock=$1;
					$out_of_stock = "y" if($out_of_stock=~m/true/is);
					$out_of_stock = "n" if($out_of_stock=~m/false/is);
				}
				# Pattern match to get price text.
				if($blk_siz=~m/\"price\"\:\"([^>]*?)\"/is)
				{
					$price_text = $1;					
				}
				
				# Pattern match to get price text along with old price.
				if($blk_siz=~m/\"oldPrice\"\:(?:\")?([^\"]*?)(?:\")?\,\s*"/is)
				{
					$price_text = $price_text.' '.$1;
				}
				elsif($blk_siz=~m/\"oldPrice\"\:\s*\"\s*([^>]*?)\s*\"\s*\,/is)
				{
					$price_text = $price_text.' '.$1;
				}
				# Pattern match to get price.
				if($blk_siz=~m/\"priceWithoutCurrency\"\:\"([^>]*?)\"/is)
				{
					$price = $1;
				}
				$price_text = $utilityobject->PriceFormat($price_text, $ccode);  
				$price_text =~ s/null//igs;
				#$price_text ='€'.$price_text;
				$price='null' if($price eq '' or $price eq ' ');
				## $price_text=$utilityobject->Translate($price_text,$country);			# Removed to save trans		
				$tcolor2=$utilityobject->Translate($tcolor2,$country);	
				print "COLOUR GOT:: $color\n";
				if($color)
				{
					print "Inside the color SKU:: $color \t $size\n";
					# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
					$dbobject->SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$color);
				}
				else
				{
					print "Inside the ELse loop\n";
					# save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
					$dbobject->SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,'');
				}
				$price_text='';
			}
			
			if(($blk_siz2 eq "")&&($color ne ""))
			{
				$price='null' if($price eq '' or $price eq ' ');
				$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' ');
				print "Inside the No colour or size SKU\n";
				$tcolor2=$utilityobject->Translate($tcolor2,$country);	
				if($color)
				{					
					# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
					$dbobject->SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,' ',$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$color);
				}
				else
				{
					# save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
					$dbobject->SaveSku($product_object_key,$article_url,$product_name,$price,$price_text,' ',$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,'');
				}
			}
			
		}
	}
	else  #To take sku details main block not available.
	{
		print "Inside ELSE LOOP FOR SKU\n";
		$price='null' if($price eq '' or $price eq ' ');
		$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' ');
		
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,' ',' ',$out_of_stock,$Retailer_Random_String,$robotname,'');
	}	
	print "\nCrossed the SKU COllection completed.....\n";
	# Image Section.
	# Declaring all required variables to take images.
	my ($lin,$image_page,@defclr,@alternate_image,%alter,%dupliUrl);
	
	# Pattern match to take main block for Images.
	if($content2=~m/>\s*Farbe\s*\:\s*<([\w\W]*?)<\/ul>/is)
	{
		my $blk=$1;
		
		# Loop through to get "article url", "sku code" and "colour" from main block.
		while($blk=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"([^>]*?(?:\=([^<]*?))?)\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?([^<]*?)\s*</igs)
		{
			my $page_url="$url"."$1";
			my $Skucode=$2;
			my $default1=$3;
			$default1='' if($default1=~m/\bnull\b/is); # Pattren match to substitute '' if colour value is null (Helpful for sku has image mapping).
			my $main_image_id;
			print "Image URL COlOUR:: $default1\n";
			print "Page URL:: $page_url\n";
			$image_page=$utilityobject->Lwp_Get($page_url);
			
			# Pattern match(1) to get main image URLs.(Scenario 1).
			if($image_page=~m/<li[^>]*?class\s*\=\s*(?:\"|\')\s*fullscreen\s*(?:\"|\')[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/is)
			{
				$main_image_url=$1;
				$main_image_url="http:".$1 unless($main_image_url=~m/^http/is);
				
				# Pattern match to take main image ID to remove duplicates.
				$main_image_id=$1 if($main_image_url=~m/source\s*\[\s*([^<]*?)\]/is);
				$main_image_url=~s/\/product\/full/\/product\/large/is;
				
				# Downloading and save entry for product images
				my $img_file = $imagesobject->download($main_image_url,'product','hm-DE',$ua);
				# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
				if($default1)
				{
					$dbobject->SaveImage($main_image_url,$img_file,'product',$Retailer_Random_String,$robotname,$default1,'y') if(defined $img_file);
				}
				else # save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
				{
					$dbobject->SaveImage($main_image_url,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
				}
			}
			elsif($image_page=~m/\"\s*product\-image[^\"]*?\"[^>]*?>\s*<img[^>]*?src\=\"\s*([^\"]*?)\"[^>]*?>/is) # Pattern match(2) to get main image URLs.(Scenario 2).
			{
				$main_image_url=$1;
				$main_image_url="http:".$1 unless($main_image_url=~m/^http/is);
				
				# Pattern match to take main image ID to remove duplicates.
				$main_image_id=$1 if($main_image_url=~m/source\s*\]\s*\,value\[([^<]*?)\]\&/is);   
				
				# Downloading and save entry for product images.
				my $img_file = $imagesobject->download($main_image_url,'product','hm-DE',$ua);
				
				# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
				if($default1)
				{
					$dbobject->SaveImage($main_image_url,$img_file,'product',$Retailer_Random_String,$robotname,$default1,'y') if(defined $img_file);;
				}
				else # save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
				{
					$dbobject->SaveImage($main_image_url,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);;
				}
			}
			my $count=1;
			# Pattern match to take block for alternate image URLs.
			if($image_page=~m/<ul[^>]*?id\s*\=\s*\"\s*product\-\s*thumbs\s*\"([\w\W]*?)<\/ul>/is)
			{
				my $blk1=$1;
				
				# Looping through to get alternate image URLs from block.
				while($blk1=~m/<img\s*src\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>/igs)
				{
					$alt_image_url="http:$1";
					
					# Pattern match to take alternate image ID to remove Duplicates.
					my $alt_image_id=$1 if($alt_image_url=~m/source\s*\[\s*([^<]*?)\s*]\s*\,/is); 
					
					# Pattern matches to remove duplicate images of main and alternate images by their IDS(If main and 1st alternate image are same).
					if(($main_image_id eq $alt_image_id)&&($count==1))  
					{
						print "GOTO COUNT LABEL\n";
						goto COUNT;
					}
					
					# Appending home url if URL doesn't start with "http".
					$alt_image_url="http:".$alt_image_url unless($alt_image_url=~m/^http\:/is);
									
					# Changing size of the Alternate images.(in terms of pixels).
					$alt_image_url=~s/\/product\/thumb/\/product\/large/igs;  
					
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($alt_image_url,'product','hm-DE',$ua);

					if($default1)
					{
						# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($alt_image_url,$img_file,'product',$Retailer_Random_String,$robotname,$default1,'n');
					}
					else
					{
						# save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($alt_image_url,$img_file,'product',$Retailer_Random_String,$robotname,'','n');
					}
					
					
COUNT:
print "crossed COUNT LABEL POINT\n";						
					$count++;  # To skip duplication of alternate images removal from 2nd alternate image.
				}
			}				
			# Pattern match to get swatch image URLs.
			while($content2=~m/article\s*\-\s*([^\{]*?)\s*\{\s*background\s*\-\s*image\s*\:\s*url\s*\(([^\)]*?)\)/igs)   
			{
				my $swatch_image_code=$1;
				my $swatch_image_url=$2;
				print "Image Looping...\n";
				# Appending http if URL dosn't start with. 
				$swatch_image_url="http:".$swatch_image_url unless($swatch_image_url=~m/^http\:/is);
				
				if($swatch_image_code eq $Skucode)
				{
					# Appending http if URL dosn't start with. 
					$swatch_image_url='http:'.$swatch_image_url unless($swatch_image_url=~m/^\s*http\:/is);
					
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($swatch_image_url,'swatch','hm-DE',$ua);
					
					if($default1)
					{
						# save entry to Image table with colour as mapping element($default1),if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$default1,'n') if(defined $img_file);
					}
					else
					{
						# save entry to Image table with null as mapping element(' '),if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,'','n') if(defined $img_file);
					}
				}
			}
		}
	}
	elsif($content2=~m/\"\s*product\-image[^\"]*?\"[^>]*?>\s*<img[^>]*?src\=\"\s*([^\"]*?)\"[^>]*?>/is) # Pattern match to take image URLs (Scenario 2 if colour block not availble but images available)
	{
		$main_image_url=$1;
		print "Main Image URL:: $main_image_url\n";
		# Appending http if URL dosn't start with. 
		$main_image_url="http:".$1 unless($main_image_url=~m/^http\:/is);
				
		# Downloading and save entry for product images
		my $img_file = $imagesobject->download($main_image_url,'product','hm-DE',$ua);
		
		# save entry to Image table ,if image download is successful. Otherwise throw error in log.(Color Not available).
		$dbobject->SaveImage($main_image_url,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file); 
		
		# Pattern match to gett swatch image URLs.
		while($content2=~m/article\s*\-\s*[^<]*?\s*\{\s*background\s*\-\s*image\s*\:\s*url\s*\(([^\)]*?)\)/igs)  
		{
			my $swatch_image_url=$1;
			
			# Appending http if URL dosn't start with. 
			$swatch_image_url='http:'.$swatch_image_url unless($swatch_image_url=~m/^\s*http\:/is);
			
			# Downloading and save entry for product images.
			my $img_file = $imagesobject->download($swatch_image_url,'swatch','hm-DE',$ua);
			
			# save entry to Image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,'','n') if(defined $img_file);
		}
	}
		
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);	
	
	PNF:
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url,$retailer_id,$mflag);

	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	
	ENDOFF:
	# Committing transaction and undefine the query array
	$dbobject->commit();	
	$dbobject->Destroy();		
	$price=$price_text=$brand=$product_id=$product_name=$description=$prod_detail=$out_of_stock=$color=$main_image_url=$alt_image_url=$swatch_image_url=undef;
}1;


##Function to remove Special Characters in Data
# sub clear
# {
  # my $data=shift;  
  # $data=~s/š//igs;	
  # $data=~s/Ë/°/igs;
  # $data=~s/Ã//igs;
  # $data=~s/Â//igs;
  # return $data;		
# }