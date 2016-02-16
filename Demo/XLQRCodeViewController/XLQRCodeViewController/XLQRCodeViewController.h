//
//  XLQRCodeViewController.h
//  XLQRCodeViewController
//
//  Created by 谢小雷 on 16/2/16.
//  Copyright © 2016年 *. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XLQRCodeViewController : UIViewController
@property (nonatomic, copy) void (^getQRInfoBlock)(NSString *info,XLQRCodeViewController *viewcontroller);
@end
