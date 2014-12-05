#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
package Topshop_US;
use strict;

sub Topshop_US_DetailProcess()
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
	my $Retailer_Random_String='Tus';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);
	
	# Setting the Environment.
	$utilityobject->SetEnv($ProxyConfig);
	
	# Return to calling script if product object key is not available.
	return if($product_object_key eq ''); 
	
	# Appending home url if url doesn't start with "http".
	$url='http://us.topshop.com/en/tsus/product/'.$url unless($url=~m/^\s*http\:/is);
	
	# Getting the page content.
	my $content2 = $utilityobject->Lwp_Get($url);
	
	if($content2 =~ m/type\s*\=\s*\"\s*hidden\s*\"\s*name\s*\=\s*\"\s*searchTerm\s*\"\s*value|We\s*could\s*not\s*find\s*any\s*matches|<p\s*id\=\"item_out_of_stock\">/is)
	{
		$content2 = $utilityobject->Lwp_Get($url);
	}
		
	# Pattern match to check whether product page is multiple product page if yes flag value becomes 1.	
	if($content2=~m/<body[^>]*?id\s*\=\s*\"\s*cmd_bundledisplay\s*\"[^>]*?>/is)
	{
		$mflag=1;
	}
	
	# Declaring all required variables.
	my ($price,$price_text,$brand,$product_id,$product_name,$description,$prod_detail,$out_of_stock,$color,$staus);
	
	
	# Pattern match to check whether multiple flag is true.
	if($mflag)
	{
		# Pattern match to get the product id of multiple product item.
		if($content2 =~ m/product_view\s*\"[^>]*?>\s*(?:\s*<[^>]*?>\s*)*<a[^>]*?href\s*\=\s*(?:\"|\')[^\"\']*?\/\s*catalog\s*\/([^\"\']*?\d{1,2})[^\"\']*?(?:\"|\')/is)
		{
			$product_id = $utilityobject->Trim($1);
		}
		
		# Pattern match to get product name.
		if ( $content2 =~ m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is )
		{
			$product_name = $utilityobject->Trim($1);
			# Pattern match to get the "Brand" from product name.
			if($product_name=~m/\s+BY\s+([^<]*)$/is)
			{
				$brand=$1;
				$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
			}
		}
		# Pattern match to get description for the multiple product.
		if ($content2 =~ m/(?:class|id)\s*\=\s*\"(?:product|bundle)_description\"[^>]*?>\s*([\w\W]*?)\s*<\/p/is) 
		{
			$description = $utilityobject->Trim($1);
			$prod_detail = $utilityobject->Trim($2);
			$description='MULTI-ITEM PRODUCT:'."$description";
		}
		# Pattern match to get the image url of the multiple product.
		if ($content2 =~ m/product_view\s*\"[^>]*?>\s*(?:\s*<[^>]*?>\s*)*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)(?:\"|\')/is)
		{
			my $imageurl_mul = $1;
			
			# Downloading and save entry for product images
			my $img_file = $imagesobject->download($imageurl_mul,'product',$retailer_name,$ua);
			
			# Save entry to image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($imageurl_mul,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
		}	
		goto PNF;			
	}
	elsif ( $content2 =~ m/<li[^>]*?class\s*\=\s*\"\s*product_code\s*\"[^>]*?>\s*Item\s*code\s*\:[^>]*?<span[^>]*?>([^<]*?)</is ) # Pattern match to get the product id.
	{
		$product_id = $utilityobject->Trim($1);
		
		# Call UpdateProducthasTag to update tag information of the new product if product id already exists.
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key, $robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	
	# Pattern match to get product price text & price(Scenario 1).
	if ( $content2 =~ m/<li[^>]*?class\=\s*\"product_price\"[^>]*?>\s*Price\s*\:\s*[^>]*<[^>]*?>\s*([^<]*?)\s*</is )
	{
		# Encode the Pricetext using country code.
		$price_text = $utilityobject->PriceFormat($1, $ccode);
		#$price_text=~s/Now/, Now/igs;	
		
		if ($price_text =~ m/([\d\.]+)/is )
		{
			$price = $1;
		}
	}
	if($price_text eq "") # Pattern match to get product price text & price(Scenario 2).
	{
		if ( $content2 =~ m/\->\s*<li[^<]*?class\=\s*\"[^<]*product_price\"\s*>\s*([\w\W]*?)\s*<li\s*class=\"product_colour\"/is )
		{
			my $Pricecont = $1;
			# Encode the Pricetext using country code.
			$price_text = $utilityobject->PriceFormat($Pricecont, $ccode);
			#$price_text=~s/Now/, Now/igs;
			
			if ($price_text =~ m/Now[^<]*?([\d\.]+)/is )
			{
				$price = $1;
			}
		}
	}
	
	# Pattern match to get product_name.
	if ( $content2 =~ m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is )
	{
		$product_name = $utilityobject->Trim($1);
		#Brand
		if($product_name=~m/\s+BY\s+([^<]*)$/is)
		{
			$brand=$1;
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	# Pattern match to get product description & product detail.
	##if ( $content2 =~ m/class\=\"product_description\">([\w\W]*?)<div\s*class\s*\=\s*\"content_spot\s*\"/is ) 
	if ( $content2 =~ m/class\=\"product_description\">\s*([\w\W]*?)\s*<\/div>/is ) 
	{
		$description = $utilityobject->Trim($1);
		#$prod_detail = $utilityobject->Trim($2);
	}
	
	# Pattern match to get color.
	if ( $content2 =~ m/<li\s*class\=\"product_colo(?:u)?r\"\s*>\s*Colo(?:u)?r\s*\:\s*[^>]*?<span>([\w\W]*?)</is )
	{
		$color = $utilityobject->Trim($1);
	}
	# Pattern match to get size & out of stock block.
	if ( $content2 =~ m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is )
	{
		my $size_content = $1;
		my %size_hash;
		
		# Looping through to get size & "out of stock" values of instock products first to remove Duplicates in size.
		while($size_content=~m/<option\s*value\=(?:\"|\')[^\"\']*?(?:\"|\')\s*title\=(?:\"|\')([^\"\']*?)(?:\"|\')(?:\s*class\=\"[^\"]*?\")?>\s*([^<]*?)\s*<\/option>/igs)
		{
			my $size 			= $utilityobject->Trim($2);
			my $out_of_stock 	= $utilityobject->Trim($1);
			$out_of_stock=~s/\s*In\s*stock\s*$/n/ig;
			$out_of_stock=~s/\s*Low\s*stock\s*$/n/ig;
			$size_hash{$out_of_stock}=$size;
			
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
			$size_hash{$size}=1; # Creating hash to remove Duplicates.
		}
		# Looping through to get size & "out of stock" values of "Out of stock" products from block.(Given Priority to Instock Products if Duplication in size).
		while($size_content=~m/<option\s*disabled\s*\=\s*\"\s*disabled\s*\"\s*title\s*\=\s*(?:\"|\')\s*([^\"\']*?)(?:\"|\')\s*[^>]*?>\s*([^<]*?)\s*<\/option>/igs)
		{
			my $size 			= $utilityobject->Trim($2);
			my $out_of_stock 	= $utilityobject->Trim($1);
			$out_of_stock=~s/\s*Out\s*of\s*stock\s*$/y/ig;
			$out_of_stock=~s/^\s*$/y/igs;
			
			if($size_hash{$size} eq '') # Checking with hash to remove Duplicates in size.
			{
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
			}
		}
	}
	
	# Pattern match to take main image url.
	if ( $content2 =~ m/<meta[^<]*?property\s*\=\s*\"\s*og\s*\:\s*image\s*\"[^>]*?content\=\"([^<]*?)\"[^<]*?>/is )
	{
		my $imageurl_det = $utilityobject->Trim($1);	 # Actual image url. 	
		my $imageurl_up = (split('_',$imageurl_det))[0]; # Taking url before "_" to take needed part from main image url to make image size huge and to form alternate image url.
		my $imageurl = $imageurl_up."_large.jpg";        # Forming image url from the url taken to make the difference in image size. 
		my $image_Domain_url="http://media.topshop.com/";# Image home url.
		$staus=$utilityobject->GetCode($imageurl);            # Get the status of the Image url. 
		
		if($staus!~m/20/is) # Pattern match to check whether the image page is a error page.
		{
			$imageurl = $imageurl_det;  # Assigning actual image url to image url if image url that was formed is error.
			
			# Appending image home url if url taken doesn't start with "http".
			$imageurl=$image_Domain_url.$imageurl unless($imageurl=~m/^\s*http\:/is);
		}
		
		
		# Downloading and save entry for product images		
		my $img_file = $imagesobject->download($imageurl,'product',$retailer_name,$ua);
		
		# Save entry to image table ,if image download is successful. Otherwise throw error in log.
		$dbobject->SaveImage($imageurl,$img_file,'product',$Retailer_Random_String,$robotname,$color,'y') if(defined $img_file);
						
		foreach my $count ( 2 .. 6 ) 
		{
			my $imageurl1 = $imageurl_up."\_$count\_large.jpg"; # Formation of alternate image urls with respect to count value.
			
			$staus=$utilityobject->GetCode($imageurl1);           # Get the status of the Image url. 
			
			# Pattern match to check whether image page is a error page.
			if($staus!~m/20/is) 
			{
				$imageurl1 = $imageurl_up."\_$count\_normal.jpg";                            # Formation of Image url if Image url ending with "_large" having page error in alternate images (leads to downloading Issue in Parent Directory).
				$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is); # Appending image home url if image url doesn't start with "http".
				$staus=$utilityobject->GetCode($imageurl1); # Get the status of the Image url. 
			}
			
			if($staus == 200)
			{
				# Downloading and save entry for product images
				my $img_file = $imagesobject->download($imageurl1,'product',$retailer_name,$ua);
				
				# Save entry to image table ,if image download is successful. Otherwise throw error in log.
				$dbobject->SaveImage($imageurl1,$img_file,'product',$Retailer_Random_String,$robotname,$color,'n') if(defined $img_file);
			}
		}
	}
		
	# Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);
		
	PNF:
	
	# Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url,$retailer_id,$mflag);
	
	# Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);
	
	ENDOFF:
	
	# Committing transaction and undefine the query array
	$dbobject->commit();
	$dbobject->Destroy();	
		
	$price=$price_text=$brand=$product_id=$product_name=$description=$prod_detail=$out_of_stock=$color=$staus=$url=undef;	
	
}1;

