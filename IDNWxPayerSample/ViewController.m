//
//  ViewController.m
//  IDNWxPayerSample
//
//  Created by photondragon on 16/5/28.
//  Copyright © 2016年 iosdev.net. All rights reserved.
//

#import "ViewController.h"
#import "IDNWxPayer.h"

@interface ViewController ()
<UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textFieldPrepayId;
@property (weak, nonatomic) IBOutlet UITextView *textViewPayParams;
@property(nonatomic,strong) NSDictionary* payParams;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	self.textFieldPrepayId.delegate = self;
}

// 客户端下单
- (IBAction)onClientPrepay:(id)sender {
	NSString* orderId = @"20160526112848";
	NSInteger amount = 1; //金额
	NSString* orderTitle = @"充值余额";

	[IDNWxPayer prepayWithOrderId:orderId amount:amount orderTitle:orderTitle orderDetail:nil callback:^(NSDictionary *payParams, NSError *error) {
		if(error){
			NSLog(@"下单失败：%@", error.localizedDescription);
			self.textFieldPrepayId.text = nil;
			self.textViewPayParams.text = nil;
			self.payParams = nil;
			[self alert:[NSString stringWithFormat:@"下单失败：%@", error.localizedDescription]];
		}
		else{
			NSLog(@"下单成功：%@", payParams);
			self.textFieldPrepayId.text = payParams[@"prepayid"];
			self.textViewPayParams.text = [payParams description];
			self.payParams = payParams;
			[self alert:@"支付成功"];
		}
	}];
}

- (IBAction)onPayWithPrepayId:(id)sender {
	NSString* prepayId = self.textFieldPrepayId.text;
	if(prepayId.length==0)
	{
		[self alert:@"没有prepayId参数，请先下单"];
		return;
//		prepayId = @"wx201605280911382a08054e2f0596771345";
	}
	else if(prepayId.length!=36){
		[self alert:@"prepayid长度必须是36"];
		return;
	}
	[IDNWxPayer payWithPrepayId:prepayId result:^(NSError *error) {
		if(error){
			NSLog(@"支付失败：%@", error.localizedDescription);
			[self alert:[NSString stringWithFormat:@"支付失败：%@", error.localizedDescription]];
		}
		else{
			NSLog(@"支付成功");
			[self alert:@"支付成功"];
		}
	}];
}

- (IBAction)onPayWithParams:(id)sender {
	NSDictionary* payParams = self.payParams;
	if(payParams.count==0)
	{
		[self alert:@"没有payParams参数，请先下单"];
		return;
//		NSMutableDictionary* params = [NSMutableDictionary new];
//		params[@"prepayid"] = @"wx201605280911382a08054e2f0596771345";
//		params[@"appid"] = @"wx1234567812345678";
//		params[@"partnerid"] = @"1234567890";
//		params[@"package"] = @"Sign=WXPay";
//		params[@"timestamp"] = @"1464376304";
//		params[@"noncestr"] = @"0D659B433A5783183362F50EE819C66D";
//		params[@"sign"] = @"2192F3AAC8F881DA73F4BC7E1E772EB7";

//		payParams = [params copy];
	}
	[IDNWxPayer payWithParams:payParams result:^(NSError *error) {
		if(error){
			NSLog(@"支付失败：%@", error.localizedDescription);
			[self alert:[NSString stringWithFormat:@"支付失败：%@", error.localizedDescription]];
		}
		else{
			NSLog(@"支付成功");
			[self alert:@"支付成功"];
		}
	}];

}

- (IBAction)onTapBlank:(id)sender {
	[self.textFieldPrepayId resignFirstResponder];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	self.payParams = nil;
	self.textViewPayParams.text = nil;
	return YES;
}

- (void)alert:(NSString*)msg
{
	UIAlertController* c = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction* a = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {}];
	[c addAction:a];
	[self presentViewController:c animated:YES completion:nil];
}

@end
