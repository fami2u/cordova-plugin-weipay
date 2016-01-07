/********* weipayPlugin.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import "getIPhoneIP.h"
#import "DataMD5.h"
#import "XMLDictionary.h"
#import "AFNetworking.h"
#import <CommonCrypto/CommonDigest.h>
#import "WXApi.h"

@interface weipayPlugin : CDVPlugin

@property(nonatomic,strong)NSString *partner;
@property(nonatomic,strong)NSString *seller;
@property(nonatomic,strong)NSString *privateKey;
@property(nonatomic,strong)NSString *currentCallbackId;

- (void)pay:(CDVInvokedUrlCommand*)command;
@end

@implementation weipayPlugin
-(void)pluginInitialize{
    CDVViewController *viewController = (CDVViewController *)self.viewController;
    self.partner = [viewController.settings objectForKey:@"app_id"];
    self.seller = [viewController.settings objectForKey:@"seller"];
    self.privateKey = [viewController.settings objectForKey:@"private_key"];
    
}

- (void)pay:(CDVInvokedUrlCommand*)command
{

    self.currentCallbackId = command.callbackId;
    
    
    NSMutableDictionary *args = [command argumentAtIndex:0];
    NSString   *tradeId  = [args objectForKey:@"tradeNo"];
    NSString   *body     = [args objectForKey:@"body"];
    NSString   *price    = [args objectForKey:@"price"];
    NSString   *notifyUrl    = [args objectForKey:@"notifyUrl"];
    NSString * trade_type = @"APP";
    
    
    
    //随机生成字符串
    NSString * nonce_str = [self generateTradeNO];
    
    //订单号，目前先随机生成，后期自行传值
    //获取本机IP地址，请再wifi环境下测试，否则获取的ip地址为error，正确格式应该是8.8.8.8
    NSString * spbill_create_ip = @"8.8.8.8";
    
    //获取sign签名
    DataMD5 *data = [[DataMD5 alloc]initWithAppid:self.partner mch_id:self.seller nonce_str:nonce_str partner_id:self.privateKey body:body out_trade_no:tradeId total_fee:price spbill_create_ip:spbill_create_ip notify_url:notifyUrl trade_type:trade_type];
    
    NSString * sign = [data getSignForMD5];
    
    //设置参数并转化成xml格式
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setValue:self.partner forKey:@"appid"];//公众账号ID
    [dic setValue:self.seller forKey:@"mch_id"];//商户号
    [dic setValue:nonce_str forKey:@"nonce_str"];//随机字符串
    [dic setValue:sign forKey:@"sign"];//签名
    [dic setValue:body forKey:@"body"];//商品描述
    [dic setValue:tradeId forKey:@"out_trade_no"];//订单号
    [dic setValue:price forKey:@"total_fee"];//金额
    [dic setValue:spbill_create_ip forKey:@"spbill_create_ip"];//终端IP
    [dic setValue:notifyUrl forKey:@"notify_url"];//通知地址
    [dic setValue:trade_type forKey:@"trade_type"];//交易类型
    
    NSString *string = [dic XMLString];
    [self http:string];
    

}


//随机生成字符串
- (NSString *)generateTradeNO{
    
    static int kNumber = 15;
    
    NSString *sourceStr = @"0123456789ABCDEFGHIJKLMNOPQRST";
    NSMutableString *resultStr = [[NSMutableString alloc] init];
    srand(time(0));
    for (int i = 0; i < kNumber; i++)
    {
        unsigned index = rand() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }
    return resultStr;
    
    
    
}


//将订单号使用md5加密
-(NSString *) md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char result[16]= "0123456789abcdef";
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}



//调起支付
- (void)http:(NSString *)xml{
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    //这里传入的xml字符串只是形似xml，但是不是正确是xml格式，需要使用af方法进行转义
    manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    [manager.requestSerializer setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:@"https://api.mch.weixin.qq.com/pay/unifiedorder" forHTTPHeaderField:@"SOAPAction"];
    [manager.requestSerializer setQueryStringSerializationWithBlock:^NSString *(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error) {
        return xml;
    }];
    //发起请求
    [manager POST:@"https://api.mch.weixin.qq.com/pay/unifiedorder" parameters:xml success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding] ;
        NSLog(@"responseString is %@",responseString);
        //将微信返回的xml数据解析转义成字典
        NSDictionary *dic = [NSDictionary dictionaryWithXMLString:responseString];
        //判断返回的许可
        if ([[dic objectForKey:@"result_code"] isEqualToString:@"SUCCESS"] &&[[dic objectForKey:@"return_code"] isEqualToString:@"SUCCESS"] ) {
            
            
            //发起微信支付，设置参数
            PayReq *request = [[PayReq alloc] init];
            request.partnerId = [dic objectForKey:@"mch_id"];
            request.prepayId= [dic objectForKey:@"prepay_id"];
            request.package = @"Sign=WXPay";
            request.nonceStr= [dic objectForKey:@"nonce_str"];
            //将当前时间转化成时间戳
            NSDate *datenow = [NSDate date];
            NSString *timeSp = [NSString stringWithFormat:@"%ld", (long)[datenow timeIntervalSince1970]];
            UInt32 timeStamp =[timeSp intValue];
            request.timeStamp= timeStamp;
            DataMD5 *md5 = [[DataMD5 alloc] init];
           request.sign = [md5 createMD5SingForPay:self.partner partnerid:request.partnerId prepayid:request.prepayId package:request.package noncestr:request.nonceStr timestamp:request.timeStamp partnerkey:self.privateKey];
            // 调用微信
            [WXApi sendReq:request];
        }else{
            NSLog(@"参数不正确，请检查参数");
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"error is %@",error);
    }];
    
}
@end
