# Required Module Initialization.
package Aeropostale_US;
use strict;

sub Aeropostale_US_DetailProcess()
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
	my $Retailer_Random_String='Aer';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the Country from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);

	# Setting the Environment.
	$utilityobject->SetEnv($ProxyConfig);
		
	# Return to calling script if product object key is not available.
	return if($product_object_key eq '');

	my $url3=$url;
	$url3 =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	my $content2 = $utilityobject->Lwp_Get($url3);
	
	my ($mflag,$price,$price_text,$size,$type,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color);
	
	if($content2=~m/onclick\=enable_quantity\(this\,[\d]+?\)>\s*<span>\s*(select\s*this\s*item)\s*<\/span>/is)
	{
		$mflag =1;
	}
	
	# Patten macthing for product price_text
	if( $content2 =~ m/addItemsToBagTop/is )
	{
		if( $content2 =~ m/childProdImage\">\s*<a\s*href\=\"([^>]*?)\"/is )
		{			
			goto PNF;			
		}	
	}
	# Patten macthing for product price_text.
	elsif ( $content2 =~ m/<ul\s*class\=\"price\">([\w\W]*?)<\/ul>/is )
	{
		$price_text = $1;
		$price_text = $utilityobject->Trim($price_text);
	}

	# Patten macthing for product product_id
	if ( $url3 =~ m/productId\=([\d]*)\s*$/is)
	{
		$product_id = $utilityobject->Trim($1);
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}

	# Patten macthing for product product_name.
	if ( $content2 =~ m/<h2>([^>]*?)<\/h2>/is )
	{
		$product_name = $utilityobject->Trim($1);
		$product_name=$utilityobject->UTF8Encode($product_name);
		$product_name=$utilityobject->DecodeText($product_name);
		$product_name=$utilityobject->Decode($product_name);
	}

	# Patten macthing for product description.
	if ($content2=~m/<div\s*class\=\'product\-description\'>([\w\W]*?)<\/div>/is)
	{		
		$description = $utilityobject->Trim($1);			
		$description=$utilityobject->UTF8Encode($description);
		$description=$utilityobject->DecodeText($description);
		$description=$utilityobject->Decode($description);
	}
	
	#Patten macthing for swatch image block.
	my @colur_t;
	if ($content2 =~ m/<ul\s*class\=\"swatches\s*clearfix\">\s*([\w\W]*?)<\/ul>/is)
	{
		my $color_main_swat_block=$1;
		
		# Patten macthing for swatch image.
		while($color_main_swat_block=~m/<img\s*src\=\"([^>]*?)\"\s*alt\=\"([^>]*?)\"/igs)
		{
			my $swatch = $utilityobject->Trim($1);
			my $colour_id=$utilityobject->Trim($2);
			$colour_id=lc($colour_id);
			$swatch = "http://www.aeropostale.com$swatch";
			
			# Downloading and save entry for product images
			my $img_file = $imagesobject->download($swatch,'swatch',$retailer_name,$ua);
					
			# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($swatch,$img_file,'swatch',$Retailer_Random_String,$robotname,$colour_id,'n') if(defined $img_file);
			
			# Push the color id into an array.
			push(@colur_t,$colour_id);
		}
		
		if($color_main_swat_block=~m/^\s*$/is)
		{
			if($content2=~m/<label\s*id\=\"colorLabel\">Color\s*\:\s*([^>]*?)\s*<\/label>/is)
			{
				my $colour_id=$1;
				push(@colur_t,$colour_id);
			}			
		}
	}
	elsif($content2=~m/<label\s*id\=\"colorLabel\">Color\s*\:\s*([^>]*?)\s*<\/label>/is)
	{
		my $colour_id=$1;
		push(@colur_t,$colour_id);
	}
	
	# Patten matching for size & out_of_stock
	if( $content2 =~ m/itemMap\s*\=\s*new\s*Array\(\)\;([^^]*?)<\/script>/is )
	{
		my $size_content = $1;
		my $color;
		my %color_hash;
		# Check then color_t array.
		if(@colur_t)
		{
			foreach my $c (@colur_t)
			{
				
				while($size_content=~m/sDesc\:\s*\"([^\"]*?)\"[^\{\}]*?cDesc\:\s*\"\s*($c)\s*\"[^\{\}]*?avail\:\s*\"([^\"]*?)\"\,\s*price\:\s*\"[^\"]*?([\d.]+)\"/igs)
				{			
					my $size = $utilityobject->Trim($1);
					$color = $utilityobject->Trim($2);
					$color = lc($color);
					$price = $utilityobject->Trim($4);
					my $availablity = $utilityobject->Trim($3);
					my $out_of_stock;		
					# Patten matching for out of stock.
					$out_of_stock = 'n';			
					$out_of_stock = 'y' if($availablity !~m/IN_STOCK|LOW\s*_?\s*STOCK/is);
					$price ='NULL' if($price=='');
					
					# Save the collected sku.
					$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
				}
			}
		}
		else
		{
			$color ='No raw colour';
			my $out_of_stock='n';
			my $size ='No size';
			# Pattenmatching for price.
			$price=$1 if($price_text=~m/<ul\s*class=\"price\"><li>[^<]*?([\d\,\.]+)\s*<\/li>/is);
			$price=$1 if($price_text=~m/<li\s*class="now">now[^<]*?([\d\,\.]+)\s*<\/li>/is);
			$price ='NULL' if($price=='');
			
			# Save the collected sku.
			$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
		}
	}
	
	# Pattern matching for checking image availability. 	
	if ( $content2 =~m/store\.product\.alternate(?:Prod)?Images\[\d+\]\s*\=\s*\[([\w\W]*?)\]\;/is)
	{
		my $count_col=0;
		
		# Patten matching for getting image block.
		while ( $content2 =~m/store\.product\.alternate(?:Prod)?Images\[\d+\]\s*\=\s*\[([\w\W]*?)\]\;/igs)
		{
			my $block=$1;
			my $count=0;
			
			# Patten macthing for product image. 
			while($block =~m/enh\:\s*\"(\/[^>]*?)\"\s*}/igs )
			{
				my $alt_image; $count++;
				$alt_image="http://www.aeropostale.com$1" if($1 ne '');
				
				my $img_file;
				$alt_image =~ s/\\\//\//g;
				$img_file = (split('\/',$alt_image))[-1];

				if ( $count == 1 )
				{
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($alt_image,'product',$retailer_name,$ua);
					
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($alt_image,$img_file,'product',$Retailer_Random_String,$robotname,$colur_t[$count_col],'y') if(defined $img_file);
					
				}
				else
				{
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($alt_image,'product',$retailer_name,$ua);
					
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($alt_image,$img_file,'product',$Retailer_Random_String,$robotname,$colur_t[$count_col],'n') if(defined $img_file);
				}
			}
			$count_col++;
		}
	}
		
	# Default brand.
	$brand="aeropostale";
		
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
	
	PNF: # Label for Duplicate entry.
	
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url3,$retailer_id,$mflag);

	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	ENDOFF:
	
	# Commit all the transaction.
	$dbobject->commit;
}1;

