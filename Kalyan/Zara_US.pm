#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
package Zara_US;
use strict;

sub Zara_US_DetailProcess()
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
	my $Retailer_Random_String='Zus';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the country code from retailer name.
	# my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is); # No need since currency is in USD for this retailer.
	
	# Setting the environment.
	$utilityobject->SetEnv($ProxyConfig);
	
	# Return to calling script if product object key is not available.
	return if($product_object_key eq ''); 
	
	# Appending the home url if url doesn't start with "http".	
	$url='http://www.zara.com/us/'.$url unless($url=~m/^\s*http\:/is);
		
	# Get the content from the urls'.
	my $content=$utilityobject->Lwp_Get("$url");
	
	# Pattern match to check whether the product is a multiple product item (To denote as M Product).	
	if($content=~ m/<li\s*class=\"bundle-item\"\s*[\w\W]*?\s*<div\s*class=\"bundle\-item\-description\"\s*>/is)
	{
		$mflag=1;
	}
		
	# Pattern match to check whether product details available (To denote as X Product).
	goto PNF if($content=~m/>\s*We\s*are\s*sorry\s*\.\s*The\s*item\s*you\s*are\s*looking\s*for\s*is\s*no\s*longer\s*available\s*\.\s*/is);
		
	# Declaring required variables.		
	my ($price,$price_text,$brand,$product_id,$product_name,$description,$prod_detail,$out_of_stock,@colour,$Url1_inside,$size,$blk,@colour1,$clr1,%AllColor,$clr,$blk1,@swa_clr,$ckproduct_id,$skuDetailFlag,$main_image,$image);
	my $j=0;
	
	# Pattern match to get product's ID(Scenario 1).
	if($content=~m/<p[^>]*?class\s*\=\s*\"reference\s*\"\s*>\s*Ref(?:\.|\:)\s*([^<]*?)\s*</is)
	{
		$product_id=$utilityobject->Trim($1);
		$ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	elsif($content=~m/<div\s*id\s*\=\s*\"\s*page\s*\-\s*container\"[^>]*?\s*product\s*Ref\s*\:\s*(?:\'|\")([^\'\"]*?)(?:\'|\")/is)
	# Pattern match to get product's ID(Scenario 2).
	{
		$product_id=$utilityobject->Trim($1);
		$ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	
	# Pattern match to get product name.
	if ( $content =~ m/<h1[^>]*?>([^<]*?)</is )
	{
		$product_name=&clear($utilityobject->Trim($1));
	}
	
	# Pattern match to get product detail.
	if ( $content =~ m/<div\s*class=\"hidden\-content\"\s*>\s*<h2>\s*Composition\s*<\/h2>\s*<ul>\s*([\w\W]*?)\s*<\/ul>\s*<\/div>\s*<\/div>/is )
	{
		$prod_detail = &clear($utilityobject->Trim($1));
	}
	
	# Pattern match to get product description.
	if ( $content =~ m/<\s*p\s*(?:class|id)\s*\=\s*(?:\"|\')\s*description\s*(?:\"|\')\s*>([^<]*?)<(?:[\w\W]*?<div\s*class\s*\=\s*\"\s*bundle\s*\-\s*item\s*\-\s*description\s*\"\s*>(?:(?:\s*<[^>]*?>\s*)+\s*)?([^<]*?)<)?/is )
	{
		$description = &clear($utilityobject->Trim($1." $2"));
	}
	
	goto IMAGE if($mflag);
		
	# Pattern match to get price & price text.
	if ( $content =~ m/<span[^>]*?data\-price\s*\=\s*\"\s*(\d+[^\"]*?\s*(?:USD)?)\"[^>]*?>(?:[^>]*?(?:\s*<[^>]*?>\s*)+\s*-\s*<span[^>]*?data\s*\-\s*price\s*\=\s*\"(\d+[^\"]*?\s*(?:USD)?)\s*\"\s*>)?/is )
	{
		$price_text=$utilityobject->Trim($1);
		my $price_text1=$utilityobject->Trim($2);
		if($price_text=~m/(\d[^<]*)\s*USD/is)
		{
			$price=$1;
		}
		
		if($price_text1)
		{
			$price_text="$price_text"."-"."$price_text1";
		}
		# Encode the Pricetext using country code.
		# $price_text = $utilityobject->PriceFormat($PriceCont, $ccode); Price text in USD.Hence no need.
		$price="null" if($price eq '' or $price eq ' ');
	}
		
	# Pattern match to get block to take product colour.
	if ( $content =~ m/Choose\s*a\s*colour\s*<([\w\W]*?)(?:<\/label>\s*<\/div>|<h2)/is )
	{
		$blk=$1;
		
		# Looping through to get each colour value.
		while($blk=~m/title\s*\=\s*(?:\"|\')([^>]*?)\s*(?:\"|\')[^>]*?>/igs)
		{
			my $colour1 = $utilityobject->Trim($1);
			push(@colour,$colour1);
			
			# To increment colour value.(eg.Green,Green1).
			# Pattern match to check whether colour value is greater than 1(i.e repeated).
			if($AllColor{$colour1}>0)
			{
				$AllColor{$colour1}++;		# Incrementing the colour value with the help of hash.
				my $tcolor1 = $colour1.'('.$AllColor{$colour1}.')'; # Appending the colour value.(Blue , Blue1).
				$clr1=$tcolor1;
			}
			else
			{
				$AllColor{$colour1}++;
				$clr1=$colour1;
			}
			push(@colour1,$clr1); # Pushing the incremented value of colour into the array.
		}
	}
	
	# Pattern match to get product size & out_of_stock & colour.
	if(@colour)	  # To check whether colour(array) available.	
	{
		my $i=0;
		
		# Looping through to get each size block to take size and Out of stock.
		while($content=~m/\{\"\s*sizes\s*\"\s*\:([\w\W]*?)\"pColorImgNames\"/igs)   
		{
			my $blk_clr=$1;
			
			# Looping through to get each size and out of stock values.
			while($blk_clr=~m/\{\s*[^\}]*?\,\s*\"\s*availability\s*\"\s*\:\s*\"([^\,]*?)\s*\"\,[^\}]*?\s*\"\s*description\s*\"\s*\:\s*\"([^\"]*?)\"\}/igs)
			{
				$out_of_stock=$1;
				$size=$2;
				$skuDetailFlag=1;
				
				# Pattern substitutions whether out of stock should be marked as "y" or "n".
				$out_of_stock =~ s/^\s*In\s*Stock\s*$/n/igs;
				$out_of_stock =~ s/^\s*Out\s*Of\s*Stock\s*$/y/igs;
				$out_of_stock =~ s/^\s*Coming\s*Soon\s*$/y/igs;
				$out_of_stock =~ s/^\s*Back\s*Soon\s*$/y/igs;	
				
				$size='One size' if($size eq '' or $size eq ' '); # Assigning size value if size value is null.
				$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' '); # Assigning out of stock value if out of stock value is null.
				
				# To change raw color value into needed case(Off-white as Off-White).
				# Assigning the incremented colour value to a variable.
				$clr = lc($colour1[$i]);
				my $tcolor;
				while($clr =~ m/([^>]*?)(?:\s+|\-|$)/igs)
				{
					if($tcolor eq '')
					{
					  $tcolor = ucfirst($&);
					}
					else
					{
						$tcolor = $tcolor.ucfirst($&)
					}
				}
				
				$tcolor=~s/\- /-/igs if($clr=~m/[^<]*\w+\-\w+[^<]*/is);	

				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$tcolor,$out_of_stock,$Retailer_Random_String,$robotname,$colour[$i]);
			}
			$i++;
		}
	}
	else # Save sku details into Sku table if color not available.
	{
		$size='One size' if($size eq '' or $size eq ' ');
		$out_of_stock='n' if($out_of_stock eq '' or $out_of_stock eq ' ');
		$skuDetailFlag=1;
		
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'','',$out_of_stock,$Retailer_Random_String,$robotname,'');
	}	
	
	# Images Section.
IMAGE:	
	if($mflag) # Getting images of the multiple product item (Scenario3).
	{
		my $count=1;
		
		# Pattern match to get image block.
		if($content=~m/<div\s*class\s*\=\s*\"\s*bigImageContainer\"[^>]*?>\s*[\w\W]*?<\/div>\s*<\/div>\s*<\/div>/is)
		{
			my $blkimg=$&;
			
			# Looping through to get each image urls from the block taken above.
			while($blkimg=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/igs)
			{
				my $image = $utilityobject->Trim($1);
				$image =~ s/photos\/\//photos\//igs;
				$image="http:"."$image" unless($image=~m/^\s*http\:/is); 
				
				# Downloading and save entry for product images.
				my $img_file = $imagesobject->download($image,'product',$retailer_name,$ua);
				
				# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
				if($count==1)
				{
					#Main image urls Collection.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
					$count++;
				}
				else
				{		
					#Alternate image urls Collection.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,'','n') if(defined $img_file);
				}
			}
		}
		elsif($content=~m/<div[^>]*?class\s*\=\s*\"big\s*Image\s*Container\s*\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/is)# Pattern match to get main image url if block not available for the multiple product item.
		{
			$main_image = $1;
			$main_image =~ s/\$//g;	
			$main_image =~ s/photos\/\//photos\//igs;
			$main_image="http:"."$main_image" unless($main_image=~m/^\s*http\:/is);
			
			# Downloading and save entry for product images
			my $img_file = $imagesobject->download($main_image,'product',$retailer_name,$ua);
			
			# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($main_image,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
		}
		goto PNF;
	}
	# Pattern match to take swatch images block.
	if ( $content =~ m/Choose\s*a\s*colour\s*<([\w\W]*?)(?:<\/label>\s*<\/div>|<h2)/is ) 
	{
		$blk1=$1;
		
		# Pattern match to get swatch image url and swatch colour value from the block.
		while($blk1=~m/title\s*\=\s*(?:\"|\')([^>]*?)\s*(?:\"|\')[^>]*?>\s*<img[^>]*?src\s*\=\s*(?:\"|\')\s*([^\"\'\?]*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/igs)
		{
			my $swa_clr=$1;
			my $Swatch_image_url=$2;
			
			$Swatch_image_url =~ s/photos\/\//photos\//igs;
			
			push(@swa_clr,$swa_clr); # Pushing swatch colour into "@swa_clr" to use as Objectkey for main and swatch images.

			# Checking whether swatch image url is non-empty.
			if($Swatch_image_url ne "")
			{
				# Appending home url if url doesn't start with "http".				
				$Swatch_image_url="http:"."$Swatch_image_url" unless($Swatch_image_url=~m/^\s*http\:/is);
				
				# Downloading and save entry for product images.
				my $img_file = $imagesobject->download($Swatch_image_url,'swatch',$retailer_name,$ua);
				
				# Save entry to image table ,if image download is successful. Otherwise throw error in log.
				$dbobject->SaveImage($Swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$swa_clr,'n') if(defined $img_file);;
			}
		}	
	}	
	
	# Pattern match to get image main block.(Scenario1).
	if($content =~ m/\{\s*subscribeLabel\s*\}\s*\}\s*(?:\s*<[^>]*?>\s*)+\s*([\w\W]*?)<\/script>/igs) #Images Block 
	{
		my $block=$&;
		my $k=0;
		
		# Looping through to get each sub block from the block taken above.
		while($block=~m/{\s*\"\s*xmedias\s*\"\s*\:\s*\[\s*\{\s*\"\s*datatype\s*\"\s*\:([\w\W]*?)\}\s*\]/igs)  
		{
			my $block1=$&;
			my $count=1;
			
			# Looping through to get each image urls from the block taken above.
			while ( $block1 =~ m/(?:\"|\')\s*url\s*(?:\"|\')\s*\:\s*(?:\"|\')\s*([^\"\'\?]*)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^\}]*?\}/igs )
			{
				$image = $utilityobject->Trim($1);
				$image =~ s/photos\/\//photos\//igs;
				
				# Appending "http" if image url doesn't start with "http".
				$image="http:"."$image" unless($image=~m/^\s*http\:/is);
				
				# Downloading and save entry for product images.
				my $img_file = $imagesobject->download($image,'product',$retailer_name,$ua);
				
				# Save entry to image table ,if image download is successful. Otherwise throw error in log.
				if(@colour)
				{
					if($count==1)
					{
						# Getting main image url.
						# Save entry to image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$colour[$k],'y') if(defined $img_file);
						print "save Image2:: $image \t $swa_clr[$k] \t y \n";
						$count++;
					}
					else
					{		
						# Getting alternate image urls.
						# Save entry to image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$colour[$k],'n') if(defined $img_file);
						print "save Image2:: $image \t $swa_clr[$k] \t n \n";
					}						
				}
				elsif($count==1)
				{
					#Main image urls Collection.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$swa_clr[$k],'y') if(defined $img_file);
					$count++;
				}
				else
				{		
					#Alternate image urls Collection.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$swa_clr[$k],'n') if(defined $img_file);
				}
			}
			$k++;	
		}
	}
	elsif($content=~m/<div[^>]*?class\s*\=\s*\"big\s*Image\s*Container\s*\"[^>]*?>(?:(?:\s*<[^>]*?>\s*)+\s*)?\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)\s*(?:\?\s*timestamp=[^\"\']*?)?\s*(?:\"|\')[^>]*?>/is) # Pattern match to get main image url.(Scenario 2).
	{
		$main_image = $1;
		$main_image =~ s/\$//g;			
		$main_image =~ s/photos\/\//photos\//igs;
		$main_image="http:"."$main_image" unless($main_image=~m/^\s*http\:/is);
		
		# Downloading and save entry for product images
		my $img_file = $imagesobject->download($main_image,'product',$retailer_name,$ua);
		
		# Save entry to image table ,if image download is successful. Otherwise throw error in log.
		$dbobject->SaveImage($main_image,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
		
		
	}
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
	
	# Checking whether product_name,product_id are not null and have sku detail(Checking whether Instock Product->should be marked as Product).
	if(($product_name eq '')&&($product_id ne '')&&($skuDetailFlag))
	{
		$product_name='-';
	}
	# Checking whether description,prod_detail are null but product id not null and have sku detail(Checking whether instock product->should be marked as 'y' ).
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
	
	# Committing transaction and undefine the query array
	$dbobject->commit();
	$dbobject->Destroy();
}1;

sub clear()
{
	my $text=shift;
	$text=~s/ร/ษ/igs;
	$text=~s/ยบ/บ/igs;
	$text=~s/ย//igs;
	return $text;
}		
