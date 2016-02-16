//
//  XLQRCodeViewController.m
//  XLQRCodeViewController
//
//  Created by 谢小雷 on 16/2/16.
//  Copyright © 2016年 *. All rights reserved.
//

#import "XLQRCodeViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface XLQRCodeViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) UILabel *titleLabel;
@property (weak, nonatomic) UIButton *cancelButton;


@property (nonatomic) NSUInteger numbers;
@property (nonatomic, weak)             UIView                          *cameraView;
@property (nonatomic, weak)             UIView                          *maskView;

@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;
@property (weak, nonatomic) UIImageView *qrImageView;
@property (nonatomic) BOOL isStopAnimation;
@property (weak, nonatomic) UIView *qrAnimationContentView;
@property (weak, nonatomic) UIImageView *qrAnimationView;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metaDataOutput;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

- (BOOL) setupSession;

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) backFacingCamera;

@end

@implementation XLQRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //标题，如果有navigationBar的情况可以去掉
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = NSLocalizedString(@"扫描二维码", @"");
    [titleLabel sizeToFit];
    self.navigationItem.titleView = titleLabel;
    self.titleLabel = titleLabel;
    
    //取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelButton setTitle:NSLocalizedString(@"取消", @"") forState:UIControlStateNormal];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:17];
    [cancelButton addTarget:self action:@selector(cancelButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton sizeToFit];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
    self.cancelButton = cancelButton;

    //拍摄的View，用于显示图像使用
    UIView *cameraView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds))];
    cameraView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cameraView.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    [self.view addSubview:cameraView];
    self.cameraView = cameraView;
    
    _numbers = 0;

    //黑框的View，线边距
    CGFloat margin = 60;
    CGFloat width = CGRectGetHeight(self.view.bounds);
    
    CGFloat borderWidth = (width-CGRectGetWidth(self.view.bounds))/2+margin;
    UIView *maskView =[[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(self.view.bounds)-width)/2, 0, width, width)];
    [self.view addSubview:maskView];
    maskView.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.5].CGColor;
    maskView.layer.borderWidth = borderWidth;
    self.maskView = maskView;

    __weak __typeof(&*self)weakSelf = self;
    
    //参与动画的外框
    CGFloat delta = 3;
    CGFloat imageViewWidth = CGRectGetWidth(self.view.bounds)-margin*2+delta*2;
    UIImageView *qrImageView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"qr_scan"] resizableImageWithCapInsets:UIEdgeInsetsMake(22, 22, 22, 22)]];
    qrImageView.frame = CGRectMake(CGRectGetMidX(self.view.frame)-imageViewWidth/2, CGRectGetMidY(self.view.frame)-imageViewWidth/2, imageViewWidth, imageViewWidth);
    qrImageView.center = self.view.center;
    [self.view addSubview:qrImageView];
    self.qrImageView = qrImageView;
    
    //拥有扫描动画线的View
    UIView *qrAnimationContentView = [[UIView alloc] initWithFrame:CGRectMake(margin, 20+44+margin, CGRectGetWidth(self.view.bounds)-margin*2, CGRectGetWidth(self.view.bounds)-margin*2)];
    qrAnimationContentView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    qrAnimationContentView.clipsToBounds = YES;
    qrAnimationContentView.center = self.view.center;
    [self.view addSubview:qrAnimationContentView];
    self.qrAnimationContentView = qrAnimationContentView;
    
    UIImageView *qrAnimationView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"qr_animation"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0) resizingMode:UIImageResizingModeTile]];
    qrAnimationView.frame = CGRectMake(0, 0, CGRectGetWidth(qrAnimationContentView.frame), CGRectGetHeight(qrAnimationView.frame));
    [self.qrAnimationContentView addSubview:qrAnimationView];
    self.qrAnimationView = qrAnimationView;
    self.qrAnimationView.alpha = 0;
    self.qrImageView.alpha = 0;

    //初始化摄像头 动画
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicatorView.hidesWhenStopped = YES;
    indicatorView.center = self.view.center;
    [self.view addSubview:indicatorView];
    self.indicatorView = indicatorView;
    [self.indicatorView startAnimating];
    
    double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        if ([self setupSession]) {
            
            AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
            captureVideoPreviewLayer.frame = self.cameraView.bounds;
            [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            [self.cameraView.layer insertSublayer:captureVideoPreviewLayer below:[[self.cameraView.layer sublayers] objectAtIndex:0]];
            self.captureVideoPreviewLayer = captureVideoPreviewLayer;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf.session startRunning];
            });
        }
        [self.indicatorView stopAnimating];
        self.cameraView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        CGRect qrFrame = self.qrImageView.frame;
        self.qrImageView.frame = CGRectMake(CGRectGetMidX(qrFrame), CGRectGetMidY(qrFrame), 0, 0);
        [UIView animateWithDuration:0.2 animations:^{
            self.qrImageView.frame = qrFrame;
            self.qrImageView.alpha = 1;
        } completion:^(BOOL finished) {
            self.isStopAnimation = NO;
            self.qrAnimationView.alpha = 1;
            [self beginScanAnimation];
        }];
    });

}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.maskView.alpha = 1;
    }];
    
    if (self.session) {
        [self.session startRunning];
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        self.maskView.alpha = 0;
    }];
    
    if (self.session) {
        [self.session stopRunning];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)cancelButtonAction:(id)sender{
    
    self.isStopAnimation = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)beginScanAnimation{
    
    if (self.isStopAnimation) {
        return;
    }
    self.qrAnimationView.frame = CGRectMake(0, -CGRectGetHeight(self.qrAnimationView.frame), CGRectGetWidth(self.qrAnimationView.frame), CGRectGetHeight(self.qrAnimationView.frame));
    
    [UIView animateWithDuration:2.0 animations:^{
        self.qrAnimationView.frame = CGRectMake(0, CGRectGetHeight(self.qrImageView.frame), CGRectGetWidth(self.qrAnimationView.frame), CGRectGetHeight(self.qrAnimationView.frame));
    } completion:^(BOOL finished) {
        if (!self.isStopAnimation) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self beginScanAnimation];
            });
        }
    }];
}

#pragma mark - Private Action

- (BOOL) setupSession{
    
    BOOL success = NO;
    
    // Set torch and flash mode to auto
    if ([[self backFacingCamera] hasFlash]) {
        if ([[self backFacingCamera] lockForConfiguration:nil]) {
            if ([[self backFacingCamera] isFlashModeSupported:AVCaptureFlashModeOff]) {
                [[self backFacingCamera] setFlashMode:AVCaptureFlashModeOff];
            }
            [[self backFacingCamera] unlockForConfiguration];
        }
    }
    if ([[self backFacingCamera] hasTorch]) {
        if ([[self backFacingCamera] lockForConfiguration:nil]) {
            if ([[self backFacingCamera] isTorchModeSupported:AVCaptureTorchModeOff]) {
                [[self backFacingCamera] setTorchMode:AVCaptureTorchModeOff];
            }
            [[self backFacingCamera] unlockForConfiguration];
        }
    }
    
    self.session = [[AVCaptureSession alloc] init];
    
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:nil];
    
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    self.metaDataOutput = [[AVCaptureMetadataOutput alloc] init];
    dispatch_queue_t videoQueue = dispatch_queue_create("com.sunsetlakesoftware.colortracki ng.metadataqueue", NULL);
    [self.metaDataOutput setMetadataObjectsDelegate:self queue:videoQueue];
    if ([self.session canAddOutput:self.metaDataOutput]) {
        [self.session addOutput:self.metaDataOutput];
    }
    if ([self.metaDataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
        self.metaDataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    }
    
    [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    
    success = YES;
    return success;
}

// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

// Find a back facing camera, returning nil if one is not found
- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    
    _numbers ++;
    if (_numbers%20 == 1) {
        for (AVMetadataObject *object in metadataObjects) {
            if ([[object type] isEqualToString:AVMetadataObjectTypeQRCode]) {
                AVMetadataMachineReadableCodeObject *code = (AVMetadataMachineReadableCodeObject *)object;
                if (code.stringValue.length && self.getQRInfoBlock) {
                    [self.session stopRunning];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *resultString = code.stringValue;
                        resultString = [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        self.isStopAnimation = YES;
                        self.getQRInfoBlock(resultString,self);
                    });
                }
            }
        }
    }
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */
@end
