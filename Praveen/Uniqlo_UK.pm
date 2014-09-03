#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Required modules are initialized.
package Uniqlo_UK;
use strict;

sub Uniqlo_UK_DetailProcess()
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
	my $Retailer_Random_String='Uni';
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
	
	# Required variables are declared globally.
	my ($product_name,$product_description,$retailer_product_reference,$brand,$product_detail,$current_price,$price_text);
	
	# Pattern match of retailer product reference.
	if($source_page =~ m/ITEM\s*CODE\s*\:\s*(?<Product_ID>[^>]*?)\s*</is)
	{
		$retailer_product_reference = $utilityobject->Trim($1);
		
		# Verification on product table, whether retailer product reference was already exist. if exist duplicate product will be removed from the product table and further scrapping will be skipped.
		my $ckproduct_id = $dbobject->UpdateProducthasTag($retailer_product_reference, $product_object_key, $robotname, $retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}	

	# Pattern match of product name.
	if($source_page =~ m/<h1[^>]*?>\s*(?<Product_name>[^>]*?)\s*<\/h1>/is)
	{
		$product_name = $utilityobject->Trim($1);		
	}
	
	# Brand name - all the products in the retailer website belongs to own (uniqlo) brand (no external brands are available).
	$brand = 'Uniqlo';
	
	# Pattern match of product description.
	if($source_page =~ m/<p\s*class\=\"about\">\s*(?<Product_Desc>[^>]*?(?:<[^>]*?>[^>]*?)*?)\s*<\/p>/is)
	{
		$product_description = $utilityobject->Trim($1);		
	}
	
	# Pattern match of product detail.
	if($source_page =~ m/<dl\s*class\=\"spec\s*clearfix\">\s*(?<Product_Detail>[\w\W]*?)\s*<\/dl>/is)
	{
		$product_detail = $utilityobject->Trim($1);		
	}
	
	# Pattern match of price text.
	my ($first_price,$sale_price);
	if($source_page =~ m/\"firstPrice\"\:\"\\u00a3(?<Price>[\d\.\,]*?)\"/is)
	{
		$first_price = $1;
		$price_text = 'Â£'.$first_price;
	}
	
	# Pattern match of current price.
	if($source_page =~ m/\"salesPrice\"\:\"\\u00a3(?<Price>[\d\.\,]*?)\"/is)
	{
		$sale_price = $1;
		
		if($first_price eq $sale_price)
		{
			$current_price = $first_price;
		}
		else
		{
			$current_price = $sale_price;
			$price_text = $price_text.' Â£'.$current_price;
		}
	}
	
	my ($color_id,$raw_color);
	if($source_page =~ m/\"colorInfoList\"\:\{(?<Color_Block>[^>]*?)\}/is)
	{
		my $colour_block = $1;
		my $inc = 2;
		my %hash_color;
		
		# Pattern match of raw colour and colour id.
		while($colour_block =~ m/\"(\d+)\"\:\"(?<Color_list>[^>]*?)\"/igs)
		{
			$color_id = $1; # Colour code.
			$raw_color = $utilityobject->Trim($2); # Raw colour.
			$raw_color = lc($raw_color);
			$raw_color =~ s/(\w+)/\u\L$1/g; # Makes first letter capital of each word.
			
			# Validating raw colour for duplicates - if duplicate found, incremental value i.e., '2' will be appended to the duplicate raw colour (example: white (2)).
			if($hash_color{$raw_color} eq '')
			{
				$hash_color{$raw_color} = $raw_color;
			}
			else
			{
				$raw_color=$raw_color.' ('.$inc.')';
				$inc++;
			}
			
			# Saving swatch image.
			my $swatch_image_url = 'http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/chip/'.$color_id.'_'.$retailer_product_reference.'.gif';			
			my $img_file = $imagesobject->download($swatch_image_url,'swatch',$retailer_name,$ua);
			$dbobject->SaveImage($swatch_image_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
			
			# Pattern match of size.
			if($source_page =~ m/\"sizeInfoList\"\:\{(?<Size_Block>[^>]*?)\}/is)
			{
				my $size_block = $1;
				
				# Extracts all sizes and it's corresponding size id from product page.
				while($size_block =~ m/\"(\d+)\"\:\"(?<Size_list>[^>]*?)\"/igs)
				{
					my $size_id = $1; # Size id.
					my $size = $utilityobject->Trim($2); # Size.
					my $out_of_stock = 'n'; # In stock.
					$out_of_stock = 'y' if($source_page =~ m/\"realStockCnt\"\:\"0\"\,\"sumStockCnt\"\:\"0\"\,\"lowStockFlg\"\:\"0\"\,\"colorCd\"\:\"$color_id\"\,\"sizeCd\"\:\"$size_id\"/is); # Out of stock.
					
					# Saving sku details.
					$dbobject->SaveSku($product_object_key,$url,$product_name,$current_price,$price_text,$size,$raw_color,$out_of_stock,$Retailer_Random_String,$robotname,$color_id);					
				}
			}
			
			# Saving default product image.
			my $image_url = 'http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/item/'.$color_id.'_'.$retailer_product_reference.'.jpg';
			my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);
			$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'y') if(defined $img_file);
		}
	}
	
	if($source_page =~ m/\"goodsSubImageList\"\:\"(?<sub_image_block>[^>]*?)\"\,/is)
	{
		my $image_block = $1;
		
		# Extracts all alternate image sub name from the product page.
		while($image_block =~ m/(?<sub_image>\d+_sub\d+)/igs)
		{
			my $alternate_image_url = $utilityobject->Trim($1);
			
			# Saving alternate product images.
			$alternate_image_url = 'http://im.uniqlo.com/images/uk/pc/goods/'.$retailer_product_reference.'/sub/'.$alternate_image_url.'.jpg';
			my $img_file = $imagesobject->download($alternate_image_url,'product',$retailer_name,$ua);
			$dbobject->SaveImage($alternate_image_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
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