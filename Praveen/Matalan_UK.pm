#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Matalan_UK;
use strict;

sub Matalan_UK_DetailProcess()
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
	my $Retailer_Random_String='Mat';
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
	goto PNF if($source_page =~ m/<title>Page\s*Not\s*Found\s*\-\s*Matalan\s*<\/title>/is); # Pattern match of unavailable product.
	
	# Required variables are declared globally.	
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$raw_colour,$current_price,$price_text,$size,$out_of_stock);
		
	# Pattern match of retailer product reference.
	if($source_page =~ m/\"id\"\s*\:\s*\"([^>]*?)\"/is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
		$retailer_product_reference = lc($retailer_product_reference);
	}
	
	# Pattern match of product name.
	if($source_page =~ m/<h1[^>]*?>\s*([^>]*?)\s*</is)
	{
		$product_name = $utilityobject->Trim($1);
	}		
	
	# Pattern match of external brand.
	if($source_page =~ m/brand\s*tag\-([\w]+)\"/is)
	{
		$brand = $1;
		$brand =~ s/__/ & /igs;
		$brand =~ s/_/ /igs;
		$brand =~ s/(\w+)/\u\L$1/g; # Makes first letter capital for each word.
	}
	else # Otherwise Own brand.
	{
		$brand = 'Matalan';
	}
	
	# Pattern match of product description.
	if($source_page =~ m/class\=\"description\"[^>]*?>([^>]*?(?:<[^>]*?>[^>]*?)*?)<\/div>/is)
	{
		$product_description = $utilityobject->Trim($1);
	}
	
	# Pattern match of product detail.
	if($source_page =~ m/Product\s*Information\s*<\/a>\s*([\w\W]*?)\s*<\/dl>/is)
	{
		$product_detail = $utilityobject->Trim($1);
	}
	
	# Pattern match of price text.
	if($source_page =~ m/<ul\s*class\=\"prices\"[^>]*?>\s*([\w\W]*?)\s*<\/ul>/is)
	{
		$price_text = $utilityobject->Trim($1);
		$price_text =~ s/\&\#163\;/\Â\£/igs;		
	}

	# Pattern match of current price.
	if($source_page =~ m/itemprop\=\"price\">(?:\s*Now)?\s*([^>]*?)</is)
	{
		$current_price = $1;
		$current_price =~ s/\&\#163\;//igs;
	}
	
	# Pattern match of raw colours.
	my %hash_color;
	while($source_page =~ m/<input[^>]*?name\=\"Color\"[^>]*?value\=\"([^>]*?)\"\s*\/>\s*<label[^>]*?>\s*([^>]*?)\s*<\/label>/igs)
	{
		my $color_code = $1; # Colour code.
		$raw_colour = $utilityobject->Trim($2); # Raw colour.
		
		my $color_url = 'http://www.matalan.co.uk/product/detail/'.$retailer_product_reference.'?id='.$retailer_product_reference.'&color='.$color_code;
		
		# Validating raw colour for duplicates - if duplicate found, colour code (i.e., $color_code) will be appended to the duplicate raw colour (example: white (c109)).
		if($hash_color{$raw_colour} eq '')
		{
			$hash_color{$raw_colour} = $raw_colour;
		}
		else
		{
			$raw_colour = $raw_colour.' ('.$color_code.')';				
		}
		
		$raw_colour = lc($raw_colour);				
		$raw_colour =~ s/(\w+)/\u\L$1/g; # Makes first letter capital for each word.
		my $color_content = $utilityobject->Lwp_Get($color_url);
		next if($color_content == 1);
		
		# Pattern match of size - type 1.
		if($color_content =~ m/<ul\s*class\=\"sizes\">([\w\W]*?)\s*<\/ul>/is)
		{
			my $size_group = $1;
			
			# Pattern match of in-stock sku.
			while($size_group =~ m/data\-max\=\"\d+\"\s*\/>\s*<label\s*for\=\"[^>]*?\"\s*>\s*([^>]*?)\s*(?:<[^>]*?>[^>]*?)*?<\/label>/igs)
			{
				$size = $utilityobject->Trim($1);
				$out_of_stock = 'n'; # In stock.
				
				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);				
			}
			
			# Pattern match of out of stock sku.
			while($size_group =~ m/<label\s*for\=\"[^>]*?\"\s*class\=\"oos\">\s*([^>]*?)\s*(?:<[^>]*?>[^>]*?)*?<\/label>/igs)
			{
				$size = $utilityobject->Trim($1);
				$out_of_stock = 'y'; # Out of stock.
				
				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);
			}
		}
		elsif($color_content =~ m/<li\s*class\=\"size\s*dropdown\">\s*([\w\W]*?)\s*<\/li>/is) # Pattern match of size - type 2.
		{
			my $size_group = $1;
			
			while($size_group =~ m/<option\s*value\=\"[^>]*?\"\s*data\-max\=\"[^>]*?\"\s*>\s*([^>]*?)\s+(?:\-\s*([^>]*?)\s*)?(?:\-\s*([^>]*?)\s*)?<\/option>/igs)
			{
				$size = $utilityobject->Trim($1);
				my $price = $2; # Current price (available in the drop down for each size).
				my $stock = $3;
				
				$current_price = $1 if($price=~m/Now\s*\&\#163\;\s*([^>]*?)\s*$/is);
				$current_price = $1 if($price=~m/^\&\#163\;\s*([^>]*?)\s*$/is);

				$out_of_stock = 'n'; # In stock.
				$out_of_stock = 'y' if($stock ne ''); # Out of stock.
				
				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);
			}
		}
		else # Entry when size is not available in product page.
		{
			$size = 'one size';
			$out_of_stock = 'n';
			
			# Saving sku details.
			$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_colour,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);
		}		
		
		my $image_count = 1;
		
		# Pattern match of product images.
		while($color_content =~ m/smallimage\:\s*\'([^>]*?)\'/igs)
		{
			my $image_url = 'http:'.$1;
			
			# Saving default image.
			if($image_count == 1)
			{				
				my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
				$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_code,'y') if(defined $img_file);
			}
			else # Saving alternate image.
			{
				my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
				$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_code,'n') if(defined $img_file);
			}
			$image_count++;
		}
	}
	undef %hash_color;
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