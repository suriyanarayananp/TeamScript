#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization
package Topshop_UK;
use strict;

sub Topshop_UK_DetailProcess()
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
	my $Retailer_Random_String='Tuk';
	my $mflag = 0;
	
	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	
	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~ m/\-([^>]*?)$/is);
	
	# Setting the Environment
	$utilityobject->SetEnv($ProxyConfig);
	
	my $content = $utilityobject->Lwp_Get($url);

	if($content =~ m/type\s*\=\s*\"\s*hidden\s*\"\s*name\s*\=\s*\"\s*searchTerm\s*\"\s*value|We\s*could\s*not\s*find\s*any\s*matches/is)
	{
		$content = $utilityobject->Lwp_Get($url);
	}
	
	# Pattern match to check whether Product is a multiple Product.
	if($content=~m/<body\s*id\s*\=\s*\"\s*cmd_bundledisplay\s*\"\s*>/is)
	{
		$mflag=1;
	}
	
	#  Declaring variables.
	my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color);
	# Checking whether multiple product.
	if($mflag)
	{
		# Pattern match to get product id of multiple product.
		if($content =~ m/var\s*product\s*Data\s*\=\s*\{[^\}]*?code\s*\:\s*(?:\"|\')([^\,]*?)(?:\"|\')/is)
		{
			$product_id = $utilityobject->Trim($1);
		}
		
		# Pattern match to get product name.
		if ( $content =~ m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is )
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
		if ( $content =~ m/(?:class|id)\s*\=\s*\"(?:product|bundle)_description\">\s*([\w\W]*?)\s*<\/p>/is ) 
		{
			$description = $utilityobject->Trim($1);
			$description='MULTI-ITEM PRODUCT:'."$description"
		}
		
		# Pattern match to get the image url of the multiple product.
		if ( $content =~ m/product_view\s*\"\s*>\s*(?:\s*<[^>]*?>\s*)*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*?)(?:\"|\')/is )
		{
			my $imageurl_mul = $1;
			
			# Downloading and saving product images in the Directory.
			my $img_file = $imagesobject->download($imageurl_mul,'product',$retailer_name,$ua);
		
			# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
			$dbobject->SaveImage($imageurl_mul,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
		}
		goto PNF;	
	}
	elsif ( $content =~ m/<li[^>]*?class\s*\=\s*\"\s*product_code\s*\"[^>]*?>\s*Item\s*code\s*\:[^>]*?<span[^>]*?>([^<]*?)</is )# Pattern match to get product id of single product.
	{
		$product_id = $utilityobject->Trim($1);
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id,$product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	
	# Pattern match to get price text.
	if($content =~ m/prices\s*\:\s*\{([\w\W]*?)\}/is) # Getting price if Multiple Product.
	{
		$price_text  = $1;
		# $price_text  = $utilityobject->PriceFormat($Pricecont, $ccode);
		$price_text  =~ s/now//igs if($price_text !~ m/was/is);
		$price_text  =~ s/\:|\"//igs;
		$price_text=~s/\&pound\;/\Â\£/igs;
	}
	
	# Pattern match to get price.
	if($content=~m/prices\:\s*\{\s*now\:\s*\"([^>]*?)\"/is)
	{
		$price = $1;
		$price =~ s/\&pound\;//igs;
	}
	
	# Pattern match to get product name.
	if ( $content =~ m/<h1[^>]*?>\s*([^<]*?)\s*<\/h1>/is )
	{
		$product_name = $utilityobject->Trim($1);
		# Pattern match to get the "Brand" from product name.
		if($product_name=~m/\s+BY\s+([^<]*)$/is)
		{
			$brand=$1;
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	# Pattern match to get Product description & detail.
	if ( $content =~ m/class\=\"product_description\">([\w\W]*?)<div\s*class\s*\=\s*\"content_spot\s*\"/is )
	{
		$description = $utilityobject->Trim($1);
	}
	
	# Pattern match to get Product Color.
	if ( $content =~ m/<li\s*class\=\"product_colour\"\s*>\s*Colour\s*\:\s*[^>]*?<[^<]*?>([^<]*?)</is )
	{
		$color = $utilityobject->Trim($1);
	}
	
	# Pattern match to get block for size & out of stock.
	if($content=~m/<option>\s*Select\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
	{
		my $size_content = $1;
		my %size_hash;
		# Pattern match to take Instock Products First to remove Duplication in size. 
		while($size_content=~m/<option\s*value\=(?:\"|\')[^\"\']*?(?:\"|\')\s*title\=(?:\"|\')([^\"\']*?)(?:\"|\')(?:\s*class\=\"[^\"]*?\")?>\s*([^<]*?)\s*<\/option>/igs)
		
		{
			my $size 			= $utilityobject->Trim($2);
			my $out_of_stock 	= $utilityobject->Trim($1);
			$out_of_stock=~s/\s*In\s*stock\s*$/n/ig;
			$out_of_stock=~s/\s*Low\s*stock\s*$/n/ig;
			$size_hash{$out_of_stock}=$size;
			
			$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
			$size_hash{$size}=1;   # Creating hash to remove Duplicates.
		}
		# Pattern Match to get Out of stock products from block.(Given Priority to Instock Products if Duplication in size).
		while($size_content=~m/<option\s*disabled\s*\=\s*\"\s*disabled\s*\"\s*title\s*\=\s*(?:\"|\')\s*([^\"\']*?)(?:\"|\')\s*[^>]*?>\s*([^<]*?)\s*<\/option>/igs)
		{
			my $size 			= $utilityobject->Trim($2);
			my $out_of_stock 	= $utilityobject->Trim($1);
			$out_of_stock=~s/\s*Out\s*of\s*stock\s*$/y/ig;
			$out_of_stock=~s/^\s*$/y/igs;
			
			if($size_hash{$size} eq '')  # Checking with hash to remove Duplicates.
			{
				$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color);
			}
		}
	}
	
	# Pattern match to take Main Image URL.
	if ( $content =~ m/<meta[^<]*?property\s*\=\s*\"\s*og\s*\:\s*image\s*\"[^>]*?content\=\"([^<]*?)\"[^<]*?>/is )
	{
		my $imageurl_det = $utilityobject->Trim($1);
		my $imageurl_up = (split('_',$imageurl_det))[0];
		my $imageurl = $imageurl_up."_large.jpg";
		
		my $image_Domain_url="http://media.topshop.com/";
		my $status=$utilityobject->GetCode($imageurl);
		
		if($status!~m/20/is) # Formation of Image URL if Image URL ending with "_large" having page error (leads to Image downloading Issue in Parent Directory).
		{
			$imageurl = $imageurl_det;
			
			# Adding home url if image url doesn't start with "http".
			$imageurl=$image_Domain_url.$imageurl unless($imageurl=~m/^\s*http\:/is);
		}
		
		# Downloading and saving product images  in the directory.
		my $img_file = $imagesobject->download($imageurl,'product',$retailer_name,$ua);
		
		# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
		$dbobject->SaveImage($imageurl,$img_file,'product',$Retailer_Random_String,$robotname,$color,'y') if(defined $img_file);
						
		# Formation of Alternate Image URLs from Main image URL.				
		foreach my $count ( 2 .. 5 )
		{
			my $imageurl1 = $imageurl_up."\_$count\_large.jpg";
			my $status=$utilityobject->GetCode($imageurl1);  
			
			if($status!~m/20/is) # Formation of Image url if Image url ending with "_large" having page error (leads to Image downloading Issue in Parent Directory).
			{
				$imageurl1 = $imageurl_up."\_$count\_normal.jpg";
				
				# Adding home url if image url doesn't start with "http".
				$imageurl1=$image_Domain_url.$imageurl1 unless($imageurl1=~m/^\s*http\:/is);
			}
			my $status=$utilityobject->GetCode($imageurl1);
			
			if($status == 200)
			{
				# Downloading and saving product alternate images in the directory.
				my $img_file = $imagesobject->download($imageurl1,'product',$retailer_name,$ua);
		
				# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
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

	$content=$price=$price_text=$brand=$sub_category=$product_id=$product_name=$description=$main_image=$prod_detail=$alt_image=$out_of_stock=$color=undef;
	
}1;