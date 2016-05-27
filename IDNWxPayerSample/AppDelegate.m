//
//  AppDelegate.m
//  IDNWxPayerSample
//
//  Created by photondragon on 16/5/28.
//  Copyright © 2016年 iosdev.net. All rights reserved.
//

#import "AppDelegate.h"
#import "IDNWxPayer.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	[IDNWxPayer initWithAppId:@"wx1234567812345678" merchantId:@"1234567890"]; //
	[IDNWxPayer setMerchantKey:@"12345678901234567890123456789012"]; //设置商户密钥，仅供测试使用
	[IDNWxPayer setNotifyUrl:@"http://weixin.app.example.com/index.php"]; //仅供测试使用
	return YES;
}

// ios<9.0
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	if([IDNWxPayer handleOpenURL:url])
		return YES;
	return NO;
}

// ios>=9.0
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
	if([IDNWxPayer handleOpenURL:url])
		return YES;
	return NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
