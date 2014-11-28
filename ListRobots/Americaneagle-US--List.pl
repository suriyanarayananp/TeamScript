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
my $cont = $utilityobject->Lwp_Get($url);
while($cont =~ m/<a\s*class\=\"inline\-block\-middle\s*site\-top\-link\s*[^>]*?href\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>\s*<\/div>/igs)
{
	my $menu1 = $1;  ##Women
	my $mcont = $2;
	# next unless($menu1 =~ m/\bClearance\b/is);
	
	while($mcont =~ m/<ul\s*class\=\"nav\-column\s*inline\-block\-top[^>]*?>\s*<li>(?:<strong>\s*<a\s*href[^>]*?>|<em>|<strong>\s*<a[^>]*?>\s*<span>)?\s*([^>]*?)\s*<([\w\W]*?)(?:<\/li>\s*<\/ul>|<\/li>\s*<li>)/igs)
	{
		my $menu2 = $1;  ## Featured
		my $m2cont = $2;
		# next unless($menu2 =~ m/Bottoms/is);
		print "L1 -> $menu1->$menu2\n";
		while($m2cont =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
		{				
			my $menuurl2 = $1;
			my $menu3 = $2;  ## New Arrivals
			$menuurl2="http://www.ae.com".$menuurl2 if($menuurl2!~m/^http/is);
			my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
			my $test=quotemeta($menu3);
			print "L1 -> $menu1->$menu2->$menu3\n";
			# next unless($menu3 =~ m/socks/is);
			# Check if menu3 having sub-block, it should consider as menu4 [Menu3 :: New Arrivals].
			if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"(?:subMenu|Menu)\">([\w\W]*?)<\/ul>/is)
			{
				my $subcont4 = $1;
				# print "Im getting New arrivals block \n";
				# exit;
				# Getting the product page URLs from the block.
				while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $menuurl3 = $1;
					my $menu4 = $2;
					my $test=quotemeta($menu4);
					print "L1 -> $menu1->$menu2->$menu3->$menu4\n";
					my $subcont5 = $utilityobject->Lwp_Get($menuurl3);
					
					# Check if menu3 having sub-block, it should consider as menu4 [Menu3 :: New Arrivals].
					if($subcont5 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"(?:subMenu|Menu)\">([\w\W]*?)<\/ul>/is and $menu2 !~ m/Featured/is)
					{
						my $subcont5block = $1;
						# print "Im getting New arrivals block \n";
						# exit;
						# Getting the product page URLs from the block.
						while($subcont5block =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $menuurl4 = $1;
							my $menu5 = $2;
							# my $test=quotemeta($menu4);
							print "L1 -> $menu1->$menu2->$menu3->$menu4 -> $menu5\n";
							
							my $subcont6 = $utilityobject->Lwp_Get($menuurl3);
							
							# Pattern match to get the category ID.
							my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
							
							# Pattern match to get the block based on the category ID.
							if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
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
									$dbobject->SaveTag($menu4,$menu5,$product_object_key,$robotname,$Retailer_Random_String);
									
									# Committing the transaction.
									$dbobject->commit();
									
									# Whether the product page URLs having bundle products.
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
							
							# Pattern match to getting the productIDs' from the sub content.
							if($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								# pattern match to collecting the productID.
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
									
									# Collecting the bundle product based on the ProductIDs.
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
					else
					{
						print "ELse in Menu4 -> $menu1->$menu2->$menu3->$menu4\n";
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
			}
			else
			{
				print "L2 -> $menu1->$menu2->$menu3\n";
				
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
					while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"|\"prdId\"\:\"([^\:]*?)\"\,\"prdName\"\:\"/igs)
					{
						my $pid = $utilityobject->Trim($1.$2);
						print $pid,"\n";
						
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
	
	while($mcont =~ m/<strong>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>\s*<\/strong>\s*<\/li>\s*(?:<li>|<\/ul>)/igs)
	{
		my $menuurl2 = $1;
		my $menu2 = $2;  ## Dresses
		$menuurl2="http://www.ae.com".$menuurl2 if($menuurl2!~m/^http/is);
		my $subcont3 = $utilityobject->Lwp_Get($menuurl2);
		my $test = quotemeta($menu2);
		if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*(?:<[^>]*?\s*>*)?<ul\s*class\=\"(?:subMenu|Menu)\">([\w\W]*?)<\/ul>/is)
		{
			my $subcont4 = $1;
			# print "Im getting New arrivals block \n";
			# exit;
			# Getting the product page URLs from the block.
			while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
			{
				my $menuurl3 = $1;
				my $menu3 = $2;
				my $test = quotemeta($menu3);
				$menuurl3="http://www.ae.com".$menuurl3 if($menuurl3 !~ m/^http/is);
				my $subcont6 = $utilityobject->Lwp_Get($menuurl3);
				
				if($subcont6 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*(?:<ul\s*class\=\"(?:subMenu|Menu)\">|<\/li>\s*<ul>\s*<li\s*class\=\"\">)([\w\W]*?)<\/ul>/is)
				{
					my $subcont6blk = $1;
					while($subcont6blk =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
					{
						my $menuurl4 = $1;
						my $menu4 = $2;
						my $test = quotemeta($menu4);
						print "L1 -> $menu1->$menu2->$menu3->$menu4\n";
						$menuurl4="http://www.ae.com".$menuurl4 if($menuurl4 !~ m/^http/is);
						my $subcont7 = $utilityobject->Lwp_Get($menuurl4);
					
						# Pattern match to get the category ID.
						my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
						
						my @cats;
						if($subcont7 =~ m/\"displayCategoryIds\"\:\[([^>]*?)\]/is)
						{
							my $displaycat = $1;
							$displaycat =~ s/\"//igs;
							print $displaycat,"\n\n";
							@cats = split(/\,/, $displaycat);
						}
						print "CATS ::  @cats\n";
						foreach (@cats)
						{
							$catid = $_;
							# Pattern match to get the block based on the category ID.
							if($subcont7 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
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
									if($subcont7 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
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
							if($subcont7 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								# pattern match to collecting the productID.
								while($subcont7 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
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
									if($subcont7 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
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
				else
				{
					
					print "L1 -> $menu1->$menu2->$menu3\n";
					# Pattern match to get the category ID.
					my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
					
					# Pattern match to get the block based on the category ID.
					if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
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
							
							# Committing the transaction.
							$dbobject->commit();
							
							# Whether the product page URLs having bundle products.
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
								
								# Committing the transaction.
								$dbobject->commit();
							}
						}
					}
					
					# Pattern match to getting the productIDs' from the sub content.
					if($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
					{
						# pattern match to collecting the productID.
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
							
							# Committing the transaction.
							$dbobject->commit();
							
							# Collecting the bundle product based on the ProductIDs.
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
