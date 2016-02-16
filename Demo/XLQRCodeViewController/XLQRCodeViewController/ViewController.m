//
//  ViewController.m
//  XLQRCodeViewController
//
//  Created by 谢小雷 on 16/2/16.
//  Copyright © 2016年 *. All rights reserved.
//

#import "ViewController.h"
#import "XLQRCodeViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *resultTextView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)qrCodeButtonTapped:(id)sender {
    
    __weak __typeof(&*self)weakSelf = self;
    XLQRCodeViewController *qrCodeViewController = [[XLQRCodeViewController alloc] init];
    [qrCodeViewController setGetQRInfoBlock:^(NSString *result, XLQRCodeViewController *controller) {
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
        if (result.length) {
            weakSelf.resultTextView.text = result;
        }
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:qrCodeViewController] animated:YES completion:nil];
}
@end
