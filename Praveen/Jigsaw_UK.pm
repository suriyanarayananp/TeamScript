#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl

# Required modules are initialized.
package Jigsaw_UK;
use strict;

sub Jigsaw_UK_DetailProcess()
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
	my $Retailer_Random_String='Jig';
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
			
	$url='http://www.jigsaw.com'.$url unless($url=~m/^\s*http\:/is);
	my $source_page=$utilityobject->Lwp_Get($url);	
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);	
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/id\=\"product_code\">\s*([^>]*?)<\/p>/is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
		$retailer_product_reference =~ s/\s*Item\s*number\s*//igs;			
	}
	
	# Pattern match of product name.
	if($source_page =~ m/<h1\s*id\=\"product_title\">([^>]*?)<\/h1>/is)
	{
		$product_name = $utilityobject->Trim($1);
	}
	
	# Brand name - all the products in the retailer website belongs to own (Jigsaw) brand (no external brands are available).
	$brand = 'Jigsaw';
	
	# Pattern match of product description.
	if($source_page =~ m/<dd\s*class\=\"description\s*open\s*information_cont\">\s*([^>]*?)<\/dd>/is)
	{
		$product_description = $utilityobject->Trim($1);
	}
	
	# Pattern match of product detail.
	while($source_page =~ m/<dd\s*class\=\"([^>]*?)\s*information_cont\">\s*<ul\s*class\=\"info_list\">\s*([\w\W]*?)\s*<\/ul>/igs)
	{
		$product_detail = $product_detail.' '.$utilityobject->Trim($1).' '.$utilityobject->Trim($2);
	}
	$product_detail =~ s/^\s*|\s*$//igs;	
	
	while($source_page =~ m/<a\s*href\=\"([^\"]*?)\"\s*class\=\"product_link\">\s*<img\s*src\=\"([^>]*?)\"\s*alt\=\"([^>]*?)\&nbsp\;swatch\"\s*\/>/igs)
	{
		my $color_url = $utilityobject->Trim($1); # Colour url.
		my $swatch_image_url = $2; # Swatch image url.
		my $raw_color = $utilityobject->Trim($3); # Raw colour.
		
		# Saving swatch image.
		$swatch_image_url = 'http://www.jigsaw-online.com'.$swatch_image_url unless($swatch_image_url =~ m/^\s*http\:/is);
		my $img_file = $imagesobject->download($swatch_image_url,'swatch',$retailer_name,$ua);
		$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$raw_color,'n') if(defined $img_file);
		
		$color_url = 'http://www.jigsaw-online.com'.$color_url;
		my $color_page = $utilityobject->Lwp_Get($color_url);

		# Price text & current price extraction for each colours in the product page (four types).
		if($color_page =~ m/<p\s*class\=\"product_price[\w\W]*?<span>\s*\&pound\;([^>]*?)<\/span>/is)
		{
			$current_price = $utilityobject->Trim($1);
			$price_text = '£'.$current_price;
		}
		elsif($color_page =~ m/class\=\"product_price[\w\W]*?class\=\"wasPrice\">\s*\&pound\;\s*([^>]*?)<\/span>[\w\W]*?class\=\"nowPrice\">\s*\&pound\;\s*([^>]*?)<\/span>/is)
		{
			my $max = $1;
			my $min = $2;
			$current_price = $utilityobject->Trim($min) if($max>$min);
			$current_price = $utilityobject->Trim($max) if($max<$min);					
			$price_text = '£'.$max.' '.'£'.$min;
		}
		elsif($color_page =~ m/<p\s*class\=\"product_price\s*\">\s*<span\s*class\=\"fromPrice\">\&pound\;([^>]*?)\s*<\/span>\s*(\-)\s*<span\s*class\=\"toPrice\">\&pound\;([^>]*?)\s*<\/span>/is)
		{
			$price_text = '£'.$1.' '.$2.' '.'£'.$3;
			my $max = $1;
			my $min = $3;
			$current_price = $utilityobject->Trim($min) if($max>$min);
			$current_price = $utilityobject->Trim($max) if($max<$min);
		}
		elsif($color_page =~ m/<p\s*class\=\"product_price[^>]*?\">[\w\W]*?<span\s*class\=\"nowPrice\">\s*\&pound\;\s*([^>]*?)<\/span><\/p>/is)
		{
			$current_price = $utilityobject->Trim($1);
			$price_text = '£'.$current_price;
		}
		$price_text  = $utilityobject->PriceFormat($price_text, $ccode);
		
		# Size extraction.
		if($color_page =~ m/<div\s*id\=\"select_size\"\s*class\=\"element\">\s*([\w\W]*?)\s*<\/ul>/is)
		{
			my $size_block = $1;
			while($size_block =~ m/<li\s*class\=\"([^>]*?)\"[^>]*?>\s*<label\s*for\=\"sku_[^>]*?\">\s*([^>]*?)\s*<\/label>/igs)
			{
				my $stock = $utilityobject->Trim($1);
				my $size = $utilityobject->Trim($2); # Size.
				
				my $out_of_stock = 'y'; # Out of stock.
				$out_of_stock = 'n' if($stock =~ m/in_stock/is); # In stock.

				# Saving sku details.
				$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$raw_color);					
			}
		}
		
		# Pattern match of product image.
		if($color_page =~ m/id\=\"enlarge_button\"\s*data\-image\=\"([^>]*?)\"/is)
		{
			my $default_image = $1; # Deploying default image details into image table.
			
			my $img_file = $imagesobject->download($default_image,'product',$retailer_name,$ua);
			$dbobject->SaveImage($default_image,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'y') if(defined $img_file);
			
			# Deploying alternate image details into image table.
			my $count = 2;
			if($default_image =~ m/^([^>]*?_)1/is)
			{
				my $image_contruct = $1;
				
				altImage:
				my $alternate_image = $image_contruct.$count.'.jpg';						
				my $image_code = $utilityobject->GetCode($alternate_image);
				goto nextColor if($image_code != 200);
				
				my $img_file = $imagesobject->download($alternate_image,'product',$retailer_name,$ua);
				$dbobject->SaveImage($alternate_image,$img_file,'product',$Retailer_Random_String,$robotname,$raw_color,'n') if(defined $img_file);
			
				$count++;
				goto altImage;
			}
		}
		nextColor:
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