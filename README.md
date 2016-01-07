# cordova-plugin-weipay
cordova,plugin,weipay.
### 使用说明
* 你需要在AppDelegate.m 中的该方法中注册微信支付
 
        -(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions{
        
        [WXApi registerApp:$APP_id withDescription:$];
        
        }

