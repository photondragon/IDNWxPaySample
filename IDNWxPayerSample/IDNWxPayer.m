//
//  IDNWxPayer.m
//  IDNWxPayer
//
//  Created by photondragon on 16/5/27.
//  Copyright © 2016年 iosdev.net. All rights reserved.
//

#import "IDNWxPayer.h"
#import <UIKit/UIKit.h>
#import "WXApi.h"
#import <CommonCrypto/CommonDigest.h>

#pragma mark - 简易Xml解析器

@interface IDNWxPayXmlParser : NSObject
<NSXMLParserDelegate>
{
	NSXMLParser* xmlParser;
	NSMutableString* valBuffer;
	NSMutableDictionary* dictionary;
	NSError* lastError;
}
@end

@implementation IDNWxPayXmlParser

+ (NSDictionary*)parseData:(NSData*)data
{
	IDNWxPayXmlParser* parser = [[IDNWxPayXmlParser alloc] init];
	return [parser parseData:data];
}

- (NSDictionary*)parseData:(NSData*)data
{
	lastError = nil;
	dictionary = [NSMutableDictionary new];
	valBuffer = [NSMutableString string];
	xmlParser = [[NSXMLParser alloc] initWithData:data];
	[xmlParser setDelegate:self];
	[xmlParser parse];
	if(lastError)
		return nil;
	return [dictionary copy];
}

- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)string{
	[valBuffer setString:string];
}

- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)elementName namespaceURI:(NSString*)namespaceURI qualifiedName:(NSString*)qName{
	if([valBuffer isEqualToString:@"\n"]==NO &&
	   [elementName isEqualToString:@"root"]==NO)
	{
		[dictionary setObject:[valBuffer copy] forKey:elementName];
	}
}

- (void)parser:(NSXMLParser*)parser parseErrorOccurred:(NSError*)parseError
{
	lastError = parseError;
}

- (void)parser:(NSXMLParser*)parser validationErrorOccurred:(NSError*)validationError
{
	lastError = validationError;
}

@end

#pragma mark - 微信支付助手

//统一下单Url，用于生成prepayId
#define UnifiedOrderUrl @"https://api.mch.weixin.qq.com/pay/unifiedorder"

@interface IDNWxPayer()

@property(nonatomic,strong) NSString* appId; //应用ID
@property(nonatomic,strong) NSString* merchantId; //商户ID

@property(nonatomic,strong) NSString* merchantKey; //商户密钥，只用于生成签名。从安全角度来说，签名应该由服务端来做，再将包含签名的完整支付参数传送至客户端，由客户端发起支付。
@property(nonatomic,strong) NSString* notifyUrl; //接收微信支付异步通知回调地址，只在下单时用到

@property(nonatomic,strong) void (^currentCallback)(NSError*error); //当前支付的回调block

@end

@implementation IDNWxPayer

+ (instancetype)sharedInstance
{
	static id sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

- (void)onFailureCallCallback:(void (^)(NSError* error))callback errorString:(NSString*)errorString
{
	if(errorString.length==0)
		errorString = @"未知错误";

	NSError* error = [NSError errorWithDomain:NSStringFromClass(self.class) code:0 userInfo:@{NSLocalizedDescriptionKey:errorString}];

	[self callCallback:callback error:error];
}

- (void)callCallback:(void (^)(NSError* error))callback error:(NSError*)error
{
	if(callback==nil)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		callback(error);
	});
}

- (void)onFailureCallPrepayCallback:(void (^)(NSDictionary* payParams, NSError* error))callback payParams:(NSDictionary*)payParams errorString:(NSString*)errorString
{
	if(errorString.length==0)
		errorString = @"未知错误";

	NSError* error = [NSError errorWithDomain:NSStringFromClass(self.class) code:0 userInfo:@{NSLocalizedDescriptionKey:errorString}];

	[self callPrepayCallback:callback payParams:payParams error:error];
}

- (void)callPrepayCallback:(void (^)(NSDictionary* payParams, NSError* error))callback payParams:(NSDictionary*)payParams error:(NSError*)error
{
	if(callback==nil)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		callback(payParams, error);
	});
}

- (NSString*)md5:(NSString*)str
{
	const char* cStr = [str UTF8String];
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5(cStr, (unsigned int)strlen(cStr), digest);

	NSMutableString* output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
		[output appendFormat:@"%02X", digest[i]];

	return output;
}

- (void)post:(NSString*)url xml:(NSString*)xml callback:(void (^)(NSData* data, NSError* error))callback
{
	if(callback==nil)
		return;
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
	[request setHTTPMethod:@"POST"];
	[request addValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
	[request setValue:@"UTF-8" forHTTPHeaderField:@"charset"];
	[request setHTTPBody:[xml dataUsingEncoding:NSUTF8StringEncoding]];

	NSURLSessionDataTask * dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if(error)
			callback(nil, error);
		else if(data.length==0)
			callback(nil, [NSError errorWithDomain:NSStringFromClass(self.class) code:0 userInfo:@{NSLocalizedDescriptionKey:@"返回数据长度为0"}]);
		if(data.length)
			callback(data, nil);
	}];

	[dataTask resume] ; // 开始
}

#pragma mark - 核心方法

+ (void)initWithAppId:(NSString*)appId merchantId:(NSString*)merchantId
{
	IDNWxPayer* payer = [self sharedInstance];
	payer.appId = appId;
	payer.merchantId = merchantId;

	[WXApi registerApp:appId];
}

+ (BOOL)handleOpenURL:(NSURL*)url
{
	return [WXApi handleOpenURL:url delegate:[self sharedInstance]];
}

+ (BOOL)payWithParams:(NSDictionary*)params result:(void (^)(NSError* error))result
{
	return [[self sharedInstance] payWithParams:params result:result];
}

- (BOOL)payWithParams:(NSDictionary*)params result:(void (^)(NSError* error))result
{
	if (params.count == 0){
		[self onFailureCallCallback:result errorString:@"没有提供支付参数"];
		return FALSE;
	}

	if([WXApi isWXAppInstalled]==NO){
		[self onFailureCallCallback:result errorString:@"没有安装微信客户端"];
		return FALSE;
	}

	@synchronized (self) {
		// 不用管之前有没有回调
//		if(_currentCallback) //之前的支付没有返回
//		{
//			[self onFailureCallCallback:_currentCallback errorString:@"微信支付没有返回"];
//			//return; //不用退出，继续
//		}

		_currentCallback = result;
	}

	// 生成支付请求
	PayReq* request = [[PayReq alloc] init];
	request.prepayId = params[@"prepayid"];
	request.openID = params[@"appid"];
	request.partnerId = params[@"partnerid"]; //商户ID
	request.package = params[@"package"];
	request.timeStamp = (UInt32)[params[@"timestamp"] integerValue];
	request.nonceStr = params[@"noncestr"];
	request.sign= params[@"sign"];
	if([WXApi sendReq:request]==NO){
		[self onFailureCallCallback:result errorString:@"发起支付失败"];
		return FALSE;
	}
	return TRUE;
}

#pragma mark - WXApiDelegate

- (void)onResp:(BaseResp*)resp
{
	if([resp isKindOfClass:[PayResp class]]==NO){
		return;
	}

	NSString* errorString = nil;
	switch (resp.errCode) {
		case WXSuccess:
			break;
		case WXErrCodeUserCancel:
			errorString = @"用户取消付款";
			break;
		case WXErrCodeCommon:
			errorString = @"普通错误类型";
			break;
		case WXErrCodeSentFail:
			errorString = @"发送失败";
			break;
		case WXErrCodeAuthDeny:
			errorString = @"授权失败";
			break;
		case WXErrCodeUnsupport:
			errorString = @"微信不支持";
			break;
		default:
			errorString = [NSString stringWithFormat:@"支付失败！errCode = %d, errStr = %@", resp.errCode,resp.errStr];
			break;
	}

	NSError* error = nil;
	if(errorString.length)
	{
		error = [NSError errorWithDomain:NSStringFromClass(self.class) code:0 userInfo:@{NSLocalizedDescriptionKey:errorString}];
	}

	@synchronized (self) {
		if(_currentCallback)
		{
			[self callCallback:_currentCallback error:error];
			_currentCallback = nil;
		}
	}
}

#pragma mark - 不安全（仅供测试使用）

+ (void)setMerchantKey:(NSString*)merchantKey
{
	IDNWxPayer* payer = [self sharedInstance];
	payer.merchantKey = merchantKey;
}

+ (void)setNotifyUrl:(NSString*)notifyUrl
{
	IDNWxPayer* payer = [self sharedInstance];
	payer.notifyUrl = notifyUrl;
}

+ (void)prepayWithOrderId:(NSString*)orderId
				   amount:(NSInteger)amount
			   orderTitle:(NSString*)orderTitle
			  orderDetail:(NSString*)orderDetail
				 callback:(void (^)(NSDictionary* payParams, NSError* error))callback
{
	[[self sharedInstance] prepayWithOrderId:orderId amount:amount orderTitle:orderTitle orderDetail:orderDetail callback:callback];
}

- (void)prepayWithOrderId:(NSString*)orderId
				   amount:(NSInteger)amount
			   orderTitle:(NSString*)orderTitle
			  orderDetail:(NSString*)orderDetail
				 callback:(void (^)(NSDictionary* payParams, NSError* error))callback
{
	if(_notifyUrl.length==0)
	{
		[self onFailureCallPrepayCallback:callback payParams:nil errorString:@"必须先设置notifyUrl"];
		return;
	}

	if(amount<=0)
	{
		[self onFailureCallPrepayCallback:callback payParams:nil errorString:@"订单金额必须大于0"];
		return;
	}

	if(orderId.length==0)
	{
		[self onFailureCallPrepayCallback:callback payParams:nil errorString:@"没有提供订单ID"];
		return;
	}
	if(orderTitle.length==0)
		orderTitle = @"测试订单001";

	time_t now;
	time(&now);
	NSString* timeStamp = [NSString stringWithFormat:@"%ld", now];
	NSString* nonceStr = [self md5:timeStamp]; //生成随机字符串

	NSMutableDictionary* prepayParams = [NSMutableDictionary new];

	prepayParams[@"appid"] = _appId;
	prepayParams[@"mch_id"] = _merchantId;
//	prepayParams[@"device_info"] = @"WEB"; //非必需。终端设备号(门店号或收银设备ID)，默认请传"WEB"
	prepayParams[@"nonce_str"] = nonceStr;
	prepayParams[@"body"] = orderTitle;
	if(orderDetail.length)
		prepayParams[@"detail"] = orderDetail;
	prepayParams[@"out_trade_no"] = orderId;
	prepayParams[@"total_fee"] = [@(amount) description];
	prepayParams[@"spbill_create_ip"] = @"0.0.0.0"; //用户端实际ip
	prepayParams[@"notify_url"] = _notifyUrl;
	prepayParams[@"trade_type"] = @"APP";
//	prepayParams[@"limit_pay"] = @"no_credit"; //非必需。no_credit--指定不能使用信用卡支付

	prepayParams[@"sign"] = [self signWithParams:prepayParams]; //生成签名

	NSString* xml = [self getXmlFromParams:prepayParams];

	__weak __typeof(self) wself = self;
	[self post:UnifiedOrderUrl xml:xml callback:^(NSData *data, NSError *error) {
		__typeof(self) sself = wself;
		if(error)
			[self callPrepayCallback:callback payParams:nil error:error];
		else{
			NSDictionary* respParams = [IDNWxPayXmlParser parseData:data];
			[sself receiveUnifiedOrderResponse:respParams callback:callback];
		}
	}];
}

- (void)receiveUnifiedOrderResponse:(NSDictionary*)respParams callback:(void (^)(NSDictionary* payParams, NSError* error))callback
{
	NSString* return_code   = [respParams objectForKey:@"return_code"];
	NSString* result_code   = [respParams objectForKey:@"result_code"];
	NSString* errorString = nil;
	if([return_code isEqualToString:@"SUCCESS"])
	{
		NSString* sign = [self signWithParams:respParams ]; // 计算签名
		NSString* send_sign =[respParams objectForKey:@"sign"] ;

		if([sign isEqualToString:send_sign]) //验证签名正确性
		{
			if([result_code isEqualToString:@"SUCCESS"])
			{
				NSString* prepayId = respParams[@"prepay_id"];
				if(prepayId.length==0)
					errorString = @"微信服务器返回成功但却没有返回prepayid";
				else{
					NSDictionary* payParams = [self genPayParamsWithPrepayId:prepayId];
					[self callPrepayCallback:callback payParams:payParams error:nil];
					return; //成功返回
				}
			}
			else
			{
				errorString = respParams[@"err_code_des"];
				if(errorString.length==0)
					errorString = [NSString stringWithFormat:@"错误码：%@", respParams[@"err_code"]];
			}
		}
		else
			errorString = @"服务器返回签名验证错误";
	}
	else
		errorString = @"服务器接口返回错误";

	[self onFailureCallPrepayCallback:callback payParams:nil errorString:errorString];
}

//生成请求参数
- (NSDictionary*)genPayParamsWithPrepayId:(NSString*)prepayId
{
	if (prepayId.length == 0)
		return nil;

	time_t now;
	time(&now);
	NSString* timeStamp = [NSString stringWithFormat:@"%ld", now];
	NSString* nonce_str = [self md5:timeStamp]; //生成随机字符串

	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	params[@"prepayid"] = prepayId;
	params[@"appid"] = _appId;
	params[@"partnerid"] = _merchantId;
	params[@"package"] = @"Sign=WXPay";
	params[@"timestamp"] = timeStamp;
	params[@"noncestr"] = nonce_str;

	params[@"sign"] = [self signWithParams:params]; // 加上参数签名

	return [params copy];
}

+ (BOOL)payWithPrepayId:(NSString*)prepayId result:(void (^)(NSError* error))result
{
	return [[self sharedInstance] payWithPrepayId:prepayId result:result];
}
- (BOOL)payWithPrepayId:(NSString*)prepayId result:(void (^)(NSError* error))result
{
	if (prepayId.length == 0)
	{
		[self onFailureCallCallback:result errorString:@"没有提供prepayId"];
		return FALSE;
	}

	NSDictionary* params = [self genPayParamsWithPrepayId:prepayId];

	return [self payWithParams:params result:result];
}

// 根据参数生成带sign的xml字符串（做为HTTP POST请求的body）
-(NSString*)getXmlFromParams:(NSMutableDictionary*)packageParams
{
	NSString* sign = [self signWithParams:packageParams];
	//生成xml的package
	NSMutableString* reqPars=[NSMutableString string];
	NSArray* keys = [packageParams allKeys];
	[reqPars appendString:@"<xml>\n"];
	for (NSString* categoryId in keys) {
		[reqPars appendFormat:@"<%@>%@</%@>\n", categoryId, [packageParams objectForKey:categoryId],categoryId];
	}
	[reqPars appendFormat:@"<sign>%@</sign>\n</xml>", sign];

	return [NSString stringWithString:reqPars];
}

// 根据参数生成签名
- (NSString*)signWithParams:(NSDictionary*)params
{
	if(_merchantKey.length==0){
		NSLog(@"没有设置商户密钥");
		return nil;
	}

	NSMutableString* contentString  =[NSMutableString string];

	NSArray* keys = [params allKeys];
	//按字母顺序排序
	NSArray* sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [obj1 compare:obj2 options:NSNumericSearch];
	}];

	//拼接字符串
	for (NSString* key in sortedKeys) {
		if (![[params[key] description] isEqualToString:@""] && //忽略值为空的参数
			![key isEqualToString:@"sign"] && //忽略sign参数
			![key isEqualToString:@"key"]) //忽略key参数
		{
			[contentString appendFormat:@"%@=%@&", key, params[key]];
		}
	}

	[contentString appendFormat:@"key=%@", _merchantKey]; //添加key字段
	NSString* md5Sign =[self md5:contentString]; //返回的MD5值已经是大写了
	
	return md5Sign;
}

@end
