#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Peacocks_UK;
use strict;

sub Peacocks_UK_DetailProcess()
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
	my $Retailer_Random_String='Pea';
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
	
	# Return if ProductObjectkey is null.
	return if($product_object_key eq '');
	
	my $source_page = $utilityobject->Lwp_Get($url);
	goto PNF if($source_page =~ m/<h1>\s*(Whoops\!)\s*<\/h1>/is); # Source page contains whoops! when requested product not found in the website and detail collected for this url will be marked as 'x'.
	goto PNF if($source_page !~ m/class\=\"stock\-available\">\s*Available\s*<\/span>/is); # Source page which does not pattern matches for stock available and detail collected for this url will be marked as 'x'.
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/Number\:\s*(\d+)\s*[^>]*?\s*</is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
		
		# Verification on product table, whether retailer product reference was already exist. if exist duplicate product will be removed from the product table and further scrapping will be skipped.
		my $ckproduct_id = $dbobject->UpdateProducthasTag($retailer_product_reference, $product_object_key, $robotname, $retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}

	# Pattern match of product name.
	if($source_page =~ m/<header>\s*<h1>([^>]*?)<\/h1>/is)
	{
		$product_name = $utilityobject->Trim($1);
	}

	# Brand name - all the products in the retailer website belongs to own (peacocks) brand (no external brands are available).
	$brand = 'Peacocks';

	# Pattern match of product description.
	if($source_page =~ m/description\">\s*([^>]*?(?:<[^>]*?>[^>]*?)*?)\s*<\/p>/is)
	{
		$product_description = $utilityobject->Trim($1);
		$product_description =~ s/â€//igs;
	}

	# Pattern match of product detail.
	if($source_page =~ m/extra\">\s*([^>]*?(?:<br\s*\/>[^>]*?)*?)\s*<\/p>/is)
	{
		$product_detail = $utilityobject->Trim($1);			
	}
	
	# Pattern match of price text.
	if($source_page =~ m/price\-box\">\s*([\w\W]*?)\s*<\/div>/is)
	{
		$price_text = $1;
		$price_text = $utilityobject->PriceFormat($price_text, $ccode);
	}	
	
	# Pattern match of current price (two types).
	if($source_page =~ m/regular\-price\"[^>]*?>\s*<span\s*class\=\"price\">\s*[^>]*?([\d\.]*?)\s*</is)
	{
		$current_price = $utilityobject->Trim($1);
	}
	elsif($source_page =~ m/<strong\s*class\=\"price\"\s*id\=\"[^>]*?\">\s*[^>]*?([\d\.]*?)\s*<\/strong>/is)
	{
		$current_price = $utilityobject->Trim($1);
	}
	
	# Pattern match of raw colours.
	while($source_page =~ m/<a[^>]*?href\=\"([^>]*?)\"[^>]*?title\=\"([^>]*?)\">\s*<span\s*class\=\"swatch\">\s*<img\s*src\=\"([^>]*?)\"[^>]*?\/>/igs)
	{
		my $color_url = $1;
		my $raw_colour = $utilityobject->Trim($2);
		my $swatch_image_url = $3;
		$swatch_image_url =~ s/^\s+|\s+$//g;
		my $color_page = $utilityobject->Lwp_Get($color_url);
		
		# Saving swatch image.
		my $img_file = $imagesobject->download($swatch_image_url,'swatch',$retailer_name,$ua);
		$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$raw_colour,'n') if(defined $img_file);

		# Pattern match of size block.
		if($color_page =~ m/<\/dl>\s*<script[^>]*?>\s*([\w\W]*?)\s*<\/script>\s*<div\s*class\=\"no\-display\">/is)
		{
			my $size_block = $1;
			
			# Pattern match of size and out of stock.
			while($size_block =~ m/\"label\"\:\"((?!Size)[^>]*?)\"/igs)
			{
				my $size = $utilityobject->Trim($1);
				my $out_of_stock = 'n'; # In stock - only in-stock products are available in the retailer website.
				
				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$Retailer_Random_String,$robotname,$raw_colour);
			}
			undef $size_block;
		}
		
		# Pattern match of image block.
		if($color_page =~ m/data\-images\=\"[^>]*?default([^>]*?)\">/is)
		{
			my $image_block = $1;
			my $count = 1;
			
			# Pattern match of product image.
			while($image_block =~ m/large\&quot\;\:\&quot\;(http\:[^>]*?970x1274[^>]*?)\&quot\;\}/igs)
			{
				my $image_url = $utilityobject->Trim($1);					
				$image_url =~ s/\\\//\//g;
				
				if($count == 1) # Deploying default image details into image table.
				{					
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_colour,'y') if(defined $img_file);
				}
				else # Deploying alternate image details into image table.
				{					
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_colour,'n') if(defined $img_file);
				}
				$count++;
			}
			undef $image_block;
		}
	}
	undef $source_page;
		
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
		
	PNF:
	
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$retailer_product_reference,$product_name,$brand,$product_description,$product_detail,$robotname,$url,$retailer_id,$mflag);
	
	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	
	ENDOFF:
	
	# Commit all the transaction.
	$dbobject->commit();
	
	# Destory global variables in AnorakDB.
	$dbobject->Destroy();
}1;