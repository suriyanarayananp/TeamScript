#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
package Forever21_US;
use strict;
use URI::Escape;

sub Forever21_US_DetailProcess()
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
	my $Retailer_Random_String='For';
	my $mflag = 0;
	# sleep 10;
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
		
	# Appending home url if Product url doesn't start with "http".
	$url='http://www.forever21.com'.$url unless($url=~m/^\s*http\:/is);
	RepingOccur:
	# Get the page content from utilityobject module.
	my $content2 = $utilityobject->Lwp_Get($url);
	
	# open fh, ">$product_object_key.html";
	# print fh $content2;
	# close fh;	
	
	# Declaring all the required variables.	
	my ($price,$price_text,$brand,$product_id,$product_name,$description,$prod_detail,%color_hash,$out_of_stock);
	
	# Get the view state,event validation values for the formation of page's post content.
	my($view_state,$EVENTVALIDATION)=&view_state_Event_val($content2);
		
	# Pattern match to get product's id(reatailer product reference).
	if ( $content2 =~ m/Product\s*Code\s*\:[^<]*?(\w[^<]*?)</is )
	{
		my $prod_id=$utilityobject->Trim($&); 
		
		# Call UpdateProducthasTag to update tag information of the new product if product id already exists. 
		$product_id=$1 if($prod_id=~m/Product\s*Code\s*\:[^<]*?(\w[^<]*?)</is);
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id,$product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
			
	# Pattern match to get product price text & price(Scenario 1).
	if ( $content2 =~ m/<p\s*class\=\"product\-price\">\s*([\w\W]*?)\s*<\/\s*p>/is )
	{
		$price_text = $utilityobject->PriceFormat($1, $ccode);
		$price=$price_text;
		$price=~s/\$//is;
	}
	elsif($content2=~m/<span\s*itemprop\=\"price\">\s*<p\s*class\=\"was\-now\-price\">([\w\W]*?)<br\s*\/>([\w\W]*?)<\/\s*p>/is)# Pattern match to get product price text & price(Scenario 2).
	{
		$price_text = $utilityobject->PriceFormat($1, $ccode);
		$price=$utilityobject->Trim($2);
		$price_text=$price_text."-".$price;
		$price=~s/now\s*\:|\$//igs;
	}
	# Pattern match to get product name.
	if ( $content2 =~ m/<h1\s*class\=(?:\"|\')[^<]*?product\-title(?:\"|\')\s*>([\w\W]*?)<\/h1>/is )
	{
		$product_name = $utilityobject->Trim($1);
		# $product_name=~s/&eacute;/é/is;
		# $product_name=~s/&trade;/™/igs;	
		# $product_name=~s/<[^>]*?>/ /igs;
		# $product_name=~s/^\s+|\s+$//igs;
		# $product_name=~s/\s+/ /igs;
		# $product_name=~s/Â//igs;	
		# $product_name=decode_entities($product_name); 
	}
	# Pattern match to get product brand. 
	if($content2=~m/hdBrand\"\s*value\=\"([^>]*?)\"/is)  
	{
		$brand=$1;
		if ( $brand !~ /^\s*$/g )
		{
			$dbobject->SaveTag('Brand',$brand,$product_object_key,$robotname,$Retailer_Random_String);
		}
	}
	
	# Declaring required variables to get the post content.
	my ($cat_name,$item_code,$hdProductSKU);
	
	# Pattern match to get the category name (helpful for the formation of post content).
	if($content2=~m/hdCategoryName\"\s*value\=\"([^>]*)\"/is)
	{
		$cat_name=$1;
	}
	# Pattern match to get the category item code(helpful for the formation of post content).	
	if($content2=~m/hdItemCode\"\s*value\=\"([^>]*)\"/is)
	{
		$item_code=$1;
	}
	# Pattern match to get the category sku code(helpful for the formation of post content).	
	if($content2=~m/hdProductSKU\"\s*value\=\"([^>]*?)\"/is)
	{
		$hdProductSKU=$1;
	}
	
	# Pattern match to get product description & detail.
	if($content2=~m/class\=(?:\"|\')\s*(?:simpleTabsContent|productdesc)\s*(?:\"|\')>([\w\W]*?)<[^>]*?>\s*DETAILS\s*\:\s*<[^>]*?>([\w\W]*?)<\/div>/is)
	{
		$description=$utilityobject->Trim($1);
		$prod_detail=$2;
		
		$prod_detail=~s/<li>/-/igs;	
		 
		$prod_detail=$utilityobject->Trim($prod_detail);
		$prod_detail=~s/(?:Model\s*Info|Product\s*Code)[\w\W]*$//igs;	
	}
	elsif($content2=~m/class\=(?:\"|\')\s*(?:simpleTabsContent|productdesc)\s*(?:\"|\')>([\w\W]*?)<\/p>\s*<ul>\s*<li>([\w\W]*?)<\/div>/is) # Pattern match to get product description & detail.
	{	
		$description=$utilityobject->Trim($1);
		$prod_detail=$2;		
		
		$prod_detail=~s/<li>/-/igs;
		
		$prod_detail=$utilityobject->Trim($prod_detail);	
		$prod_detail=~s/(?:Model\s*Info|Product\s*Code)[\w\W]*$//igs;
	}	
	
	# Pattern match to get colour and colour data(id) and forming a hash.
	my $reg_1='<option\s*[^>]*?\s*value\=\"('.$item_code.'[^\"]*)\"\s*>\s*([\w\W]*?)\s*<\/\s*option>';
	while($content2=~m/$reg_1/igs)
	{	
		my $colr_data=$1;
		my $color=$2;
		
		my $colr_ids=(split('\|',$colr_data))[0];
		
		$color_hash{$colr_ids}=[$color,$colr_data];
		# $color_hash{$colr_ids}=[$color,uri_escape($colr_data)];
	}

	# To take color count from hash.
	my @key=keys %color_hash;
	my $color_count=@key;
	# my $tcontent = $content2
	my $subpost;
	while($content2 =~ m/type\=\"hidden\"\s*id\=\"([^>]*?)\"\s*value\=\"([^>]*?)\"/igs)
	{
		my $key = uri_escape($1);
		my $val = uri_escape($2);
		$key =~ s/_/\%24/igs;
		$val =~ s/_/\%24/igs;
		$subpost .= "$key=$val&";
		# print $subpost,"\n\n";
	}
	# Pattern match if content matches with largeimage for getting images(Scenario 1).
	if($content2=~m/largeimage\s*\:\s*\'([^\']*?)\'\s*\}/is) 
	{
		if($color_count>1) # Checking whether colour count is greater than one.
		{
			foreach my $color_id (sort{$a<=>$b} keys %color_hash) #  Taking each colour id from colour hash.
			{
				my $color_code;
				if($color_id=~m/[\w\W]*?\-([\w\W]*)/is)  # Getting colour code from colour id for Objectkey mapping.
				{
					$color_code=$1;
				}
				# print "ColorHash:: $color_hash{$color_id}[1] \n\n";
				my $id_s=(split('\|',$color_hash{$color_id}[1]))[-2];  # Getting ids to form post content.
				print "IDS :: $id_s\n";
				my $post_content;
				# my $subpost;
				# while($content2 =~ m/id\=\"(ctl00_MainContent_dlColorChart_ctl0\d+_hdProductSKU)\"\s*value\=\"([^>]*?)\"/igs)
				# {
					# $subpost .= "$1=$2";
				# }
				my $oospid = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdProductID_OOS\"\s*value\=\"([^>]*?)\"/is);
				my $oosname = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdDisplayName_OOS\"\s*value\=\"([^>]*?)\"/is);
				my $oosprice = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdPrice_OOS\"\s*value\=\"([^>]*?)\"/is);
				my $oosbrand = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdBrand_OOS\"\s*value\=\"([^>]*?)\"/is);
				my $ooscul = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdCulture_OOS\"\s*value\=\"([^>]*?)\"/is);
				my $oospcolimg = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdProductColorImages\"\s*value\=\"([^>]*?)\"/is);
				if($content2 =~ m/id\=\"ctl00_MainContent_hdProductID_OOS\"\s*value\=\"([^>]*?)\"/is)
				{
					my $oospid = $1;
					my $oosname = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdDisplayName_OOS\"\s*value\=\"([^>]*?)\"/is);
					my $oosprice = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdPrice_OOS\"\s*value\=\"([^>]*?)\"/is);
					my $oosbrand = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdBrand_OOS\"\s*value\=\"([^>]*?)\"/is);
					my $ooscul = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdCulture_OOS\"\s*value\=\"([^>]*?)\"/is);
					my $oospcolimg = $1 if($content2 =~ m/id\=\"ctl00_MainContent_hdProductColorImages\"\s*value\=\"([^>]*?)\"/is);
					# $post_content = "__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=$view_state&ctl00%24MainContent%24hdBrand=$brand&ctl00%24MainContent%24hdCategoryName=$cat_name&ctl00%24MainContent%24hdProductId=$product_id&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode=$item_code&ctl00%24MainContent%24hdRepColorCode=$color_code&$subpost&ctl00%24MainContent%24ddlColor=".$color_hash{$color_id}[1]."&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&ctl00%24MainContent%24hdProductID_OOS=$oospid&ctl00%24MainContent%24hdDisplayName_OOS=$oosname&ctl00%24MainContent%24hdPrice_OOS=$oosprice&ctl00%24MainContent%24hdBrand_OOS=$oosbrand&ctl00%24MainContent%24hdCulture_OOS=$ooscul&ctl00%24MainContent%24hdProductColorImages=$oospcolimg&__ASYNCPOST=true&&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.x=17&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.y=9";
					
					if($brand =~ m/21/is)
					{
						$post_content = "ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=$view_state&ctl00%24MainContent%24hdBrand=$brand&ctl00%24MainContent%24hdCategoryName=$cat_name&ctl00%24MainContent%24hdProductId=$product_id&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode=$item_code&ctl00%24MainContent%24hdRepColorCode=$color_code&$subpost&ctl00%24MainContent%24ddlColor=".$color_hash{$color_id}[1]."&ctl00%24MainContent%24hdProductID_OOS=$oospid&ctl00%24MainContent%24hdDisplayName_OOS=$oosname&ctl00%24MainContent%24hdPrice_OOS=$oosprice&ctl00%24MainContent%24hdBrand_OOS=$oosbrand&ctl00%24MainContent%24hdCulture_OOS=$ooscul&ctl00%24MainContent%24hdProductColorImages=$oospcolimg&__ASYNCPOST=true&&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.x=17&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.y=9";
					}
					else
					{
						$post_content = "ctl00%24MainContent%24hdBrand=$brand&ctl00%24MainContent%24hdCategoryName=$cat_name&ctl00%24MainContent%24hdProductId=$product_id&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode=$item_code&ctl00%24MainContent%24hdRepColorCode=$color_code&ctl00%24MainContent%24dlColorChart%24ctl00%24hdProductSKU=$hdProductSKU&ctl00%24MainContent%24dlColorChart%24ctl01%24hdProductSKU=$hdProductSKU&ctl00%24MainContent%24ddlColor=".$color_hash{$color_id}[1]."&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&ctl00%24MainContent%24hdProductID_OOS=$oospid&ctl00%24MainContent%24hdDisplayName_OOS=$oosname&ctl00%24MainContent%24hdPrice_OOS=$oosprice&ctl00%24MainContent%24hdBrand_OOS=$oosbrand&ctl00%24MainContent%24hdCulture_OOS=$ooscul&ctl00%24MainContent%24hdProductColorImages=$oospcolimg&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=$view_state&__ASYNCPOST=true";					
					}
					
				}
				else
				{
				
					$post_content ='ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage&ctl00%24MainContent%24hdBrand='.$brand.'&ctl00%24MainContent%24hdCategoryName='.$cat_name.'&ctl00%24MainContent%24hdProductId='.$product_id.'&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode='.$item_code.'&ctl00%24MainContent%24hdRepColorCode='.$color_code.'&ctl00%24MainContent%24dlColorChart%24ctl00%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24dlColorChart%24ctl01%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24ddlColor='.$color_hash{$color_id}[1].'&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='.$view_state.'&__ASYNCPOST=true&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.x=9&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.y=6';
				}
				# $post_content ='ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage&ctl00%24MainContent%24hdBrand='.$brand.'&ctl00%24MainContent%24hdCategoryName='.$cat_name.'&ctl00%24MainContent%24hdProductId='.$product_id.'&ctl00%24MainContent%24hdVariantId=&ctl00%24MainContent%24hdItemCode='.$item_code.'&ctl00%24MainContent%24hdRepColorCode='.$color_code.'&ctl00%24MainContent%24dlColorChart%24ctl00%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24dlColorChart%24ctl01%24hdProductSKU='.$hdProductSKU.'&ctl00%24MainContent%24ddlColor='.$color_hash{$color_id}[1].'&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='.$view_state.'&__ASYNCPOST=true&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.x=9&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.y=6';
				if($brand =~ m/21|plus/is)
				{
					if($content2 =~ m/id\=\"__VIEWSTATEGENERATOR\"\s*value\=\"([^>]*?)\"/is)
					{
						$post_content = "ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=$view_state&__VIEWSTATEGENERATOR=$1&$subpost&ctl00%24MainContent%24ddlColor=".$color_hash{$color_id}[1]."&ctl00%24MainContent%24hdProductID_OOS=$oospid&ctl00%24MainContent%24hdDisplayName_OOS=$oosname&ctl00%24MainContent%24hdPrice_OOS=$oosprice&ctl00%24MainContent%24hdBrand_OOS=$oosbrand&ctl00%24MainContent%24hdCulture_OOS=$ooscul&ctl00%24MainContent%24hdProductColorImages=$oospcolimg&__ASYNCPOST=true&&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.x=17&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.y=9";
					}
					else
					{
						$post_content = "ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=$view_state&$subpost&ctl00%24MainContent%24ddlColor=".$color_hash{$color_id}[1]."&ctl00%24MainContent%24hdProductID_OOS=$oospid&ctl00%24MainContent%24hdDisplayName_OOS=$oosname&ctl00%24MainContent%24hdPrice_OOS=$oosprice&ctl00%24MainContent%24hdBrand_OOS=$oosbrand&ctl00%24MainContent%24hdCulture_OOS=$ooscul&ctl00%24MainContent%24hdProductColorImages=$oospcolimg&__ASYNCPOST=true&&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.x=17&ctl00%24MainContent%24dlColorChart%24ctl0$id_s%24imgColorImage.y=9";
					}
				}
				else
				{
					$post_content ='ctl00%24MainContent%24ScriptManager1=ctl00%24MainContent%24upColorChart%7Cctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage&'.$subpost.'ctl00%24MainContent%24ddlColor='.$color_hash{$color_id}[1].'&ctl00%24MainContent%24ddlSize=&ctl00%24MainContent%24ddlQty=1&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='.$view_state.'&__ASYNCPOST=true&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.x=9&ctl00%24MainContent%24dlColorChart%24ctl0'.$id_s.'%24imgColorImage.y=6';
				}
				# print "\n\n$post_content\n\n";
				#Forming Page's Post Content (depend on color change).
				# RepingOccur:
				my $content_3 = $utilityobject->Lwp_Post($url,$post_content); 
				# print "Post content1\n";
				# open(fh,">post_content_".$id_s."_".$product_object_key.".html");
				# print fh "$content_3";
				# close fh;
				# goto RepingOccur if($content_3 !~ m/liImageButton_0/is);
				($view_state,$EVENTVALIDATION)=&view_state_Event_val($content_3); # Getting view_state,event validation values to form next post content.
				my $img_count=0;
				
				# Pattern match to get image urls.
				while($content_3=~m/largeimage\s*\:\s*\'([^\']*?)\'\s*\}/igs)  
				{
					my $final_img_url=$1;
					my $img_cont = $utilityobject->GetCode($final_img_url);  # Getting the status of the image url. 
					
					next if($img_cont!=200); # Getting the next image url if status code isn't 200.
					
					# Downloading and save entry for product images
					my $img_file = $imagesobject->download($final_img_url,'product',$retailer_name,$ua);
			
					if($img_count==0) # Getting deafault(Main) image url.
					{
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'y') if(defined $img_file);
					}
					else # Getting alternate image urls.
					{
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
						
					}
					$img_count++;
				}
				# Pattern match to check whether size is available and get a size block for each color.
				if($content_3=~m/>\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
				{
					my $size_block=$1;
					my $size_count=0;
					
					# Pattern match to get each size.
					while($size_block=~m/<option\s*[^>]*value\=\"[^>]*\">\s*([^<]*?)\s*<\/option>/igs)
					{
						my $size=$1;
						$out_of_stock='n';
						if($size=~m/sold\s*out/is)
						{
							$out_of_stock='y';
						}
						$size=~s/\s*\([^\)]*?\)//igs;
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table. 
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color_hash{$color_id}[0],$out_of_stock,$Retailer_Random_String,$robotname,$color_id);
						
						$size_count++;
					}
					if($size_count==0) 
					{
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table if size block not available.
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'',$color_hash{$color_id}[0],$out_of_stock,$Retailer_Random_String,$robotname,$color_id);
					}
				}
				# Pattern match to get swatch image url & it's code.
				while($content2=~m/imgColorImage\"\s*src\=\"([^>]*?(?:(\d{2})\s*\.\s*jpg)?)\s*\"/igs) 
				{
					my $final_sw_img_url=$1;
					my $sw_clr_code=$2;
					
					if($sw_clr_code eq $color_code) # To save swatch image urls of the corresponding colour.
					{
						my $sw_img_cont = $utilityobject->GetCode($final_sw_img_url); # Getting the status code for the swatch image url.
								
						next if($sw_img_cont!=200); 
						
						# Downloading and save entry for swatch images.
						my $img_file = $imagesobject->download($final_sw_img_url,'swatch',$retailer_name,$ua);
			
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_sw_img_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
					}
				}
			}
		}
		elsif($color_count<=1) # If colour count less than or equal to 1.
		{
			foreach my $color_id (sort{$a <=> $b}keys %color_hash) # Getting colour id from colour hash.
			{
				my $img_count=0;
				
				# Pattern match to get image urls.
				while($content2=~m/largeimage\s*\:\s*(?:\'|\")([^>]*?)(?:\'|\")[^>]*?>/igs) 
				{
					my $final_img_url=$1;
					
					my $img_cont = $utilityobject->GetCode($final_img_url); # Get the status of each image url.
					
					next if($img_cont!=200); # If status code is not "200",get the next url.
				
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($final_img_url,'product',$retailer_name,$ua);
					
					if($img_count==0) # Get the default(main) image url.
					{
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'y') if(defined $img_file);
					}
					else # Get the alternate(main) image urls.
					{
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
					}
					$img_count++; # increment the value to write image urls as alternate image urls.
				}
				
				# Pattren match to get color.
				my $color=$1 if($content2=~m/<option[^>]*?selected\s*\=\s*\"selected\s*\"\s*[^>]*?>[^>]*?(?:<[^>]*?>\s*)+\s*([^>]*?)</is);
				
				# Pattern match to check whether size is available and get a size block for each color.
				if($content2=~m/>\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
				{
					my $size_block=$1;
					my $size_count=0;
					
					# Pattern match to get each size.
					while($size_block=~m/<option\s*[^>]*value\=\"[^>]*\">\s*([\w\W]*?)\s*<\/option>/igs)
					{
						my $size=$1;
						$out_of_stock='n';
						if($size=~m/sold\s*out/is)
						{
							$out_of_stock='y';
						}
						$size=~s/\s*\([^\)]*?\)//igs;
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table. 
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color_id);
						
						$size_count++;
					}
					if($size_count==0)
					{
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table if size block not available.
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'',$color,$out_of_stock,$Retailer_Random_String,$robotname,$color_id);
					}
				}
				
				# Pattern match to get swatch image url.
				while($content2=~m/imgColorImage\"\s*src\=\"([^>]*?(?:(\d{2})\s*\.\s*jpg)?)\s*\"/igs) 
				{
					my $final_sw_img_url=$1;
					my $sw_clr_code=$2;
					
					my $sw_img_code = $utilityobject->GetCode($final_sw_img_url);  # Getting the status code for the swatch image url.
							
					next if($sw_img_code!=200);
					
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($final_sw_img_url,'swatch',$retailer_name,$ua);
			
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($final_sw_img_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$color_id,'n') if(defined $img_file);
				}
			}
		}
		elsif(($content2=~m/oos_btn/is)||($content2=~m/oos_tag/is))
		{
			my $img_count=0;
			
			while($content2=~m/largeimage\s*\:\s*\'([^\']*?)\'\s*\}/is)
			{
				my $final_img_url=$1;
					
				my $img_cont = $utilityobject->GetCode($final_img_url); # Get the status of each image url.
				
				next if($img_cont!=200); # If status code is not "200",get the next url.
			
				# Downloading and save entry for product images.
				my $img_file = $imagesobject->download($final_img_url,'product',$retailer_name,$ua);
				
				if($img_count==0) # Get the default(main) image url.
				{
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,'','y') if(defined $img_file);
				}
				else # Get the alternate(main) image urls.
				{
					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,'','n') if(defined $img_file);
				}
				$img_count++; # increment the value to write image urls as alternate image urls.	
			}
		}
	}
	elsif($content2=~m/<div[^>]*?id\s*\=\s*(?:\"|\')\s*imageBoxInside\s*(?:\"|\')[^>]*?>([\w\W]*?)<\/div>/is) # Pattern match if page content matches with "imageBoxInside" for getting images url(url differs with "product_pop.aspx") (Scenario 2).
	{
		if($content2=~m/<div\s*id\s*\=\s*\"\s*upColorChart\s*\"\s*>([\w\W]*?)<\/div>/is) # Pattern match to take block for taking color details.
		{
			my $blk=$1;
			
				# Pattern match to take colour content and colour code.
				while($blk=~m/<td[^>]*?>\s*<input[^>]*?id\s*\=\s*\"([^>]*?)\s*\"\s*src\s*\=\s*\"[^<]*?\-([^<]*?)\s*\.\s*jpg[^>]*?>/igs)
				{
					my $color_cont=$1;
					my $color_code=$2;
					
					$color_cont=~s/_/%24/igs;
					
					my $post_content='ScriptManager1=upColorChart%7CdlColorChart%24ctl03%24imgColorImage&hdBrand='."$brand".'&hdCategoryName='."$cat_name".'&hdProductId='."$product_id".'&hdVariantId=&hdItemCode='."$hdProductSKU".'&hdRepColorCode=04&rpButtonImageList%24ctl00%24hdIdx=0&rpButtonImageList%24ctl00%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl01%24hdIdx=1&rpButtonImageList%24ctl01%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl02%24hdIdx=2&rpButtonImageList%24ctl02%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl03%24hdIdx=3&rpButtonImageList%24ctl03%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl04%24hdIdx=4&rpButtonImageList%24ctl04%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl05%24hdIdx=5&rpButtonImageList%24ctl05%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&rpButtonImageList%24ctl06%24hdIdx=6&rpButtonImageList%24ctl06%24hdImageName='."$hdProductSKU"."-$color_code".'.jpg&dlColorChart%24ctl00%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl01%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl02%24hdProductSKU='."$hdProductSKU".'&dlColorChart%24ctl03%24hdProductSKU='."$hdProductSKU".'&ddlColor='."$hdProductSKU"."-$color_code".'%7Clarge%7C0%7C'."$color_code".'&ddlQty=1&ddlSize=&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE='."$view_state".'&__ASYNCPOST=true&'."$color_cont".'.x=18&'."$color_cont".'.y=13';
					# Forming Page's Post Content.
					
					my $content_3 = $utilityobject->Lwp_Post($url,$post_content);
					# print "Post Content 2\n";
					# open(fh,">post_content2.html");	
					# print fh "$content_3";
					# close fh;
					#exit;
					
					
					if($content_3=~m/<div[^>]*?id\s*\=\s*(?:\"|\')imageBoxInside(?:\"|\')[^>]*?>([\w\W]*?)<\/div>/is)# Pattern match to get block for taking image urls.
					{
						my $blk1=$1;
						my $img_count=0;
						
						# Pattern match to get the image urls.
						while($blk1=~m/<img[^>]*?src\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')[^>]*?>/igs)
						{
							my $final_img_url=$1;
							$final_img_url=~s/_58/_330/igs; # Pattern substitution to change size.
							
							my $img_cont = $utilityobject->GetCode($final_img_url); # Get the status code for the image url.
							
							next if($img_cont!=200); # Get the next url if status code is not "200".   
						
							# Downloading and save entry for product images.
							my $img_file = $imagesobject->download($final_img_url,'product',$retailer_name,$ua);
					
							if($img_count==0)
							{
								# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
								$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_code,'y') if(defined $img_file);
							}
							else
							{
								# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
								$dbobject->SaveImage($final_img_url,$img_file,'product',$Retailer_Random_String,$robotname,$color_code,'n') if(defined $img_file);
							}
							$img_count++;
						}
					}
				
				# Pattern match to get color.
				my $color=$1 if($content_3=~m/<option[^>]*?selected\s*\=\s*\"selected\s*\"\s*[^>]*?>([^<]*?)</is);
				
				# Pattern match to check whether size is available and get a size block for each color.
				if($content_3=~m/>\s*Size\s*<\/option>([\w\W]*?)<\/select>/is)
				{
					my $size_block=$1;
					my $size_count=0;
					
					# Pattern match to get each size.
					while($size_block=~m/<option\s*[^>]*value\=\"[^>]*\">\s*([\w\W]*?)\s*<\/option>/igs)
					{
						my $size=$1;
						$out_of_stock='n';
						if($size=~m/sold\s*out/is)
						{
							$out_of_stock='y';
						}
						$size=~s/\s*\([^\)]*?\)//igs;
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table. 
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,$size,$color,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);
						
						$size_count++;
					}
					if($size_count==0)
					{
						my $out_of_stock='n';
						$price='null' if($price eq '' or $price eq ' ');
						
						# Save entry to sku table if size block not available.
						$dbobject->SaveSku($product_object_key,$url,$product_name,$price,$price_text,'',$color,$out_of_stock,$Retailer_Random_String,$robotname,$color_code);
					}
				}
				#Pattern match to get swatch image url.
				while($content2=~m/imgColorImage\"\s*src\=\"([^>]*?(?:(\d{2})\s*\.\s*jpg)?)\s*\"/igs) 
				{
					my $final_sw_img_url=$1;
					my $sw_clr_code=$2;
					
					if($sw_clr_code eq $color_code) # To save swatch image urls of the corresponding colour.
					{
						my $sw_img_cont = $utilityobject->GetCode($final_sw_img_url,"GET","","");# Getting the status code for the swatch image url.						
								
						next if($sw_img_cont!=200);
						
						# Downloading and save entry for product images
						my $img_file = $imagesobject->download($final_sw_img_url,'swatch',$retailer_name,$ua);
				
						# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
						$dbobject->SaveImage($final_sw_img_url,$img_file,'swatch',$Retailer_Random_String,$robotname,$color_code,'n') if(defined $img_file);
					}
				}
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
	
	# Committing transaction and undefine the query array.
	$dbobject->commit();
	$dbobject->Destroy();

	$price=$price_text=$brand=$product_id=$product_name=$description=$prod_detail=%color_hash=undef;	
}1;

#Function to get page's view state and Event validation values for post content  
sub view_state_Event_val
{
	my $cont=shift;
	my($view_state,$EVENTVALIDATION);
	if($cont=~m/VIEWSTATE\"\s*value\=\"([^~]*?)\"/is)
	{
		$view_state=uri_escape($1);
	}
	elsif($cont=~m/__VIEWSTATE\|([\w\W]+?)\|/is)
	{
		$view_state=uri_escape($1);
	}
	if($cont=~m/EVENTVALIDATION\"\s*value\=\"([^~]*?)\"/is)
	{
		$EVENTVALIDATION=uri_escape($1);
	}
	elsif($cont=~m/EVENTVALIDATION\|([\w\W]+?)\|/is)
	{
		$EVENTVALIDATION=uri_escape($1);
	}
	return $view_state,$EVENTVALIDATION;
} 
