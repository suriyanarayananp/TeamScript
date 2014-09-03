#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Asos_UK;
use strict;

sub Asos_UK_DetailProcess()
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
	my $Retailer_Random_String='Auk';
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
	goto PNF if($source_page =~ m/<div\s*class\=\"outofstock\">\s*Out\s*Of\s*Stock\s*<\/div>/is);
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$price_text);	
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/productcode\"\s*>\s*([^>]*?)\s*</is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
	}
	
	# Pattern match of product name.
	if($source_page =~ m/title\"\s*content\=\"([^\"]*?)\"/is)
	{
		$product_name = $1;
	}
	$product_name =~ s/at\s*asos\.com//igs;
	$product_name =~ s/\sat$//igs;
	$product_name =~ s/\"//igs;
	
	# Pattern match of brand name.
	if($source_page =~ m/\"ProductBrand\"\:\"([^>]*?)\"/is) # External brand.
	{
		$brand = $utilityobject->Trim($1);
		$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
	}
	elsif($product_name ne '')
	{
		$brand = 'Asos'; # Own brand.
	}
	
	# Pattern match of product description.
	if($source_page =~ m/class\=\"product-description\"\s*[^>]*?>\s*([\w\W]*?)\s*<\/div>/is)
	{
		$product_description = $utilityobject->Trim($1);		
	}
	
	# Pattern match of product detail.
	if($source_page =~ m/id\=\"infoAndCare\"[^>]*?\s*>\s*([\w\W]*?)\s*<span[^>]*?class\=\"productcode\">/is)
	{
		$product_detail = $1;
		$product_detail =~ s/Product\s*Code\://ig;
		$product_detail =~ s/ABOUT\s*ME//ig;
		$product_detail = $utilityobject->Trim($product_detail);		
	}
	
	# Pattern match of price text.
	if($source_page =~ m/<div[^>]*?class\=\"product_price\"[^>]*?>\s*([\w\W]*?\s*<span[^>]*?product_price_details\s*[^>]*?\s*>[\w\W]*?)\s*<\/div>/is)
	{		
		$price_text = $1;
		if($price_text !~ m/>RRP/is)
		{
			$price_text = $utilityobject->Trim($price_text);
			$price_text =~ s/\&\#163\;/\Â\£/igs;
		}
		else
		{
			$price_text = '';
		}
	}
	
	# Pattern match of size, color, current price and out of stock.
	while($source_page =~ m/\(\d+\,\"([^>]*?)\"\,\"([^\"]*?)\"\,\"(true|false)\"\,\"([^\,]*?)\"\,\"([^\"]*?)\"/igs)
	{
		my $size = $utilityobject->Trim($1); # Size.
		my $raw_color = $utilityobject->Trim($2); # Raw color.
		my $stock = $3; # Stock result - true/false.
		$size = $size.$4;
		my $current_price = $5; # Current price.
		$price_text = 'Â£'.$current_price if($price_text eq '');
		
		my $out_of_stock = 'n'; # In stock.
		$out_of_stock = 'y' if($stock=~m/false/is); # Out of stock - when stock result is false.
		$size =~ s/\\//ig;
		$size =~ s/\"//ig;

		# Saving sku details.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$retailer_product_reference);		
	}

	# Pattern match of default product images.
	while($source_page =~ m/name\=\"og\:image\"\s*content\=\"([^\"]*?)\"/igs)
	{
		my $image_url = $1;
		$image_url =~ s/(image\d+)s/$1xl/igs;
		
		my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
		$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$retailer_product_reference,'y') if(defined $img_file);
	}
	
	# Pattern match of alternate product images.
	while($source_page =~ m/arrThumbImage\[\d+\]\s*=\s*new\s*Array\(\"([^\"]*?)\"/igs)
	{
		my $image_url = $1;
		$image_url =~ s/(image\d+)s/$1xl/igs;
		
		my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
		$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$retailer_product_reference,'n') if(defined $img_file);
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