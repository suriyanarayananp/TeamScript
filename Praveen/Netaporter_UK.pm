#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Netaporter_UK;
use strict;

sub Netaporter_UK_DetailProcess()
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
	my $Retailer_Random_String='Nuk';
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
	goto PNF if($source_page =~ m/What\s*to\s*buy\s*now/is);		
	goto PNF if($source_page =~ m/<div\s*class\=\"message\">\s*Unfortunately\,\s*this\s*product\s*is\s*no\s*longer\s*available\s*\.\s*<\/div>/is);
	goto PNF if($source_page =~ m/Unfortunately\s*this\s*item\s*is\s*sold\s*out/is);
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);	
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/productID\s*\=\s*\"?\s*(\d+)\s*(?:\;|\,|\")/is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
	}
	
	# Pattern match of product name.
	if($source_page =~ m/title\:\s*\"([^\"]*?)\"/is)
	{
		$product_name = $1;
	}
	
	# Brand name - only external brand available.
	if($source_page =~ m/category\:\s*\"([^\"]*?)\"/is)
	{
		$brand = $1;
		$dbobject->SaveTag('Designer',$brand,$product_object_key,$robotname,$Retailer_Random_String);
	}
	
	# Pattern match of product description.
	if($source_page =~ m/<div\s*class\=\'tabBody1\s*tabContent\'>\s*<p><span\s*class\=\"en\-desc\">\s*([\w\W]*?)\s*<\/p>/is)
	{
		$product_description = $utilityobject->Trim($1);			
	}
	
	# Pattern match of product detail.
	if($source_page =~ m/>\s*Size\s*\&\s*fit\s*<\/a>\s*([\w\W]*?)\s*<\/ul>\s*<\/span>/is)
	{
		$product_detail = $utilityobject->Trim($1);
	}
	if($source_page =~ m/<div\s*class\=\'tabBody2\s*tabContent\'[^>]*?>\s*<p>\s*<span\s*class\=\"en\-desc\">\s*([\w\W]*?)\s*<\/span>/is)
	{
		$product_detail = $product_detail.' '.$utilityobject->Trim($1);
	}		
	
	# Pattern match of price text and current price (4 types).
	if($source_page =~ m/<span\s*itemprop\=\"price\"\s*>\s*([^>]*?)\s*<\/span>/is)
	{
		$price_text = $1;
		$current_price = $price_text;
	}
	elsif($source_page =~ m/<span[^>]*?class\=\"was\"\s*>\s*([^<]*?)\s*<\/span>\s*<span[^>]*?class\=\"now\"\s*>\s*([^<]*?)\s*<\/span>\s*<span[^>]*?class\=\"percentage\"\s*>\s*([^>]*?)\s*<\/span>/is)
	{
		$price_text = $1.' '.$2.' '.$3;
		$current_price = $2;
		$current_price =~ s/^Now\s*//igs;
	}
	elsif($source_page =~ m/<span\s*class\=\"was\"\s*>\s*([^<]*?)\s*<\/span>\s*<span\s*class\=\"now\"\s*>\s*([^<]*?)\s*<\/span>/is)
	{
		$price_text = $1." ".$2;
		$current_price = $2;
	}
	elsif($source_page =~ m/<div\s*id\=\"price\"\s*>\s*([^<]*?)\s*<\/div>/is)
	{
		$price_text = $1;
		$current_price = $price_text;
	}
	$price_text =~ s/\&pound\;/\Â\£/igs;
	$current_price =~ s/\&pound\;//igs;
	$current_price =~ s/\,//igs;	
	$current_price =~ s/\&nbsp\;//igs;
	$current_price = $utilityobject->Trim($current_price);
	$price_text = $utilityobject->Trim($price_text);	
	
	# Raw colour extraction - (only 1 colour in each product page).
	my $raw_color;
	if($source_page =~ m/value\=\"([^\"]*?)\"\s*name\=\"pr_color\"\s*id\=\"pr_color\"\/>/is)
	{
		$raw_color = $1;
	}
	
	my $own_flag = 0;
	# Pattern match of size - Pattern 1 (contains out stock).
	while($source_page =~ m/<option\s*data\-size\=\"([^\"]*?)\"\s*data\-stock\=\"([^\"]*?)\"/igs)
	{
		my $size = $1; # Size.
		my $stock = $2;
		my $out_of_stock = 'n'; # In stock.
		$out_of_stock = 'y' if($stock =~ m/out/is); # Out of stock.
		$size = $1 if($size =~ m/^([^>]*?)\s*\-[^>]*?$/is);
		$own_flag = 1;
		
		# Saving sku details.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$raw_color);		
	}
	
	# Pattern match of size - Pattern 2 (contains in, low stock).
	while($source_page =~ m/<option\s*data\-stock\=\"([^\"]*?)\"\s*data\-size\=\"([^\"]*?)\"/igs)
	{
		my $stock = $1;
		my $size = $2; # Size.		
		my $out_of_stock = 'n'; # In stock.
		$out_of_stock = 'y' if($stock =~ m/out/is); # Out of stock.
		$size = $1 if($size =~ m/^([^>]*?)\s*\-[^>]*?$/is);
		$own_flag = 1;
		
		# Saving sku details.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$raw_color);		
	}
	
	# saving one size products.
	if($own_flag == 0)
	{
		my $size = 'one size';
		my $out_of_stock = 'n';			
		
		# Saving sku details.
		$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$raw_color);
	}

	# Pattern match of product images.
	my $image_count = 1;
	while($source_page =~ m/<meta\s*property\=\"og\:image\"\s*content\=\"([^>]*?)\"\s*\/>\s*<img/igs)
	{
		my $image_url = $1;
		
		if($image_count == 1) # Deploying default image details into image table.
		{			
			my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
			$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'y') if(defined $img_file);
		}
		else # Deploying alternate image details into image table.
		{
			my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
			$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'n') if(defined $img_file);
		}
		$image_count++;
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