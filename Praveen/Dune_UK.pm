#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Dune_UK;
use strict;

sub Dune_UK_DetailProcess()
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
	my $Retailer_Random_String='Duk';
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
	goto PNF if($source_page !~ m/200/is);
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);	
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/sku\'\:\s*\'([^\']*?)\'/is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
	}
	
	# Pattern match of product name.
	if($source_page =~ m/prodName1\">([^<]*?)</is)
	{
		$product_name = $1;
	}
	if($source_page =~ m/prodName2\">([^<]*?)<\/span>\s*<\/h1>/is)
	{
		$product_name = $product_name.' '.$1;
	}
	$utilityobject->Trim($product_name);
	
	# Brand name - only external brand available.
	if($source_page =~ m/brand\'\:\s*\'([^\']*?)\'/is)
	{
		$brand = $1;
		$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
	}
	
	# Pattern match of product description.
	if($source_page =~ m/description\'\:\s*\'([^\']*?)\'/is)
	{
		$product_description = $utilityobject->Trim($1);			
	}
	
	# Pattern match of product detail.
	if($source_page =~ m/product\s*information\s*([\w\W]*?)\s*<\/div>\s*<\/div>\s*<\/div>/is)
	{
		$product_detail = $utilityobject->Trim($1);
	}
	if($source_page =~ m/product\s*care\s*([\w\W]*?)\s*<\/div>/is)
	{
		$product_detail = $product_detail.' '.$utilityobject->Trim($1);
	}
	
	# Pattern match of current price and price text.
	if($source_page =~ m/unit_price\'\:\s*([^\,]*?)\,/is)
	{
		$current_price = $1;		
	}
	
	if($source_page =~ m/sale_price\'\:\s*([^\,]*?)\,/is)
	{
		my $price = $1;
		if($price =~ m/\'\'/is)
		{
			$price_text = '£'.$current_price;
		}
		else
		{
			$price_text = '£'.$price.' '.'£'.$current_price;
			$current_price = $price;
		}
	}	
	
	# Raw colour extraction.
	my $raw_color;
	if($source_page =~ m/colour\'\:\s*\'([^>]*?)\-/is)
	{
		$raw_color = $1;
	}
	elsif($source_page =~ m/colour\'\:\s*\'([^\']*?)\'/is)
	{
		$raw_color = $1;
	}
		
	# Pattern match of size - Pattern 1 (contains out stock).
	if($source_page =~ m/size\'\:\s*\[\s*([^\]]*?)\]/is)
	{
		my $size_block = $1;
		my %hash_size;
		while($size_block =~ m/size\'\s*\:\s*\'([^\']*?)\'\,\s*\'stock\'\s*\:\s*\'([^\']*?)\'/igs)
		{
			my $size = $1; # Size.
			my $stock = $2;
			my $out_of_stock = 'n'; # In stock.
			$out_of_stock = 'y' if($stock =~ m/out/is); # Out of stock.			
			
			$size =~ s/^([^>]*?)\/US[\d\.]*?$/$1/igs;
			if($hash_size{$size} eq '')
			{
				$hash_size{$size} = $size;
				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$raw_color);		
			}
		}
	}

	# Pattern match of product images and swatch image.
	my $image_count = 1;
	if($source_page =~ m/class\=\"pdimage\">\s*<img\s*src\=\"([^\?]*?)\?/is)
	{
		my $image_url = $1;		
		
		# Deploying default image.
		my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
		$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'y') if(defined $img_file);
		
		# Deploying swatch image.
		my $swatch_url = $image_url;
		$swatch_url =~ s/MAIN/SWATCH/igs;
		my $img_file = $imagesobject->download($swatch_url,'swatch',$retailer_name,$ua);
		$dbobject->SaveImage($swatch_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$raw_color,'n') if(defined $img_file);
		
		# Deploying alternate image.
		$image_url =~ s/MAIN/ALT/igs;
		in:
		my $alternate_image_url = $image_url.$image_count;
		my $image_code = $utilityobject->GetCode($alternate_image_url);
		goto out if($image_code != 200);
		my $img_file = $imagesobject->download($alternate_image_url,'product',$retailer_name,$ua);
		$dbobject->SaveImage($alternate_image_url,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'n') if(defined $img_file);
		$image_count++;
		goto in if($image_code == 200);
	}
	out:
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