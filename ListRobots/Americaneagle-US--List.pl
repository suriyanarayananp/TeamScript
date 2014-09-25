#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;

# Package Initialization.
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings.
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Variable Initialization.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Ame';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %totalHash;

# Setting the UserAgent.
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});

# Read the settings from the config file.
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) 
{
	# Die if reading the settings failed.
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog.
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

# Connect to AnorakDB Package.
my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Connect to Utility package.
my $utilityobject = AnorakUtility->new($logger,$ua);

# Getting Retailer_id and Proxystring.
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Using the argument set the domain URLs'.
my $url="http://www.ae.com";
print "$url\n";
# Fetch the content based on the domain URLs'.
my $content0=$utilityobject->Lwp_Get($url);
my $tempcont0 = $content0;
# Navigate for each main menu.
while($content0 =~ m/href\=\"([^>]*?)\">\s*<span\s*class\=\"catLabel[^>]*?\">\s*([^>]*?)\s*<\/span>\s*<\/a>/igs)
{
	my $menu1url = $utilityobject->Trim($1);
	my $menu_1 = $utilityobject->Trim($2);
	my $menu1 = $menu_1;
	
	# $menu1url='' if($menu_1=~m/Jeans/is);
	# next unless($menu_1 =~ m/Clearance/is);
	$menu1url="http://www.ae.com".$menu1url if($menu1url!~m/^http/is);
	print "$menu1url\n";
	# Check if menu1 is Men or Women.
	if($menu1 =~ m/Men|Women/is) 
    {
		# Fetch the content based on the menu1 url's.
        my $menucontent = $utilityobject->Lwp_Get($menu1url); 
		
		if($menucontent =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?<\/div>)/is) 
        { 
            my $tempcont = $1;

			# Fetch the collections block.
            if($tempcont =~ m/>\s*(Collections)\s*<\/span>([\w\W]*?)<span\s*class\=\"noLink\">/is) 
			{
				my $menu2 = $1;
				my $subcont2 = $2;
				
				# Loop through the collection category get the menu3 [Menu2 :: Collections].
				while($subcont2 =~ m/class\=\"navCat_cat\d+\s*emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $menuurl2 = $1;
					my $menu3 = $2;
					my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
					my $test=quotemeta($menu3);
					# Check if menu3 having sub-block, it should consider as menu4 [Menu3 :: New Arrivals].
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						
						# Getting the product page URLs from the block.
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							print "$menu1->$menu2->$menu3->$menu4\n";
							my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
							
							# Pattern match to get the category ID.
							my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
							
							# Pattern match to get the block based on the category ID.
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								
								# Collecting the Product URLs.
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Whether the product page URLs having bundle products.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
							
							# Pattern match to getting the productIDs' from the sub content.
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								# pattern match to collecting the productID.
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Collecting the bundle product based on the ProductIDs.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
						}
					}
					else
					{
						print "$menu1->$menu2->$menu3\n";
						
						# Pattern match to get the categoryID.
						my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
						
						# Pattern match to get the block based on the category ID.
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the sub-product based on the ProductIDs.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
						
						# Pattern match to available productIDs.
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							# Loop through to get the productIDs from the block.
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the child product based on the Parent ProductIDs.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
				}
			}
		
			# Fetch the Categories block.
			if($tempcont =~ m/>\s*(Categories)\s*<\/span>([\w\W]*?)<\/li>\s*<\/ul>\s*<\/div>/is)
			{
				my $menu2 = $1;
				my $subcont2 = $2;
				print "Menu2 -> $menu2\n";
				# Loop through the collection category get the menu3 [Menu2 :: Categories].
				while($subcont2 =~ m/class\=\"navCat_cat\d+\s*emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $menuurl2 = $1;
					my $menu3 = $2;
					my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
					my $test=quotemeta($menu3);
					
					# Check if menu3 having sub-category, [Menu3 :: Tops].
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						
						# Getting the Sub-Content based on the menu3 content.
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
							my $test = quotemeta($menu4);
							print "$menu1->$menu2->$menu3\n";
							# Check if menu4 having sub-category, [Menu4 :: Graphic Tees].
							if($subcont5 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
							{
								my $subcont6 = $1;
								
								while($subcont6 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
								{
									my $menuurl4 = $1;
									my $menu5 = $2;   #Low Rise trunks
									print "$menu1->$menu2->$menu3->$menu4->$menu5\n";
									my $subcont6 = $utilityobject->Lwp_Get($menuurl4);
									
									# Pattern match to get the categoryID.
									my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
									
									# Pattern match to get the category block based on the category ID.
									if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										
										# Loop through to get the productIDs from the block.
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
									if($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										
										# Loop through to get the productIDs from the block.
										while($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
								}
							}
							else ## No Sub Menu from menu3 Eg: socks menu
							{
								print "$menu1->$menu2->$menu3->$menu4\n";
								
								# Pattern match to get the categoryID.
								my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
								
								# Pattern match to get the category block based on the category ID.
								if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									
									# Collect the ProductID from the Category Block.
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
											
											# Insert Product_List table based on values collected for the product.											
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
								
								# Pattern match to get the productID.
								if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									# Loop through to get the productIDs from the block.
									while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
							}
						}
					}
					else
					{
						print "$menu1->$menu2->$menu3\n";
								
						# Pattern match to get the categoryID.
						my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
						
						# Pattern match to get the category block based on the category ID.
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							
							# Collect the ProductID from the Category Block.
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid;
									
									# Insert Product_List table based on values collected for the product.											
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
						
						# Pattern match to get the productID.
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							# Loop through to get the productIDs from the block.
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
				}
				if($subcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"[^>]*?\">([\w\W]*?)<\/ul>/is)
				{
					while($subcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"[^>]*?\">([\w\W]*?)<\/ul>/igs) ##categoreis->tops
					{
						my $menu3 = $1;
						my $menusubcont = $2;
						while($menusubcont =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							my $subcont3 = $utilityobject->Lwp_Get($menuurl3);
							my $test=quotemeta($menu4);
							if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) ## Trunks Block
							{
								my $subcont4 = $1;
								
								# Getting the product page URLs from the block.
								while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
								{
									my $menuurl4 = $1;
									my $menu5 = $2;
									my $subcont5 = $utilityobject->Lwp_Get($menuurl4);
								
									# Pattern match to get the categoryID.
									my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
									print "$menu1->$menu2->$menu3->$menu4->$menu5\n";
									
									# Pattern match to get the category block based on the category ID.
									if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										
										# Loop through to get the productID from the content.
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);

												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
									if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										
										# Loop through to get the productID from the content.
										while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
								}
							}
							else ## No Sub Menu from menu3 Eg: socks menu
							{
								print "$menu1->$menu2->$menu3->$menu4\n";
								
								# Pattern match to get the categoryID.
								my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
								
								# Pattern match to get the category block based on the category ID.
								if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									
									# Loop through to get the productID from the content.
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
								if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									
									# Loop through to get the productID from the content.
									while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
							}
						}
					}
				}
			}
			# Pattern match to get the Trends block.
			if($tempcont =~ m/>\s*(Trends)\s*<\/span>([\w\W]*?)<\/ul>/is)
			{
				my $menu2 = $1; #Trends
				my $subcont2 = $2;
				while($subcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $caturl = $1;
					my $menu3 = $2; #vday shop
					my $subcont3 = $utilityobject->Lwp_Get($caturl);
					print "$menu1->$menu2->$menu3\n";
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) ## Trunks Block
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
						{
							my $menuurl4 = $1;
							my $menu4 = $2;
							my $subcont5 = $utilityobject->Lwp_Get($menuurl4);
							
							# Pattern match to get the categoryID.
							my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
							print "Link32=>$menu1->$menu2->$menu3->$menu4\n";
							
							# Pattern match to get the category block based on the category ID.
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								
								# Loop through to get the productID from the content.
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								# Loop through to get the productID from the content.
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
						}
					}
					else
					{
						# Pattern match to get the categoryID.
						my $catid = $1 if($caturl =~ m/catId\=([^>]*?)$/is);
						
						# Pattern match to get the category block based on the category ID.
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							print "Link32=>$menu1->$menu2->$menu3\n";
							my $catCollection = $1;
							
							# Loop through to get the productID from the content.
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							# Loop through to get the productID from the content.
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
				}
			}
		} 
    }
	elsif($menu1 =~ m/Clearance/is) # Check if the menu1 is clearance then get the content from the menu1 URLs.
    { 
        my $menucontent = $utilityobject->Lwp_Get($menu1url); 
        if($menucontent =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
        { 
			my $tempcont = $1; 
            while($tempcont =~ m/<span[^>]*?class\s*\=\s*\"\s*noLink\s*\"[^>]*?>([^<]*?)<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>\s*<\/ul>\s*<\/li>/igs)
			{
				my $menu2= $utilityobject->Trim($1);
				my $menu2_blk = $&; 
				while($menu2_blk =~ m/class\=\"[^>]*?>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $caturl2 = $1; 
					my $menu3 = $utilityobject->Trim($2); 
					next if($menu3 =~ m/clearance/is);
					$caturl2="http://www.ae.com".$caturl2 if($caturl2!~m/^http/is);
					my $menucontent2 = $utilityobject->Lwp_Get($caturl2);
					if($menucontent2 =~ m/>\s\Q$menu2\E[\w\W]*?<span>\s*\Q$menu3\E\s*<\/span>\s*<\/a>\s*<ul class="subMenu">([\w\W]*?)<\/ul>/is)
					{
						my $subcont5 = $1;
						while($subcont5 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
						{
							my $menuurl4 = $1;
							my $menu4 = $utilityobject->Trim($2);
							print "Check5 => $menu1->$menu2->$menu3->$menu4\n";
							$menuurl4="http://www.ae.com".$menuurl4 if($menuurl4!~m/^http/is);
							my $subcont6 = $utilityobject->Lwp_Get($menuurl4);
							my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
							if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									
									my $pid = $utilityobject->Trim($1);
											
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($menucontent2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
						}
					}
					else
					{
						print "$menu1 -> $menu2 -> $menu3\n";
						my $catid = $1 if($caturl2 =~ m/catId\=([^>]*?)$/is);
						if($menucontent2 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								
								my $pid = $utilityobject->Trim($1);
										
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($menucontent2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
				}
			}
		}
	} 
	elsif($menu_1=~ m/Aerie/is)  # If menu is aerie then collect the aerie products.
	{
		my $content=$utilityobject->Lwp_Get($menu1url);
		
		# Navigate through sub category based on the menu.
		while($content=~ m/href\=\"([^>]*?)\">\s*<span\s*class\=\"catLabel[^>]*?\">\s*([^>]*?)\s*<\/span>\s*<\/a>/igs)
		{
			my $url2 =  $utilityobject->Trim($1);
			my $menu2 =  $utilityobject->Trim($2); # Bras|Undies|Swim|Clothing
			print "Menu2 => $menu2\n";
			$url2="http://www.ae.com".$url2 if($url2!~m/^http/is);
			my $subcont = $utilityobject->Lwp_Get($url2);
			
			# Pattern match to get the category block.
			if($subcont =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
			{ 
				my $tempcont = $1;
				while($tempcont =~ m/<span\s*class\=\"noLink\">\s*([^>]*?)\s*<\/span><ul\s*class\=\"menu\">([\w\W]*?<\/ul>)\s*<\/li>/igs)
				{
					my $menu3 = $utilityobject->Trim($1); #Collections|Categories|Shop By Fit|Shop by Girl
					my $tempcont2 = $2;
					if($menu3 =~ m/Categories/is)
					{
						$tempcont2 = $2 if($subcont =~ m/>\s*(Categories)\s*<\/span>([\w\W]*?)<span\s*class\=\"noLink\">/is);
					}
					if($tempcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						while($tempcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/igs)
						{
							
							my $menu4 = $utilityobject->Trim($1);  #All Fit| View All
							my $tempcont3 = $2;
							while($tempcont3 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
							{
								my $url3 = $1;
								my $menu5 = $utilityobject->Trim($2);  #Push up Bra
								$url3="http://www.ae.com".$url3 if($url3!~m/^http/is);
								my $subcont2 = $utilityobject->Lwp_Get($url3);
								my $test=quotemeta($menu5);
								if($subcont2 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
								{
									my $subcont4 = $1;
									while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
									{
										my $menuurl3 = $1;
										my $menu6 = $2;
										print "Link1=>$menu1->$menu2->$menu3->$menu4->$menu5->$menu6\n";
										$menuurl3="http://www.ae.com".$menuurl3 if($menuurl3!~m/^http/is);
										my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
										
										# Pattern match to get the categoryID.
										my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
										
										# Pattern match to get the category block based on the category ID.
										if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
										{
											my $catCollection = $1;
											
											# Loop through to get the productID from the content.
											while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu5,$menu6,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
												
												# Pattern match to get the child productID from the Parent Product.
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = $utilityobject->Trim($1);
													
													# Form the Product URLs' based on the productID.
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													
													# Insert Product_List table based on values collected for the product.
													my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
													
													# Save the Tag Information based on the ProductID and Tag values.
													$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu5,$menu6,$product_object_key,$robotname,$Retailer_Random_String);
													
													# Committing the transaction.
													$dbobject->commit();
												}
											}
										}
										if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											# Loop through to get the productID from the content.
											while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu5,$menu6,$product_object_key,$robotname,$Retailer_Random_String); 
												
												# Committing the transaction.
												$dbobject->commit();
												
												# Pattern match to get the child productID from the Parent Product.
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = $utilityobject->Trim($1);
													
													# Form the Product URLs' based on the productID.
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													
													# Insert Product_List table based on values collected for the product.
													my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
													# Save the Tag Information based on the ProductID and Tag values.
													$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu5,$menu6,$product_object_key,$robotname,$Retailer_Random_String);
													
													# Committing the transaction.
													$dbobject->commit();
												}
											}
										}
									}
								}
								else
								{
									print "Link2=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
									
									# Pattern match to get the categoryID.
									my $catid = $1 if($url3 =~ m/catId\=([^>]*?)$/is);
									
									# Pattern match to get the category block based on the category ID.
									if($subcont2 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										
										# Loop through to get the productID from the sub-content.
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
									if($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										
										# Loop through to get the productID from the content.
										while($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();

											# Pattern match to get the child productID from the Parent Product.											
											if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
								}
							}
						}
						if($menu3 =~ m/categories/is)
						{
							while($tempcont2 =~ m/class\=\"navCat_cat\d+\s+emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
							{
							
								my $menuurl2 = $1;
								my $menu4 = $2;
								$menuurl2="http://www.ae.com".$menuurl2 if($menuurl2!~m/^http/is);
								my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
								my $test=quotemeta($menu4);
								if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
								{
									my $subcont4 = $1;
									while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
									{
										my $menuurl3 = $1;
										my $menu5 = $2;
										print "Link3=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
										$menuurl3="http://www.ae.com".$menuurl3 if($menuurl3!~m/^http/is);
										my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
										
										# Pattern match to get the categoryID.
										my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
										
										# Pattern match to get the category block based on the category ID.
										if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
										{
											my $catCollection = $1;
											
											# Loop through to get the productID from the content.
											while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String); 
												
												# Committing the transaction.
												$dbobject->commit();
												
												# Pattern match to get the child productID from the Parent Product.
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = $utilityobject->Trim($1);
													
													# Form the Product URLs' based on the productID.
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													
													# Insert Product_List table based on values collected for the product.
													my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
													
													# Save the Tag Information based on the ProductID and Tag values.
													$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
													
													# Committing the transaction.
													$dbobject->commit();
												}
											}
										}
										if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											# Loop through to get the productID from the content.
											while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String); 
												
												# Committing the transaction.
												$dbobject->commit();
												
												# Pattern match to get the child productID from the Parent Product.
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = $utilityobject->Trim($1);
													
													# Form the Product URLs' based on the productID.
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													
													# Insert Product_List table based on values collected for the product.
													my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
													
													# Save the Tag Information based on the ProductID and Tag values.
													$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
													$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
													
													# Committing the transaction.
													$dbobject->commit();
												}
											}
										}
									}
								}
								else
								{
									print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
									
									# Pattern match to get the categoryID.
									my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
									
									# Pattern match to get the category block based on the category ID.
									if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										
										# Loop through to get the productID from the Sub-Content.
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
									if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
									
										# Loop through to get the productID from the content.
										while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
								}
							}
						}
					}
					elsif($tempcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/is)
					{
						while($tempcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $menuurl2 = $1;
							my $menu4 = $2;
							$menuurl2="http://www.ae.com".$menuurl2 if($menuurl2!~m/^http/is);
							my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
							my $test=quotemeta($menu4);
							if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
							{
								my $subcont4 = $1;
								while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
								{
									my $menuurl3 = $1;
									my $menu5 = $2;
									print "Link3=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
									$menuurl3="http://www.ae.com".$menuurl3 if($menuurl3!~m/^http/is);
									my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
									
									# Pattern match to get the categoryID.
									my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
									
									# Pattern match to get the category block based on the category ID.
									if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);

											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);

												# Committing the transaction.												
												$dbobject->commit();
											}
										}
									}
									if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
									
										# Loop through to get the productID from the content.
										while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);

											# Committing the transaction.
											$dbobject->commit();
											
											# Pattern match to get the child productID from the Parent Product.
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = $utilityobject->Trim($1);
												
												# Form the Product URLs' based on the productID.
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												
												# Insert Product_List table based on values collected for the product.
												my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
												
												# Save the Tag Information based on the ProductID and Tag values.
												$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
												$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
												
												# Committing the transaction.
												$dbobject->commit();
											}
										}
									}
								}
							}
							else
							{
								print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
								
								# Pattern match to get the categoryID.
								my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
								
								# Pattern match to get the category block based on the category ID.
								if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
								if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
								
									# Loop through to get the productID from the content.
									while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
							}
						}
					}
				}
				while($tempcont =~ m/<li\s*class\=\"navHeader\s*navCat_cat\d+\s*navCat_[^>]*?emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $menuurl2 = $1;
					my $menu3 = $2;
					$menuurl2="http://www.ae.com".$menuurl2 if($menuurl2!~m/^http/is);
					my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							print "Link5=>$menu1->$menu2->$menu3->$menu4\n";
							$menuurl3="http://www.ae.com".$menuurl3 if($menuurl3!~m/^http/is);
							my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
							
							# Pattern match to get the categoryID.
							my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
							
							# Pattern match to get the category block based on the category ID.
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								# Loop through to get the productID from the content.
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
						}
					}
					else
					{
						print "Link6=>$menu1->$menu2->$menu3\n";
						
						# Pattern match to get the categoryID.
						my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
						
						# Pattern match to get the category block based on the category ID.
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							# Loop through to get the productID from the content.
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);

								# Committing the transaction.								
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}
							}
						}
					}
				}
				if(($tempcont =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"Menu\">([\w\W]*?)<\/ul>/is))
				{
					my $menu3 = $utilityobject->Trim($1);
					my $subcont5 = $2;
					while($subcont5 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
					{
						my $clearurl = $1;
						my $menu4 = $utilityobject->Trim($2);
						$clearurl="http://www.ae.com".$clearurl if($clearurl!~m/^http/is);
						my $subcont6 = $utilityobject->Lwp_Get($clearurl);
						my $test=quotemeta($menu4);
						if($subcont6 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
						{
							my $subcont7 = $1;
							while($subcont7 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
							{
								my $menuurl7 = $1;
								my $menu5 = $2;
								print "Clear=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
								$menuurl7="http://www.ae.com".$menuurl7 if($menuurl7!~m/^http/is);
								my $subcont5 = $utilityobject->Lwp_Get($menuurl7);
								
								# Pattern match to get the categoryID.
								my $catid = $1 if($menuurl7 =~ m/catId\=([^>]*?)$/is);
								
								# Pattern match to get the category block based on the category ID.
								if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
										
										# Pattern match to get the child productID from the Parent Product.
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = $utilityobject->Trim($1);
											
											# Form the Product URLs' based on the productID.
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											
											# Insert Product_List table based on values collected for the product.
											my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
											
											# Save the Tag Information based on the ProductID and Tag values.
											$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
											$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
											
											# Committing the transaction.
											$dbobject->commit();
										}
									}
								}
								# Loop through to get the productID from the content.
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.									
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										
										# Form the Product URLs' based on the productID.
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String); 
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
						}
						else
						{
							print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
							
							# Pattern match to get the categoryID.
							my $catid = $1 if($clearurl =~ m/catId\=([^>]*?)$/is);
							
							# Pattern match to get the category block based on the category ID.
							if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Pattern match to get the child productID from the Parent Product.
									if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = $utilityobject->Trim($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										
										# Insert Product_List table based on values collected for the product.
										my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										
										# Save the Tag Information based on the ProductID and Tag values.
										$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
										$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
										
										# Committing the transaction.
										$dbobject->commit();
									}
								}
							}
							# Loop through to get the productID from the content.
							while($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
								
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);   
								
								# Committing the transaction.
								$dbobject->commit();
								
								# Pattern match to get the child productID from the Parent Product.
								if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = $utilityobject->Trim($1);
									
									# Form the Product URLs' based on the productID.
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									
									# Insert Product_List table based on values collected for the product.
									my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									
									# Save the Tag Information based on the ProductID and Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu2,$menu3,$product_object_key,$robotname,$Retailer_Random_String);
									$dbobject->SaveTag($menu3,$menu4,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
								}							
							}
						}
					}
				}
			}
		}
	}
	elsif($menu_1 =~ m/Jeans/is) 
	{
		while($tempcont0 =~ m/<li>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
		{
			my $caturl2 = $1; 
			my $menu2 = $utilityobject->Trim($2); 
			$caturl2="http://www.ae.com".$caturl2 if($caturl2!~m/^http/is);
			my $menucontent = $utilityobject->Lwp_Get($caturl2); 
			while($menucontent =~ m/class\=\"subFlyoutLink\"\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*</igs) 
			{ 
				my $caturl3 = $1;
				my $menu3 = $utilityobject->Trim($2);
				$caturl3="http://www.ae.com".$caturl3 if($caturl3!~m/^http/is);
				my $menucontent3 = $utilityobject->Lwp_Get($caturl3); 
				print "$menu1 -> $menu2 -> $menu3\n";
				while($menucontent3 =~ m/<div\s*class\=\"sProd\"[^>]*?data\-product\-id\=\"([^>]*?)\"/igs)
				{
					my $pid = $utilityobject->Trim($1);
												
					# Form the Product URLs' based on the productID.
					my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
					
					# Insert Product_List table based on values collected for the product.
					my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
					
					# Save the Tag Information based on the ProductID and Tag values.
					$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
					$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
					$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
					
					# Committing the transaction.
					$dbobject->commit();
				}
			}
		}
	}
	elsif($menu_1 =~ m/Shoes/is)
	{
		my $menucontent = $utilityobject->Lwp_Get($menu1url);
		if($menucontent =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
        { 
            my $tempcont = $1; 
            while($tempcont =~ m/<span[^>]*?class\s*\=\s*\"\s*noLink\s*\"[^>]*?>([^<]*?)<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>\s*<\/ul>\s*<\/li>/igs)
			{
				my $menu2= $utilityobject->Trim($1);
				my $menu2_blk = $&;
				while($menu2_blk =~ m/>\s*([^>]*?)\s*<\/span>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/igs)
				{
					my $menu3 = $utilityobject->Trim($1);
					my $menu3_blk = $&;
					# print $menu3_blk,"\n";
					while($menu3_blk =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
					{
						my $caturl2 = $1;
						my $menu4 = $utilityobject->Trim($2);
						$caturl2="http://www.ae.com".$caturl2 if($caturl2!~m/^http/is);
						my $menucontent2 = $utilityobject->Lwp_Get($caturl2); 
						my $catid = $1 if($caturl2 =~ m/catId\=([^>]*?)$/is);
						if($menucontent2 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							print "$menu1 -> $menu2 -> $menu3 -> $menu4\n";
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
												
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit();
							}
						}
						else
						{
							while($menucontent2 =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = $utilityobject->Trim($1);
												
								# Form the Product URLs' based on the productID.
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								
								# Insert Product_List table based on values collected for the product.
								my $product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
								
								# Save the Tag Information based on the ProductID and Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String);
								$dbobject->SaveTag('Menu_4',$menu4,$product_object_key,$robotname,$Retailer_Random_String);
								
								# Committing the transaction.
								$dbobject->commit(); 
							}
						}
					}
				}
			}				
		}
	}
}
# To indicate script has completed in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);

# Once script has complete send a msg to logger.
$logger->send("$robotname :: Instance Completed  :: $pid\n");

# Committing the transaction.
$dbobject->commit();
