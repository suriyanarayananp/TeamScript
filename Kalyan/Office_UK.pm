# Required Module Initialization.
package Office_UK;
use strict;
use HTML::Entities;
use Config::Tiny;
use Try::Tiny;

sub Office_UK_DetailProcess()
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
	my $Retailer_Random_String='Off';
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
	
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	my $content = $utilityobject->Lwp_Get($url);
		
	my ($mflag,$price,$price_text,$size,$type,$brand,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color);
	
	# Patten matching for product product_id
	if ($content=~m/<p\s*class\=\"productCode\s*bold\">\s*Style\s*number\s*([^>]*?)\s*<\/p>/is)
	{
		$product_id = $1;
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	
	# Patten matching for product Colour.
	if ($content=~m/<h2\s*class\=\"productColour[^>]*?\">\s*([^>]*?)\s*<\/h2>/is)
	{
		$color = $1;
	}
	else
	{
		$color='no raw colour';
	}

	# Patten matching for product product_name.
	if ($content=~m/<h1\s*class\=\"productBrand\s*bold\s*\">\s*([^>]*?)\s*<\/h1>/is)
	{
		$brand = $1;
	}
	
	# Patten matching for product product_name.
	while ( $content =~ m/<h2\s*class\=\"productName[^>]*?>\s*([^>]*?)\s*<\/h2>/igs )
	{
		$product_name = $utilityobject->Trim($product_name.' '.$1);
	}

	# Patten matching for product product_name.
	if($content=~m/<div\s*class\=\"productDetail_main_pricelist[^>]*?>([\w\W]*?<\/div>)\s*<\/div>/is)
	{
		my $price_content=$1;
		$price_content=~s/\s*<sup>\s*//igs;
		
		# Price text includes collection of current price and price text
		while($price_content=~m/<div\s*class\=\"productDetail[^>]*?>([\w\W]*?)<\/div>/igs)
		{
			$price_text = $price_text.' '.$utilityobject->Trim($1);
			$price_text=~s/\&nbsp\;/ /igs;
			$price_text=~s/\s+/ /igs;
			$price_text=~s/^\s+|\s*$//igs;
			$price_text=~s/\.s+/\./igs;			
		}
		
		# Collection of current price only
		if($price_content=~m/<div\s*class\=\"productDetail[^>]*?id\=\"now_price\">\s*([\w\W]*?)\s*<\/div>/is)
		{
			$price = $utilityobject->Trim($1);
			if($price=~m/\£([^>]*?)$/is)
			{
				$price=$1;
			}
			$price=~s/\£//igs;		
		}		
	}
	$price=~s/\s+//igs;
	
	# Patten matching for product description.
	if ($content=~m/<div\s*id\=\"productDetail_tab[^>]*?\"\s*[^>]*?\">\s*<h3>([\w\W]*?)<\/h3>/is)
	{			
		$description = $1;
		if($description=~m/^\s*([\w\W]*?)\s*<strong>\s*About[^>]*?<\/strong>\s*<\/p>\s*([\w\W]*?)\s*<\/p>/is)
		{
			$description = $1;
			$prod_detail=$2;
		}
		$prod_detail = $utilityobject->Trim($prod_detail);
		$description = $utilityobject->Trim($description);
	}
	
	# Out of Stock details collection
	if($content=~m/<span\s*class\=\"stockLevelIndicator[^>]*?\">\s*Out\s*of\s*stock\s*<\/span>/is)
	{
		$out_of_stock = 'y';
	}
	else
	{
		$out_of_stock = 'n';
	}
	
	# Isolating size block from content
	if($content=~m/<option\s*value[^>]*?>Select\s*Size<\/option>([\w\W]*?)<\/select>/is)
	{
		my $size_block=$1;
		
		# Collecting the sizes from the size block
		while($size_block=~m/<option\s*value\=\"[^>]*?\">\s*([^>]*?)\s*<\/option>/igs)
		{
			$size=$1;						
			# Save the collected sku.
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
		}
	}
	else
	{	
		$size='';
		# Save the collected sku.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
	}
	
	#Patten matching for image block.
	if ($content=~ m/<div\s*id\=\"ql_product_thumbnails\"\s*class=\"ql_product_thumbnails\">\s*<ul>\s*([\W\w]*?)\s*<\/ul>\s*<\/div>/is)
	{
		my $image_block=$1;
		my $count=1;
		# Patten matching for image.
		while($image_block=~m/<li\s*class\=\"ql_product_thumbnail\s*floatProperties\">\s*<img\s*class=[^>]*?highres\=\"([^>]*?)\"\s*picture/igs)
		{
			my $image = $1;
			$image=~s/^\s+|\s*$//igs;
			$image = "http:$image";
			
				if ( $count == 1 )
				{
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($image,'product',$retailer_name,$ua);
					
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$color,'y') if(defined $img_file);
					
				}
				else
				{
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($image,'product',$retailer_name,$ua);
					
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$color,'n') if(defined $img_file);
				}
				$count++;
		}
		
	}
	elsif($content=~m/<div\s*class\=\"ql_product_picture\s*floatProperties\s*[^>]*?>\s*<a\s*href\=\"([^>]*?)\"\s*class\=\"MagicZoom\"[^>]*?>/is)
	{
		my $image = $1;
		$image=~s/^\s+|\s*$//igs;
		$image = "http:$image";
		
		# Downloading and save entry for product images.
		my $img_file = $imagesobject->download($image,'product',$retailer_name,$ua);
		
		# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
		$dbobject->SaveImage($image,$img_file,'product',$Retailer_Random_String,$robotname,$color,'y') if(defined $img_file);
	}
	
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
		
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url,$retailer_id,$mflag);

	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	ENDOFF:
	
	# Commit all the transaction.
	$dbobject->commit;

	# Destroying the DB Object.
	$dbobject->Destroy;
}1;