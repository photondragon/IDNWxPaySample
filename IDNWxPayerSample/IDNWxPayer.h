//
//  IDNWxPayer.h
//  IDNWxPayer
//
//  Created by photondragon on 16/5/27.
//  Copyright © 2016年 iosdev.net. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 微信支付助手

 使用教程 <http://blog.iosdev.net/articles/201606/ios-wei-xin-zhi-fu-zhu-shou-idnwxpayer/>
 demo示例程序 <https://github.com/photondragon/IDNWxPaySample>
*/
@interface IDNWxPayer : NSObject

#pragma mark - 核心方法

/**
 *  初始化。在程序启动后调用一次即可
 *
 *  @param appId      应用ID
 *  @param merchantId 商户ID（也叫partnerId）
 */
+ (void)initWithAppId:(NSString*)appId merchantId:(NSString*)merchantId;

/**
 *  需要在 application:openURL:sourceApplication:annotation:或者application:openURL:options:中调用。
 *
 *  @param url
 *  @return 如果传入的url微信可以处理，返回YES，否则返回NO
 */
+ (BOOL)handleOpenURL:(NSURL *)url;

/**
 *  发起支付（打开微信客户端）
 *
 *  支付参数payParams示例：
 *  {
 *      prepayid = wx201605280911382a08054e2f0596771345;
 *      appid = wx1234567812345678;
 *      partnerid = 1234567890;
 *      package = "Sign=WXPay";
 *      timestamp = 1464376304;
 *      noncestr = 0D659B433A5783183362F50EE819C66D;
 *      sign = 2192F3AAC8F881DA73F4BC7E1E772EB7;
 *  }
 *  @param payParams 支付参数，一般由你的服务端生成。必须包含以下字段：appid, partnerid,
 *    prepayid, package, noncestr, timestamp, sign
 *  @param result    接收支付结果的block，error==nil表示支付成功，否则表示支付失败。
 *    这个block不一定会被调用，因为我有可能在切换到微信客户端后直接关闭微信，然后再手动打开
 *    自己的应用，而不是让微信自动跳回自己的应用。
 *  @return 如果成功打开微信客户端，返回TRUE；否则返回FALSE
 *
 *  当函数返回TRUE时，应该显示一个界面，询问用户是否完成付款，就像支付宝付款时切换到另一个页面，
 *  你再手动切换回原来页面，你会发现原来的界面会有个对话框询问你付款是否完成，一般有两个选项：
 *  1. 已完成付款；2. 关闭
 *  如果result被调用，要在result中自动关闭这个界面；如果result没有被调用时，
 *  这个界面就一直显示在那，直到用户做出选择时才关闭。如果用户选择“已完成付款”，应该立即去你自
 *  己的服务器上去检测订单是否已支付，如果用户选“关闭”，那么就直接关闭这个界面。
 */
+ (BOOL)payWithParams:(NSDictionary*)payParams result:(void (^)(NSError* error))result;

#pragma mark - 不安全操作（需要在客户端设置商户密钥，仅供测试使用）

// 设置商户密钥（用于签名）。在客户端保存商户密钥是不安全的，建议只保存在服务端，在服务端签名
+ (void)setMerchantKey:(NSString*)merchantKey;

// 设置接收微信支付异步通知的URL地址。向微信下单时需要用到这个参数
+ (void)setNotifyUrl:(NSString*)notifyUrl;

/**
 *  发起支付
 *  必须先设置merchantKey
 *
 *  @param prepayId 预支付ID。一般由服务端下单，得到prepayId，再传给客户端
 *  @param result   接收支付结果的block，error==nil表示支付成功，否则表示支付失败。
 *    这个block不一定会被调用，因为我有可能在切换到微信客户端后直接关闭微信，然后再手动打开
 *    自己的应用，而不是让微信自动跳回自己的应用。
 *  @return 如果成功打开微信客户端，返回TRUE；否则返回FALSE
 */
+ (BOOL)payWithPrepayId:(NSString*)prepayId result:(void (^)(NSError* error))result;

/**
 *  向微信服务器下单，获取prepayid，然后生成支付参数和签名的字典
 *  必须先设置notifyUrl和merchantKey
 *
 *  @param orderId     你的应用的订单ID（必填）
 *  @param amount      订单金额，单位分（必填）
 *  @param orderTitle  订单标题（必填）
 *  @param orderDetail 订单详情（可选）
 *  @param callback    接收下单结果的block。如果下单成功，参数payParams是包含支付参数和签名的字典，error==nil；如果失败，error中包含错误信息
 */
+ (void)prepayWithOrderId:(NSString*)orderId
				   amount:(NSInteger)amount
			   orderTitle:(NSString*)orderTitle
			  orderDetail:(NSString*)orderDetail
				 callback:(void (^)(NSDictionary* payParams, NSError* error))callback;

@end
