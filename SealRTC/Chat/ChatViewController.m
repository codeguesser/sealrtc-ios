//
//  ChatViewController.h
//  RongCloud
//
//  Created by LiuLinhong on 2016/11/15.
//  Copyright © 2016年 Beijing Rongcloud Network Technology Co. , Ltd. All rights reserved.
//

#import "ChatViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "SettingViewController.h"
#import "CommonUtility.h"
#import "WhiteBoardWebView.h"
#import "LoginViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "RongRTCTalkAppDelegate.h"
#import "UICollectionView+RongRTCBgView.h"
#import "ChatSwitchModeTableViewController.h"

typedef enum : NSUInteger {
    ResolutionType_256_144,
    ResolutionType_320_240,
    ResolutionType_480_368,
    ResolutionType_640_368,
    ResolutionType_640_480,
    ResolutionType_720_480,
    ResolutionType_1280_720
} ResolutionType;


@protocol JSDelegate <JSExport>
//这个方法就是window.document.iosDelegate.getImage(JSON.stringify(parameter)); 中的 getImage()方法
- (void)getImage:(id)parameter;
@end

@interface ChatViewController () <UIWebViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, JSDelegate, UIPopoverPresentationControllerDelegate>
{
    NSInteger frameRateIndex, codeRateIndex, connectionStyleIndex, codingStyleIndex, minCodeRateIndex;
    ResolutionType resolutionIndex,maxResolutionIndex;
    CGFloat localVideoWidth, localVideoHeight;
    UIButton *silienceButton;
    BOOL isRaiseHandBtnClicked,isShowButton;
    NSTimeInterval showButtonSconds;
    NSTimeInterval defaultButtonShowTime;
    CADisplayLink *displayLink;
    ChatSwitchModeTableViewController *popController;
}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mainVieTopMargin;
@property(strong, nonatomic) JSContext *jsContext;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewTopMargin;
@property (nonatomic, assign) RongRTCConnectionMode connectionType;
@property(strong, nonatomic) NSIndexPath *selectedIndexPath;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewLeadingMargin;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewTrailingMargin;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *collectionViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *statuView;
@property (strong, nonatomic) IBOutlet UICollectionViewLayout *collectionViewLayout;


@end

@implementation ChatViewController
@synthesize whiteBoardWebView = whiteBoardWebView;
@synthesize deviceOrientaionBefore = deviceOrientaionBefore;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isBackCamera = NO;
    self.isCloseCamera = NO;
    self.isSpeaker = YES;
    self.isNotMute = NO;
    self.isSwitchCamera = NO;
    self.isOpenWhiteBoard = NO;
    self.isGPUFilter = NO;
    self.isSRTPEncrypt = NO;
    isRaiseHandBtnClicked = NO;
    self.userIDArray = [NSMutableArray array];
    self.remoteViewArray = [NSMutableArray array];
    self.observerArray = [NSMutableArray array];
    self.videoMuteForUids = [NSMutableDictionary dictionary];
    self.alertTypeArray = [NSMutableArray array];
    self.videoHeight = ScreenWidth * 640.0 / 480.0;
    self.blankHeight = (ScreenHeight - self.videoHeight)/2;
    self.messageStatusBar = [[MessageStatusBar alloc] init];
    self.channel = self.roomName;
    self.type = self.chatType;
    self.isFinishLeave = YES;
    self.isWhiteBoardExist = NO;
    self.isLandscapeLeft = NO;
    self.isNotLeaveMeAlone = NO;
    isShowButton = YES;
    showButtonSconds = 0;
    defaultButtonShowTime = 6;
//    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeCaucluate)];
//    [displayLink
//     addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//    displayLink.paused = YES;
//    displayLink.frameInterval = 1;
    self.titleLabel.text = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"chat_room", nil), self.channel];
    self.dataTrafficLabel.hidden = YES;
    [self initUserDefaultsData];
    
    //remote video collection view
    self.chatCollectionViewDataSourceDelegateImpl = [[ChatCollectionViewDataSourceDelegateImpl alloc] initWithViewController:self];
    self.collectionView.dataSource = self.chatCollectionViewDataSourceDelegateImpl;
    self.collectionView.delegate = self.chatCollectionViewDataSourceDelegateImpl;
    self.collectionView.tag = 202;
    self.collectionView.chatVC = self;
    self.collectionViewLayout = self.collectionView.collectionViewLayout;
    
    self.chatViewBuilder = [[ChatViewBuilder alloc] initWithViewController:self];
    
    [self.speakerControlButton setEnabled:NO];
    [self selectSpeakerButtons:NO];
    [self initRongRTCEngine];

    [self addObserver];
    self.dataTrafficLabel.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.rongRTCEngine.delegate = self.chatRongRTCEngineDelegateImpl;
    self.chatViewBuilder.chatViewController = self;
    [self initUserDefaultsData];
    
    RongRTCTalkAppDelegate *appDelegate = (RongRTCTalkAppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.isForceLandscape = YES;
    self.isLandscapeLeft = YES;
    [appDelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:self.view.window];
    deviceOrientaionBefore = UIDeviceOrientationPortrait;
  
    self.isHiddenStatusBar = NO;

 
    [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
    [self dismissButtons:YES];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            if ([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)])
            {
                NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIDeviceOrientationLandscapeLeft];
                [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
                
            }
            break;
        case UIDeviceOrientationLandscapeRight:
            if ([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)])
            {
                NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIDeviceOrientationLandscapeRight];
                [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
                
            }
            break;
        default:
            break;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self joinChannel];
    
    if ([self isHeadsetPluggedIn])
        [self reloadSpeakerRoute:YES];
}

- (void)addObserver
{
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(handleDeviceOrientationChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)handleDeviceOrientationChange:(NSNotification *)notification{
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    switch(deviceOrientation)
    {
        case UIDeviceOrientationFaceUp:
            DLog(@"屏幕朝上平躺");
            if ([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)])
            {
                NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
                [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
             
            }
            break;
        case UIDeviceOrientationFaceDown:
            DLog(@"屏幕朝下平躺");
            if ([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)])
            {
                NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
                [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
            }
            break;
        case UIDeviceOrientationUnknown:
            DLog(@"未知方向");
            if ([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)])
            {
                NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
                [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
            }
            break;
        case UIDeviceOrientationLandscapeLeft:
            DLog(@"屏幕向左横置");
            [self interfaceOrientation:deviceOrientation];
            deviceOrientaionBefore = UIDeviceOrientationLandscapeLeft;
            [self.messageStatusBar hideManual];
            [UIApplication sharedApplication].statusBarHidden = YES;
            break;
        case UIDeviceOrientationLandscapeRight:
            DLog(@"屏幕向右橫置");
            [self interfaceOrientation:deviceOrientation];
            deviceOrientaionBefore = UIDeviceOrientationLandscapeRight;
            [self.messageStatusBar hideManual];
            [UIApplication sharedApplication].statusBarHidden = YES;
            break;
        case UIDeviceOrientationPortrait:
            [UIApplication sharedApplication].statusBarHidden = NO;
            [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait];
            DLog(@"屏幕直立");
            [self.messageStatusBar hideManual];
            [self interfaceOrientation:deviceOrientation];
            deviceOrientaionBefore = UIDeviceOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            DLog(@"屏幕直立，上下顛倒");
            break;
        default:
            DLog(@"无法辨识");
            break;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (void)reloadSpeakerRoute:(BOOL)enable
{
    self.isSpeaker = enable;
    [self.rongRTCEngine switchSpeaker:!self.isSpeaker];
//    [self switchButtonBackgroundColor:self.isSpeaker button:self.chatViewBuilder.speakerOnOffButton];
    
    if (enable)
        [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_on"];
    else
        [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_off"];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    [self.messageStatusBar hideManual];
    [displayLink invalidate];
    displayLink = nil;
    self.collectionView.chatVC = nil;
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];

    RongRTCTalkAppDelegate *appDelegate = (RongRTCTalkAppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.isForceLandscape = NO;
    appDelegate.isForcePortrait = YES;

    if (!popController.popoverPresentationController) {
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait] forKey:@"orientation"];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - status bar
- (BOOL)prefersStatusBarHidden
{
    return _isHiddenStatusBar;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)setIsHiddenStatusBar:(BOOL)isHiddenStatusBar
{
    _isHiddenStatusBar = isHiddenStatusBar;
    NSInteger version = [[[UIDevice currentDevice] systemVersion] integerValue];
    if (version == 11) {
        if (isHiddenStatusBar && ![self isiPhoneX]) {
            _mainVieTopMargin.constant = 20.0;
            [self setNeedsStatusBarAppearanceUpdate];
        }else if (![self isiPhoneX]) {
            _mainVieTopMargin.constant = 0.0;
            [self setNeedsStatusBarAppearanceUpdate];
        }
    }else{
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (BOOL)isiPhoneX
{
    if ([[CommonUtility getdeviceName] isEqualToString:@"iPhone X"]) {
        return YES;
    }
    return NO;
}

#pragma mark - config UI
- (void)dismissButtons:(BOOL)flag
{
    if (isShowButton)
        displayLink.paused = NO;
}

- (void)showButtons:(BOOL)flag
{
    isShowButton = !flag;
    
    self.chatViewBuilder.upMenuView.hidden = flag;
    self.chatViewBuilder.hungUpButton.hidden = flag;
    self.dataTrafficLabel.hidden =  flag;
    self.talkTimeLabel.hidden = flag;
    self.titleLabel.hidden = flag;
    self.chatViewBuilder.openCameraButton.hidden = flag;
    self.chatViewBuilder.microphoneOnOffButton.hidden = flag;
    self.chatViewBuilder.playbackModeButton.hidden = flag;
    if (flag) {
        [popController dismissViewControllerAnimated:YES completion:nil];
    }
    
    if (!isShowButton) {
        if (self.deviceOrientaionBefore == UIDeviceOrientationPortrait) {
            _collectionViewTopMargin.constant = -40;
        }
    }else{
        if (self.deviceOrientaionBefore == UIDeviceOrientationPortrait) {
            _collectionViewTopMargin.constant = 0;
        }
    }

//    [[UIApplication sharedApplication] setStatusBarHidden:flag];
    self.isHiddenStatusBar = flag;
}

#pragma mark - touch event
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    if (!self.isOpenWhiteBoard) {
        showButtonSconds = 0;
        [self showButtons:isShowButton];
        if (isShowButton) {
            displayLink.paused = NO;
        }
    }
}

- (void)timeCaucluate
{
    showButtonSconds += 1;
    if (showButtonSconds > defaultButtonShowTime * 60) {
        showButtonSconds = 0;
        displayLink.paused = YES;
        [self showButtons:YES];
    }
}

- (void)showButtonsWithWhiteBoardExist:(BOOL)exist;
{
    if (exist) {
        showButtonSconds = 0;
        if (!isShowButton) {
            [self showButtons:isShowButton];
        }
        displayLink.paused = YES;
    }else{
        showButtonSconds = 0;
        if (!isShowButton) {
            [self showButtons:isShowButton];
        }
        if (isShowButton) {
            displayLink.paused = NO;
        }
    }
}

#pragma mark - CollectionViewTouchesDelegate
- (void)didTouchedBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event withBlock:(void (^)(void))block
{
    UITouch *touch = [touches anyObject];
    
    if (CGRectContainsPoint(self.collectionView.frame, [touch locationInView:self.collectionView])) {
        CGPoint point = [touch locationInView:self.collectionView];
        if (self.userIDArray.count * 60 < ScreenWidth && point.x > self.userIDArray.count * 60) {
            showButtonSconds = 0;
            [self showButtons:isShowButton];
            if (isShowButton) {
                displayLink.paused = NO;
            }
            return;
        }
    }
    
    block();
}

#pragma mark - init rongRTCEngine
- (void)initRongRTCEngine
{
    self.chatRongRTCEngineDelegateImpl = [[ChatRongRTCEngineDelegateImpl alloc] initWithViewController:self];
    self.rongRTCEngine = [RongRTCEngine sharedRongRTCEngine];
}

#pragma mark - join channel
- (void)joinChannel
{
    [self initUserDefaultsData];
    [self configParameter];
    [self.rongRTCEngine setVideoParameters:self.paraDic];
    [self.rongRTCEngine joinChannel:self.channel withKeyToken:[LoginViewController getKeyToken] withUserID:kDeviceUUID withUserName:self.userName];
    
    //setup local video view
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.observerIndex == RongRTC_User_Normal)
        {
            [self turnMenuButtonToNormal];
            self.localView = [self.rongRTCEngine createLocalVideoViewFrame:self.videoMainView.frame withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
            [self.localVideoViewModel.avatarView removeFromSuperview];
            [self.localVideoViewModel removeObserver:self.localVideoViewModel forKeyPath:@"frameRateRecv"];
            [self.localVideoViewModel removeObserver:self.localVideoViewModel forKeyPath:@"frameWidthRecv"];
            [self.localVideoViewModel removeObserver:self.localVideoViewModel forKeyPath:@"frameHeightRecv"];
            [self.localVideoViewModel removeObserver:self.localVideoViewModel forKeyPath:@"frameRate"];
            
            self.localVideoViewModel = nil;
            self.localVideoViewModel = [[ChatCellVideoViewModel alloc] initWithView:self.localView];
            self.localVideoViewModel.userID = kDeviceUUID;
            self.localVideoViewModel.avType = self.closeCameraIndex;
            self.localVideoViewModel.originalSize = CGSizeMake(localVideoWidth, localVideoHeight);
            self.localVideoViewModel.userName = self.userName;
            
            self.localVideoViewModel.avatarView.model = [[ChatAvatarModel alloc] initWithShowVoice:NO showIndicator:YES userName:self.localVideoViewModel.userName userID:kDeviceUUID];
            [self.videoMainView addSubview:self.localVideoViewModel.cellVideoView];

            if (self.closeCameraIndex == RongRTC_User_Only_Audio) {
                self.localVideoViewModel.avatarView.frame = BigVideoFrame;
                self.localVideoViewModel.avatarView.center = self.videoMainView.center;
                [self.localVideoViewModel.avatarView removeFromSuperview];
            }
            
            [self.rongRTCEngine setVideoSizeForTinyStream:176 height:144];
            
         }
        else if (self.observerIndex == RongRTC_User_Observer)
        {
            [self turnMenuButtonToObserver];
        }
    });
}

- (void)configParameter
{
    NSInteger videoProfile = RongRTC_VideoProfile_Invalid;
    NSInteger adaptVideoProfile = RongRTC_VideoProfile_Invalid;
    switch (self.chatResolutionRatioIndex)
    {
        case 0:
        {
            DLog(@"LLH...... 分辨率: 240x320");
            localVideoWidth = 240;
            localVideoHeight = 320;
            if (frameRateIndex == 0){
                videoProfile = RongRTC_VideoProfile_640_480P;
                adaptVideoProfile = RongRTC_VideoProfile_320_240P;
            }else if (frameRateIndex == 1){
                videoProfile = RongRTC_VideoProfile_640_480P_1;
                adaptVideoProfile = RongRTC_VideoProfile_320_240P_1;
            }else if (frameRateIndex == 2){
                videoProfile = RongRTC_VideoProfile_640_480P_2;
                adaptVideoProfile = RongRTC_VideoProfile_320_240P_2;
            }
            resolutionIndex = ResolutionType_320_240;
        }
            break;
        case 1:
        {
            DLog(@"LLH...... 分辨率: 480x640");
            localVideoWidth = 480;
            localVideoHeight = 640;
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_640_480P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_640_480P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_640_480P_2;
            resolutionIndex = ResolutionType_640_480;
            adaptVideoProfile = videoProfile;
        }
            break;
        case 2:
        {
            DLog(@"LLH...... 分辨率: 720x1280");
            localVideoWidth = 720;
            localVideoHeight = 1280;
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_1280_720P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_1280_720P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_1280_720P_2;
            resolutionIndex = ResolutionType_1280_720;
            adaptVideoProfile = videoProfile;
            [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileUpButton withEnable:NO];
        }
            break;
        case 3:
        {
            DLog(@"LLH...... 分辨率: 1080x1920 不支持机型默认最大分辨率");
            localVideoWidth = 720;
            localVideoHeight = 1280;
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_1280_720P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_1280_720P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_1280_720P_2;
            resolutionIndex = ResolutionType_1280_720;
            adaptVideoProfile = videoProfile;
            [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileUpButton withEnable:NO];
        }
            break;
        default:
            break;
    }
    maxResolutionIndex = resolutionIndex;
    if (frameRateIndex == 0){
        DLog(@"LLH........ 帧率: 15");}
    else if (frameRateIndex == 1){
        DLog(@"LLH........ 帧率: 24");}
    else if (frameRateIndex == 2){
        DLog(@"LLH........ 帧率: 30");}
    
    NSArray *codeRateArray = [CommonUtility getPlistArrayByplistName:Key_CodeRate];
    NSDictionary *codeRateDictionary = codeRateArray[self.chatResolutionRatioIndex];
    //NSInteger min = [codeRateDictionary[Key_Min] integerValue];
    NSInteger max = [codeRateDictionary[Key_Max] integerValue];
    NSInteger step = [codeRateDictionary[Key_Step] integerValue];
    
    NSMutableArray *muArray = [NSMutableArray array];
    for (NSInteger temp = 0; temp <= max; temp += step)
        [muArray addObject:[NSString stringWithFormat:@"%zd", temp]];
    
    NSInteger maxCodeRate = -1;
    if ([muArray count] > codeRateIndex)
    {
        maxCodeRate = [muArray[codeRateIndex] integerValue];
        DLog(@"LLH........ 最大码率: %zd", maxCodeRate);
    }
    else
    {
        DLog(@"LLH...... 最大码率选项出现越界... 错误 codeRateIndex: %zd", codeRateIndex);
    }
    
    NSMutableArray *minArray = [NSMutableArray array];
    for (NSInteger tmp = 0; tmp <= max; tmp += step)
        [minArray addObject:[NSString stringWithFormat:@"%zd", tmp]];
    
    NSInteger minCodeRate = -1;
    if ([minArray count] > minCodeRateIndex)
    {
        minCodeRate = [minArray[minCodeRateIndex] integerValue];
        DLog(@"LLH........ 最小码率: %zd", minCodeRate);
    }
    else
    {
        DLog(@"LLH...... 最小码率选项出现越界... 错误 minCodeRateIndex: %zd", minCodeRateIndex);
    }
    
    NSInteger sessionType;
    if (connectionStyleIndex)
    {
        sessionType = 1;
        DLog(@"LLH......sessionType:%zd 连接方式: Relay", sessionType);
    }
    else
    {
        sessionType = 0;
        DLog(@"LLH......sessionType:%zd 连接方式: P2P", sessionType);
    }
    
    switch (self.closeCameraIndex)
    {
        case 0:
        {
            self.closeCameraIndex = RongRTC_User_Audio_Video;
            self.observerIndex = RongRTC_User_Normal;
            DLog(@"LLH......self.closeCameraIndex: %zd 打开视频", self.closeCameraIndex);
            DLog(@"LLH......self.observerIndex:%zd 观察者方式: 正常,非观察者", self.observerIndex);
        }
            break;
        case 1:
        {
            self.closeCameraIndex = RongRTC_User_Only_Audio;
            self.observerIndex = RongRTC_User_Normal;
            DLog(@"LLH......self.closeCameraIndex: %zd 关闭视频,仅音频", self.closeCameraIndex);
            DLog(@"LLH......self.observerIndex:%zd 观察者方式: 正常,非观察者", self.observerIndex);
        }
            break;
        case 2:
        {
            self.closeCameraIndex = RongRTC_User_Audio_Video_None;
            self.observerIndex = RongRTC_User_Observer;
            DLog(@"LLH......self.closeCameraIndex: %zd 关闭音频+视频", self.closeCameraIndex);
            DLog(@"LLH......self.observerIndex:%zd 观察者方式: 观察者", self.observerIndex);
        }
            break;
        default:
        {
            self.closeCameraIndex = RongRTC_User_Audio_Video;
            self.observerIndex = RongRTC_User_Normal;
            DLog(@"LLH......self.closeCameraIndex: %zd 打开视频", self.closeCameraIndex);
            DLog(@"LLH......self.observerIndex:%zd 观察者方式: 正常,非观察者", self.observerIndex);
        }
            break;
    }
    
    NSInteger codeType;
    switch (codingStyleIndex)
    {
        case 0:
        {
            codeType = 0;
            DLog(@"LLH......codeType:%zd 编码方式: kVideoTypeH264", codeType);
        }
            break;
        case 1:
        {
            codeType = 1;
            DLog(@"LLH......codeType:%zd 编码方式: kVideoTypeVP8", codeType);
        }
            break;
        case 2:
        {
            codeType = 2;
            DLog(@"LLH......codeType:%zd 编码方式: kVideoTypeVP9", codeType);
        }
            break;
        default:
        {
            codeType = 0;
            DLog(@"LLH......codeType:%zd 编码方式: kVideoTypeH264", codeType);
        }
            break;
    }
    
    if (videoProfile == RongRTC_VideoProfile_Invalid || maxCodeRate == -1)
    {
        self.alertController = [UIAlertController alertControllerWithTitle:@"Setting Data ERROR!" message:@"Cann't Send Join Channel Request" preferredStyle:UIAlertControllerStyleAlert];
        [self.alertController  addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }]];
        [self presentViewController:self.alertController  animated:YES completion:^{}];
        return;
    }
    
//    [self showAlertLabelWithString:NSLocalizedString(@"chat_wait_attendees", nil)];
    
    self.paraDic = [NSMutableDictionary dictionary];
    self.paraDic[kAudioOnly] = @(NO);
    self.paraDic[kVideoProfile] = @(videoProfile);
    self.paraDic[kMaxBandWidth] = @(maxCodeRate);
    self.paraDic[@"MinBandWidth"] = @(minCodeRate);
    self.paraDic[kUserType] = @(self.observerIndex);
    self.paraDic[@"SessionType"] = @(sessionType);
    self.paraDic[@"VideoCodecType"] = @(codeType);
    self.paraDic[kCloseCamera] = @(self.closeCameraIndex);
    self.paraDic[@"SRTPEncrypt"] = @(self.isSRTPEncrypt);
    self.paraDic[@"AdaptVideoProfile"] = @(adaptVideoProfile);
    self.paraDic[@"TinyStreamEnabled"] = @(self.isTinyStream);
}

#pragma mark - init UserDefaults data
- (void)initUserDefaultsData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
    NSString *docDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Preferences"];
    NSString *settingUserDefaultPath = [docDir stringByAppendingPathComponent:File_SettingUserDefaults_Plist];
    BOOL isPlistExist = [CommonUtility isFileExistsAtPath:settingUserDefaultPath];
    
    if (isPlistExist)
    {
        NSUserDefaults *settingUserDefaults = [SettingViewController shareSettingUserDefaults];
        self.chatResolutionRatioIndex = [[settingUserDefaults valueForKey:Key_ResolutionRatio] integerValue];
        frameRateIndex = [[settingUserDefaults valueForKey:Key_FrameRate] integerValue];
        codeRateIndex = [[settingUserDefaults valueForKey:Key_CodeRate] integerValue];
        connectionStyleIndex = [[settingUserDefaults valueForKey:Key_ConnectionStyle] integerValue];
        codingStyleIndex = [[settingUserDefaults valueForKey:Key_CodingStyle] integerValue];
        minCodeRateIndex = [[settingUserDefaults valueForKey:Key_CodeRateMin] integerValue];
        self.observerIndex = [[settingUserDefaults valueForKey:Key_Observer] integerValue];
        self.closeCameraIndex = [[settingUserDefaults valueForKey:Key_CloseVideo] integerValue];
        self.isGPUFilter = [[settingUserDefaults valueForKey:Key_GPUFilter] boolValue];
        self.isSRTPEncrypt = [[settingUserDefaults valueForKey:Key_SRTPEncrypt] boolValue];
        self.connectionType = [[settingUserDefaults valueForKey:Key_ConnectionMode] integerValue];
        self.isTinyStream = [[settingUserDefaults valueForKey:Key_TinyStreamMode] integerValue];

    }
    else
    {
        self.chatResolutionRatioIndex = Value_Default_ResolutionRatio;
        frameRateIndex = Value_Default_FrameRate;
        codeRateIndex = Value_Default_CodeRate;
        connectionStyleIndex = Value_Default_Connection_Style;
        codingStyleIndex = Value_Default_Coding_Style;
        minCodeRateIndex = Value_Default_MinCodeRate;
        self.observerIndex = Value_Default_Observer;
        self.closeCameraIndex = Value_Default_CloseVideo;
        self.isGPUFilter = Value_Default_GPUFilter;
        self.isSRTPEncrypt = Value_Default_SRTPEncrypt;
        self.connectionType = Value_Default_ConnectionMode;
        self.isTinyStream = Value_Default_TinyStream;
    }
}

#pragma mark - show alert label
- (void)showAlertLabelWithString:(NSString *)text;
{
    self.alertLabel.hidden = NO;
    self.alertLabel.text = text;
}

#pragma mark - hide alert label
- (void)hideAlertLabel:(BOOL)isHidden
{
    self.alertLabel.hidden = isHidden;
}

#pragma mark - update Time/Traffic by timer
- (void)updateTalkTimeLabel
{
    self.duration++;
    NSUInteger seconds = self.duration % 60;
    NSUInteger minutes = (self.duration - seconds) / 60;
    self.talkTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (unsigned long)minutes, (unsigned long)seconds];
}

#pragma mark - click memu item button
- (void)menuItemButtonPressed:(UIButton *)sender
{
    UIButton *button = (UIButton *)sender;
    NSInteger tag = button.tag;
    
    switch (tag)
    {
        case 0: //handup
            [self didClickRaiseHandButton:button];
            break;
        case 1: //white board
            [self didClickWhiteBoardButton:button];
            break;
        case 2: //switch camera
            [self didClickSwitchCameraButton:button];
            break;
        case 3: //mute speaker
            [self didClickSpeakerButton:button];
            break;
        case 4: //UpVideoProfile
            [self didClickUpVideoProfileButton:button];
            break;
        case 5: //DownVideoProfile
            [self didClickDownVideoProfileButton:button];
            break;
        case 8: //play recording
            [self didClickPlayRecordingButton:button];
            break;
        default:
            break;
    }
}

#pragma mark - 7 play recorded audio
- (void)didClickPlayRecordingButton:(UIButton *)btn
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SealRTC/temp.wav"];
    BOOL isDir = TRUE;
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    
    if (isExist)
    {
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:nil];
        [player play];
    }
}

#pragma mark - 6 click stop recording button
- (void)didClickStopRecordingButton:(UIButton *)btn
{
}

#pragma mark - 5 click start recording button
- (void)didClickStartRecordingButton:(UIButton *)btn
{
    [self deleteTempFileFromDocuments];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SealRTC"];
    BOOL isDir = TRUE;
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (!isExist)
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SealRTC/temp.wav"];
}

#pragma mark - 4 click mute micphone
- (void)didClickAudioMuteButton:(UIButton *)btn
{
    [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Micphone open:self.isNotMute];
    self.isNotMute = !self.isNotMute;
    [self.rongRTCEngine muteMicrophone:self.isNotMute];
    
    [self switchButtonBackgroundColor:self.isNotMute button:btn];
    [self.chatRongRTCEngineDelegateImpl adaptUserType:RongRTC_Device_Micphone withDataModel:self.localVideoViewModel open:!self.isNotMute];

    if (self.isNotMute)
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_off"];
    else
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_on"];
}

- (void)muteAudioButton:(UIButton *)btn
{
    self.isNotMute = !self.isNotMute;
    [self.rongRTCEngine muteMicrophone:self.isNotMute];
    [self switchButtonBackgroundColor:self.isNotMute button:btn];
    [self.chatRongRTCEngineDelegateImpl adaptUserType:RongRTC_Device_Micphone withDataModel:self.localVideoViewModel open:!self.isNotMute];

    if (self.isNotMute)
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_off"];
    else
        [CommonUtility setButtonImage:btn imageName:@"chat_microphone_on"];
}

#pragma mark - 3 click mute speaker
- (void)didClickSpeakerButton:(UIButton *)btn
{
    self.isSpeaker = !self.isSpeaker;
    [self.rongRTCEngine switchSpeaker:self.isSpeaker];
    [self switchButtonBackgroundColor:!self.isSpeaker button:btn];
    
    if (self.isSpeaker)
        [CommonUtility setButtonImage:btn imageName:@"chat_speaker_on"];
    else
        [CommonUtility setButtonImage:btn imageName:@"chat_speaker_off"];
}

- (void)enableSpeakerButton:(BOOL)enable
{
    self.isSpeaker = enable;
    [self switchButtonBackgroundColor:!enable button:self.chatViewBuilder.speakerOnOffButton];
    
    if (enable)
        [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_on"];
    else
        [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_off"];
}

#pragma mark - 2 click local video
- (void)didClickVideoMuteButton:(UIButton *)btn
{
    self.isCloseCamera = !self.isCloseCamera;
    [self.rongRTCEngine closeLocalVideo:self.isCloseCamera];
    [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Camera open:!self.isCloseCamera];

    [self.chatRongRTCEngineDelegateImpl adaptUserType:RongRTC_Device_Camera withDataModel:self.localVideoViewModel open:!self.isCloseCamera];
 
//    self.localView.hidden = self.isCloseCamera;
     [self switchButtonBackgroundColor:self.isCloseCamera button:btn];
    
    if (self.isCloseCamera)
    {
//        [self.rongRTCEngine modifyAudioVideoType:RongRTC_User_Only_Audio];
        [CommonUtility setButtonImage:btn imageName:@"chat_close_camera"];
//        self.localVideoViewModel.avType = RongRTC_User_Only_Audio;

        if (self.isSwitchCamera)
        {
            self.localVideoViewModel.avatarView.frame = SmallVideoFrame;
            self.localVideoViewModel.avatarView.center = CGPointMake(45, 60.0);
            [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
            [self.localVideoViewModel.avatarView.indicatorView stopAnimating];

        }
        else
        {
            self.localVideoViewModel.avatarView.frame = BigVideoFrame;
            self.videoMainView.backgroundColor = [UIColor blackColor];
            [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
            self.localVideoViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width / 2, self.videoMainView.frame.size.height / 2);
            [self.localVideoViewModel.avatarView.indicatorView stopAnimating];

            if (whiteBoardWebView)
                [self.videoMainView bringSubviewToFront:whiteBoardWebView];
        }
    }
    else
    {
         [self.videoMainView bringSubviewToFront:self.localVideoViewModel.cellVideoView];
//        [self.rongRTCEngine modifyAudioVideoType:RongRTC_User_Audio_Video];
        [CommonUtility setButtonImage:btn imageName:@"chat_open_camera"];
//        self.localVideoViewModel.avType = RongRTC_User_Audio_Video;
        [self.localVideoViewModel.avatarView removeFromSuperview];
    }
}

- (void)muteVideoButton:(UIButton *)btn
{
    self.isCloseCamera = !self.isCloseCamera;
    [self.rongRTCEngine closeLocalVideo:self.isCloseCamera];

    [self switchButtonBackgroundColor:self.isCloseCamera button:btn];
    [self.chatRongRTCEngineDelegateImpl adaptUserType:RongRTC_Device_Camera withDataModel:self.localVideoViewModel open:self.isCloseCamera];
//    self.localView.hidden = self.isCloseCamera;

    
    if (self.isCloseCamera)
    {

        [CommonUtility setButtonImage:btn imageName:@"chat_close_camera"];
 
        if (self.isSwitchCamera)
        {
            self.localVideoViewModel.avatarView.frame = SmallVideoFrame;
            self.localVideoViewModel.avatarView.center = CGPointMake(45, 60.0);
            [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
            [self.localVideoViewModel.avatarView.indicatorView stopAnimating];
        }
        else
        {
            self.localVideoViewModel.avatarView.frame = BigVideoFrame;
            [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
            self.localVideoViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width / 2, self.videoMainView.frame.size.height / 2);
            [self.localVideoViewModel.avatarView.indicatorView stopAnimating];
            
            if (whiteBoardWebView)
                [self.videoMainView bringSubviewToFront:whiteBoardWebView];
        }
    }
    else
    {
        [CommonUtility setButtonImage:btn imageName:@"chat_open_camera"];
        [self.localVideoViewModel.avatarView removeFromSuperview];
    }
}

#pragma mark - 1 click switch camera
- (void)didClickSwitchCameraButton:(UIButton *)btn
{
    self.isBackCamera = !self.isBackCamera;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.rongRTCEngine switchCamera];
    });
    [self switchButtonBackgroundColor:self.isBackCamera button:btn];
}

- (void)shouldChangeSwitchCameraButtonBG:(UIButton *)btn
{
    self.isBackCamera = !self.isBackCamera;
    [self switchButtonBackgroundColor:self.isBackCamera button:btn];
}

#pragma mark - 0 click white board
- (void)didClickWhiteBoardButton:(UIButton *)btn
{
    if (self.observerIndex == RongRTC_User_Observer && !self.isWhiteBoardExist) {
        [self alertWith:@"" withMessage:NSLocalizedString(@"chat_notice_open_whiteboard", nil) withOKAction:nil withCancleAction:nil];
        return;
    }
  
    if (!self.isOpenWhiteBoard)
    {
        if (!whiteBoardWebView)
        {
            whiteBoardWebView = [[WhiteBoardWebView alloc] initWithFrame:CGRectMake(0, ScreenHeight/3, ScreenWidth, ScreenHeight/2 )];
            whiteBoardWebView.backgroundColor = [UIColor grayColor];
            whiteBoardWebView.userInteractionEnabled = YES;
            [self.rongRTCEngine requestWhiteBoardURL];
        }
        
        if (deviceOrientaionBefore == UIDeviceOrientationLandscapeLeft || deviceOrientaionBefore == UIDeviceOrientationLandscapeRight)
            whiteBoardWebView.frame = CGRectMake(0, 60.0 , ScreenWidth, ScreenHeight - 60);
        
        [CommonUtility setButtonImage:btn imageName:@"chat_white_board_off"];
    }
    else
    {
        [CommonUtility setButtonImage:btn imageName:@"chat_white_board_off"];
        [whiteBoardWebView removeFromSuperview];
        whiteBoardWebView = nil;
  
        [_messageStatusBar hideManual];
        
        self.collectionView.hidden = NO;
        
//        if (self.observerIndex == RongRTC_User_Observer) {
//            [self.videoMainView addSubview:self.localVideoViewModel.cellVideoView];
//        }else
//            [self.videoMainView addSubview:self.localView];
        if (_isSwitchCamera) {
            [self.videoMainView addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView];
        }else
            [self.videoMainView addSubview:self.localVideoViewModel.cellVideoView];

        if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio){
            self.localVideoViewModel.avatarView.center = CGPointMake(self.localView.superview.frame.size.width/2, self.localView.superview.frame.size.height/2);
             [self.localVideoViewModel.cellVideoView bringSubviewToFront:self.localVideoViewModel.avatarView];
             [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
        }
        
        self.isOpenWhiteBoard = NO;
        [self showButtonsWithWhiteBoardExist:self.isOpenWhiteBoard];
        
        if (self.observerIndex == RongRTC_User_Observer)
            [self turnMenuButtonToObserver];
        else
            [self turnMenuButtonToNormal];
    }
    
    if (self.localVideoViewModel.avType == RongRTC_User_Only_Audio || self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None) {
        [self.localVideoViewModel.avatarView setHidden:NO];
    }
}

#pragma mark - 0 click raiseHandButton
- (void)didClickRaiseHandButton:(UIButton *)btn
{
    if (self.observerIndex != RongRTC_User_Observer)
    {
        [self alertWith:@"" withMessage:NSLocalizedString(@"chat_notice_can_speak", nil) withOKAction:nil withCancleAction:nil];
        return;
    }
    
    isRaiseHandBtnClicked = !isRaiseHandBtnClicked;
    
    if (!isRaiseHandBtnClicked){
        [CommonUtility setButtonImage:btn imageName:@"chat_handup_off"];
//        [self switchButtonBackgroundColor:NO button:btn];
    }
    else{
        [CommonUtility setButtonImage:btn imageName:@"chat_handup_on"];
//        [self switchButtonBackgroundColor:YES button:btn];
    }
}

#pragma mark - show white board with URL
- (void)showWhiteBoardWithURL:(NSString *)wbURL
{
    if (!wbURL || [wbURL isEqualToString:@""] || self.isOpenWhiteBoard){
        DLog(@"showWhiteBoardWithURL return");
        return;
    }

    [_messageStatusBar showMessageBarAndHideAuto:NSLocalizedString(@"chat_Suggested_horizontal_screen_viewing", nil)];

//    NSInteger index = [self.userIDArray indexOfObject:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID];
//    if (index != NSNotFound){
//        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
//        if (self.isSwitchCamera)
//            [self.chatCollectionViewDataSourceDelegateImpl collectionView:self.collectionView didSelectItemAtIndexPath:indexPath];
//    }
  
    self.isWhiteBoardExist = YES;
    self.isNotLeaveMeAlone = YES;
    self.isOpenWhiteBoard = YES;
    self.collectionView.hidden = YES;
    [self showButtonsWithWhiteBoardExist:self.isOpenWhiteBoard];
    if (self.observerIndex == RongRTC_User_Observer)
        [self turnMenuButtonToObserver];
    else
        [self turnMenuButtonToNormal];

    [CommonUtility setButtonImage:self.chatViewBuilder.whiteBoardButton imageName:@"chat_white_board_on"];
 
//    if (self.observerIndex == RongRTC_User_Observer) {
//        [self.localVideoViewModel.cellVideoView removeFromSuperview];
//    }else
//        [self.localView removeFromSuperview];
    if (_isSwitchCamera) {
        [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView removeFromSuperview];
    }else{
        [self.localVideoViewModel.cellVideoView removeFromSuperview];
        [self.localVideoViewModel.avatarView removeFromSuperview];
    }
    [self.videoMainView addSubview:whiteBoardWebView];
    
    NSURL *url = [NSURL URLWithString:wbURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [whiteBoardWebView loadRequest:request];
}

#pragma mark - click videoProfile button
- (void)didClickDownVideoProfileButton:(UIButton *)btn
{
    NSInteger videoProfile = RongRTC_VideoProfile_Invalid;
    if (resolutionIndex == 0) {
        [CommonUtility setButtonImage:btn imageName:@"chat_preview_down_disable"];
//        [self switchButtonBackgroundColor:NO button:btn];
        [self switchMenuButtonEnable:btn withEnable:NO];
        return;
    }
    
//    [self switchButtonBackgroundColor:YES button:btn];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileUpButton withEnable:YES];

    resolutionIndex -= 1;
    switch (resolutionIndex)
    {
        case ResolutionType_1280_720:
          {
              if (frameRateIndex == 0)
                  videoProfile = RongRTC_VideoProfile_1280_720P;
              else if (frameRateIndex == 1)
                  videoProfile = RongRTC_VideoProfile_1280_720P_1;
              else if (frameRateIndex == 2)
                  videoProfile = RongRTC_VideoProfile_1280_720P_2;
          }
            break;
        case ResolutionType_720_480:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_720_480P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_720_480P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_720_480P_2;
        }
            break;
        case ResolutionType_640_480:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_640_480P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_640_480P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_640_480P_2;
        }
            break;
        case ResolutionType_640_368:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_640_360P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_640_360P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_640_360P_2;
        }
            break;
        case ResolutionType_480_368:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_480_360P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_480_360P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_480_360P_2;
        }
            break;
        case ResolutionType_320_240:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_320_240P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_320_240P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_320_240P_2;
        }
            break;
        case ResolutionType_256_144:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_256_144P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_256_144P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_256_144P_2;
            
            [self.rongRTCEngine changeVideoSize:videoProfile];
            [CommonUtility setButtonImage:btn imageName:@"chat_preview_down_disable"];
            [self switchMenuButtonEnable:btn withEnable:NO];

            return;
        }
            break;
        default:
            break;
    }
    
    [CommonUtility setButtonImage:btn imageName:@"chat_preview_down_enable"];
    [self.rongRTCEngine changeVideoSize:videoProfile];
}

- (void)didClickUpVideoProfileButton:(UIButton *)btn
{
    NSInteger videoProfile = RongRTC_VideoProfile_Invalid;
    if (resolutionIndex == maxResolutionIndex) {
        [CommonUtility setButtonImage:self.chatViewBuilder.videoProfileUpButton imageName:@"chat_preview_up_disable"];
//        [self switchButtonBackgroundColor:NO button:btn];
        [self switchMenuButtonEnable:btn withEnable:NO];
        return;
    }
    
//    [self switchButtonBackgroundColor:YES button:btn];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileDownButton withEnable:YES];
  
    resolutionIndex += 1;
    switch (resolutionIndex)
    {
        case ResolutionType_1280_720:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_1280_720P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_1280_720P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_1280_720P_2;
            [self switchMenuButtonEnable:btn withEnable:NO];
            
            [self.rongRTCEngine changeVideoSize:videoProfile];
            [CommonUtility setButtonImage:btn imageName:@"chat_preview_up_disable"];
            return;
        }
            break;
        case ResolutionType_720_480:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_720_480P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_720_480P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_720_480P_2;
        }
            break;
        case ResolutionType_640_480:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_640_480P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_640_480P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_640_480P_2;
        }
            break;
        case ResolutionType_640_368:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_640_360P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_640_360P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_640_360P_2;
        }
            break;
        case ResolutionType_480_368:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_480_360P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_480_360P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_480_360P_2;
        }
            break;
        case ResolutionType_320_240:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_320_240P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_320_240P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_320_240P_2;
        }
            break;
        case ResolutionType_256_144:
        {
            if (frameRateIndex == 0)
                videoProfile = RongRTC_VideoProfile_256_144P;
            else if (frameRateIndex == 1)
                videoProfile = RongRTC_VideoProfile_256_144P_1;
            else if (frameRateIndex == 2)
                videoProfile = RongRTC_VideoProfile_256_144P_2;
           
        }
            break;
        default:
            break;
    }
    
    [CommonUtility setButtonImage:btn imageName:@"chat_preview_up_enable"];
    [self.rongRTCEngine changeVideoSize:videoProfile];

}

#pragma mark - switch playbackMode
- (void)didClickPlaybackModeButton:(UIButton *)btn
{
    if (!popController)
        popController = [[ChatSwitchModeTableViewController alloc]init];
    
    popController.modalPresentationStyle = UIModalPresentationPopover;
    __weak ChatViewController *weakSelf = self;
    popController.videModeBlock = ^(RongRTCVideoMode mode,NSIndexPath *indexPath) {
        weakSelf.selectedIndexPath = indexPath;
        [weakSelf.rongRTCEngine setVideoMode:mode];
    };
    
    popController.selectedIndexPath = _selectedIndexPath;
    
    UIPopoverPresentationController * popover = [popController popoverPresentationController];
    popover.delegate = self;
    popController.preferredContentSize = CGSizeMake(120, 100);//设置浮窗的宽高
    popover.permittedArrowDirections = UIPopoverArrowDirectionRight;//设置箭头位置
    popover.sourceView = self.chatViewBuilder.playbackModeButton;//设置目标视图
    popover.sourceRect = self.chatViewBuilder.playbackModeButton.bounds;//弹出视图显示位置
    popover.backgroundColor = [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];//设置弹窗背景颜色(效果图里红色区域)
    [self.navigationController presentViewController:popController animated:YES completion:nil];
}

#pragma mark - click rotate button
- (void)didcClickRotateButton:(UIButton *)btn
{
    if (self.userIDArray.count <= 0)
        return;
    
    [btn setSelected:!btn.isSelected];
    [self switchButtonBackgroundColor:btn.isSelected button:btn];
    if (btn.isSelected) {
        [CommonUtility setButtonImage:self.chatViewBuilder.rotateButton imageName:@"chat_rotate_on"];
    }else{
        [CommonUtility setButtonImage:self.chatViewBuilder.rotateButton imageName:@"chat_rotate_off"];
    }
}

#pragma mark - rotate screen
- (void)interfaceOrientation:(UIDeviceOrientation)orientation
{
     if (orientation == UIDeviceOrientationLandscapeRight)
     {
        self.view.transform = CGAffineTransformIdentity;
        if (self.observerIndex != RongRTC_User_Observer && [self.localVideoViewModel.userID isEqualToString:kDeviceUUID])
        {
            self.videoMainView.frame = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
            if (self.isSwitchCamera)
            {
                self.localVideoViewModel.cellVideoView.transform = CGAffineTransformMakeRotation(M_PI_2);
                self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, 120, 120) withDisplayType:RongRTC_VideoViewDisplay_FullScreen];
                
                [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.cellVideoView];
 
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(45, 60);
                    if (!self.isOpenWhiteBoard){
                        [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                    }
                }

                self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID: self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                if (!self.isOpenWhiteBoard){
                    [self.videoMainView addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView];
                }
                if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio) {
                    
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    if (!self.isOpenWhiteBoard){
                        [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView  addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }
                }
                
            }else{
                self.localVideoViewModel.cellVideoView.transform = CGAffineTransformMakeRotation(M_PI_2);
                self.localVideoViewModel.cellVideoView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2);
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(self.localView.superview.frame.size.width/2, self.localView.superview.frame.size.height/2);
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                }
            }
        }else{
            if (self.localVideoViewModel) {
                if (!self.isSwitchCamera) {
                    self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.localVideoViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.cellVideoView];
                    self.localVideoViewModel.cellVideoView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2);
                    if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                        self.localVideoViewModel.avatarView.center = CGPointMake(self.localVideoViewModel.cellVideoView.superview.frame.size.width/2, self.localVideoViewModel.cellVideoView.superview.frame.size.height/2);
                        [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                    }
                }else{
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView ];
                    if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None)
                    {
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.frame = BigVideoFrame;
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2); [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }
                }
            }
        }
       
         self.chatViewBuilder.hungUpButton.center = CGPointMake(ScreenWidth/2, ScreenHeight-ButtonWidth);
         self.chatViewBuilder.openCameraButton.center = CGPointMake(ScreenWidth/2 - ButtonDistance - ButtonWidth/2, ScreenHeight-ButtonWidth);
         self.chatViewBuilder.microphoneOnOffButton.center = CGPointMake(ScreenWidth/2 + ButtonDistance+ButtonWidth/2, ScreenHeight-ButtonWidth);
         self.chatViewBuilder.upMenuView.center = CGPointMake(self.videoMainView.frame.size.width - self.homeImageView.frame.size.width/2 - 16.f - ScreenStatusBarHeight, ScreenHeight/2+36);

        self.chatViewBuilder.rotateButton.center = CGPointMake(16.f+18.f, ScreenHeight-44.0);
         if (self.isOpenWhiteBoard)
         {
             whiteBoardWebView.frame = CGRectMake(0, CGRectGetMaxY(self.titleLabel.frame) , self.videoMainView.frame.size.width, self.videoMainView.frame.size.height - CGRectGetMaxY(self.titleLabel.frame)-20 );
             [self.videoMainView bringSubviewToFront:whiteBoardWebView];
             [whiteBoardWebView reload];
         }
         self.messageStatusBar.transform = CGAffineTransformIdentity;
         self.messageStatusBar.frame = CGRectMake(0, 0, ScreenWidth, 20.0);
         self.messageStatusBar.center = CGPointMake(10,ScreenWidth/2);
         self.messageStatusBar.transform = CGAffineTransformMakeRotation(-M_PI_2);
         self.messageStatusBar.messageLabel.frame = self.messageStatusBar.bounds;
         self.chatViewBuilder.playbackModeButton.center = CGPointMake(self.chatViewBuilder.upMenuView.center.x, self.chatViewBuilder.upMenuView.frame.origin.y - 30.0);
         
         UICollectionViewFlowLayout *newLayout = [[UICollectionViewFlowLayout alloc] init];
         newLayout.minimumLineSpacing = 0.0;
         newLayout.minimumInteritemSpacing = 0.0;
         newLayout.itemSize = CGSizeMake(90, 120.0);
         newLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
//         [self.collectionView.collectionViewLayout invalidateLayout];
         [self.collectionView setCollectionViewLayout:newLayout animated:NO];
         [self.collectionView setNeedsLayout];
         
         _collectionViewTopMargin.constant = (- _statuView.frame.origin.y - _statuView.frame.size.height);
         _collectionViewTrailingMargin.constant = ScreenWidth-90.0 - ScreenExtraSpace;
         _collectionViewLeadingMargin.constant = ScreenExtraSpace;
         _collectionViewHeightConstraint.constant = ScreenHeight;
    }else if (orientation == UIDeviceOrientationPortrait)
    {
        self.view.transform = CGAffineTransformIdentity;
        self.localVideoViewModel.cellVideoView.transform = CGAffineTransformIdentity;
        self.messageStatusBar.transform = CGAffineTransformIdentity;
        CGFloat actualScreenWidth = ScreenWidth;
        CGFloat actualScreenHeight = ScreenHeight;
        if (ScreenWidth > ScreenHeight) {
            actualScreenWidth = ScreenHeight;
            actualScreenHeight = ScreenWidth;
        }
        NSInteger version = [[[UIDevice currentDevice] systemVersion] integerValue];
        if (version == 11) {
            self.messageStatusBar.frame = CGRectMake(0,[UIApplication sharedApplication].statusBarFrame.size.height, actualScreenWidth, 20.0);
            self.messageStatusBar.center = CGPointMake(actualScreenWidth/2,[UIApplication sharedApplication].statusBarFrame.size.height + 10.0);
        }else{
            self.messageStatusBar.frame = CGRectMake(0, 0, actualScreenWidth, 20.0);
            self.messageStatusBar.center = CGPointMake(actualScreenWidth/2, 10.0);
        }
        self.messageStatusBar.messageLabel.frame = self.messageStatusBar.bounds;
        
    
        if (self.observerIndex != RongRTC_User_Observer && [self.localVideoViewModel.userID isEqualToString:kDeviceUUID]) {
            if (self.isSwitchCamera) {
                self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, 60, 120) withDisplayType:RongRTC_VideoViewDisplay_FullScreen];
                [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.cellVideoView];
                
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(45, 60);
                    [self.localVideoViewModel.cellVideoView addSubview:self.localVideoViewModel.avatarView];
                }else
                {
                    [self.localVideoViewModel.avatarView removeFromSuperview];
                }
                
                self.videoMainView.frame = CGRectMake(0, 0, actualScreenWidth, actualScreenHeight);
                UIView *remoteVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID: self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                if (!self.isOpenWhiteBoard){
                    [self.videoMainView addSubview:remoteVideoView];
                }
                
                [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, 90, 120) withDisplayType:RongRTC_VideoViewDisplay_FullScreen];

                if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio) {
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    if (!self.isOpenWhiteBoard){
                        [remoteVideoView addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }

                }
            }else{
                self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, actualScreenWidth,actualScreenHeight) withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                self.localVideoViewModel.cellVideoView.center = CGPointMake(actualScreenWidth/2, actualScreenHeight/2);
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                }else
                {
                    [self.localVideoViewModel.avatarView removeFromSuperview];
                }
            }
        }else{
            if (self.localVideoViewModel) {
                if (!self.isSwitchCamera) {
                    self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.localVideoViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.localVideoViewModel.cellVideoView.superview addSubview: self.localVideoViewModel.cellVideoView];
                    self.localVideoViewModel.cellVideoView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                        self.localVideoViewModel.avatarView.center = CGPointMake(self.localVideoViewModel.cellVideoView.frame.size.width/2, self.localVideoViewModel.cellVideoView.frame.size.height/2);
                        [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                    }
                }else{
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView ];
                    if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None)
                    {
                        
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.frame = BigVideoFrame;
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(actualScreenWidth/2, actualScreenHeight/2); [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }
                }
        }
        }
        
        self.chatViewBuilder.hungUpButton.center = CGPointMake(actualScreenWidth/2, actualScreenHeight-ButtonWidth);
        self.chatViewBuilder.openCameraButton.center = CGPointMake(actualScreenWidth/2 - ButtonDistance - ButtonWidth/2, actualScreenHeight-ButtonWidth);
        self.chatViewBuilder.microphoneOnOffButton.center = CGPointMake(actualScreenWidth/2 + ButtonDistance+ButtonWidth/2, actualScreenHeight-ButtonWidth);
      
        CGFloat centerY = MAX(actualScreenHeight/2+(8*36+7*10)/2, self.dataTrafficLabel.frame.origin.y+self.dataTrafficLabel.frame.size.height + 130.0 + (8*36+7*10));
        centerY = MAX(ScreenHeight/2+(6*36+5*10)/2, self.dataTrafficLabel.frame.origin.y+self.dataTrafficLabel.frame.size.height + 130.0 + (6*36+5*10));
        self.chatViewBuilder.upMenuView.center = CGPointMake(self.view.frame.size.width - self.homeImageView.frame.size.width/2 - 16.f, self.chatViewBuilder.originCenter.y - 120.0);
        self.chatViewBuilder.rotateButton.center = CGPointMake(16.f+18.f, actualScreenHeight-44.0);
        if (self.isOpenWhiteBoard) {
            whiteBoardWebView.frame = CGRectMake(0, ScreenHeight/3 , self.videoMainView.frame.size.width, ScreenHeight/2);
            [self.videoMainView bringSubviewToFront:whiteBoardWebView];
            [whiteBoardWebView reload];
        }
        self.chatViewBuilder.playbackModeButton.center = CGPointMake(self.chatViewBuilder.upMenuView.center.x, self.chatViewBuilder.upMenuView.frame.origin.y - 30.0);

        if (_collectionViewLayout) {
            self.collectionView.collectionViewLayout = _collectionViewLayout;
        }
        
        _collectionViewTopMargin.constant = 0;
        _collectionViewTrailingMargin.constant = 0.0;
        _collectionViewLeadingMargin.constant = 0.0;
        _collectionViewHeightConstraint.constant = 120.0;
        
    }else if (orientation == UIDeviceOrientationLandscapeLeft) {
        self.view.transform = CGAffineTransformIdentity;
        self.localVideoViewModel.cellVideoView.transform = CGAffineTransformIdentity;
 
        self.messageStatusBar.transform = CGAffineTransformIdentity;
        self.messageStatusBar.frame = CGRectMake(0, 0, ScreenWidth, 20.0);
        self.messageStatusBar.center = CGPointMake(ScreenHeight - 10,ScreenWidth/2);
        self.messageStatusBar.transform = CGAffineTransformMakeRotation(M_PI_2);
        self.messageStatusBar.messageLabel.frame = self.messageStatusBar.bounds;
        
        if (self.observerIndex != RongRTC_User_Observer && [self.localVideoViewModel.userID isEqualToString:kDeviceUUID]) {
            if (self.isSwitchCamera) {
                self.localVideoViewModel.cellVideoView.transform = CGAffineTransformMakeRotation(-M_PI_2);
                self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, 120, 120) withDisplayType:RongRTC_VideoViewDisplay_FullScreen];
                [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.cellVideoView];
 
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(45, 60);
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                }
                
                UIView *remoteVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID: self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                if (!self.isOpenWhiteBoard){
                    [self.videoMainView addSubview:remoteVideoView];
                }
                if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio) {
                    
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    if (!self.isOpenWhiteBoard){
                        [remoteVideoView addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }
                }
                
            }else{
                self.localVideoViewModel.cellVideoView.transform = CGAffineTransformMakeRotation(-M_PI_2);
                self.localVideoViewModel.cellVideoView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2);
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(self.localVideoViewModel.cellVideoView.frame.size.width/2, self.localVideoViewModel.cellVideoView.frame.size.height/2);
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                }
            }
        }else{
            if (self.localVideoViewModel) {
                if (!self.isSwitchCamera) {
                    self.localVideoViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.localVideoViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.cellVideoView];
 
                    if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                        self.localVideoViewModel.avatarView.center = CGPointMake(self.localVideoViewModel.cellVideoView.frame.size.width/2, self.localVideoViewModel.cellVideoView.frame.size.height/2);
                        [self.localVideoViewModel.cellVideoView.superview addSubview:self.localVideoViewModel.avatarView];
                    }
                }else{
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                    [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView ];
                    if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None)
                    {
                        
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.frame = BigVideoFrame;
                        self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2); [self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.cellVideoView.superview addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                    }
                }
            }

        }
        
        self.chatViewBuilder.hungUpButton.center = CGPointMake(ScreenWidth/2, ScreenHeight-ButtonWidth);
        self.chatViewBuilder.openCameraButton.center = CGPointMake(ScreenWidth/2 - ButtonDistance - ButtonWidth/2, ScreenHeight-ButtonWidth);
        self.chatViewBuilder.microphoneOnOffButton.center = CGPointMake(ScreenWidth/2 + ButtonDistance+ButtonWidth/2, ScreenHeight-ButtonWidth);
        self.chatViewBuilder.upMenuView.center = CGPointMake(self.view.frame.size.width - self.homeImageView.frame.size.width/2 - 16.f, ScreenHeight/2+36);
        self.chatViewBuilder.rotateButton.center = CGPointMake(16.f+18.f, ScreenHeight-44.0);
        
        if (self.isOpenWhiteBoard) {
            whiteBoardWebView.frame = CGRectMake(0, CGRectGetMaxY(self.titleLabel.frame) , self.videoMainView.frame.size.width, self.videoMainView.frame.size.height - CGRectGetMaxY(self.titleLabel.frame)-20 );
            [self.videoMainView bringSubviewToFront:whiteBoardWebView];
            [whiteBoardWebView reload];
        }
        
        self.chatViewBuilder.playbackModeButton.center = CGPointMake(self.chatViewBuilder.upMenuView.center.x, self.chatViewBuilder.upMenuView.frame.origin.y - 30.0);
       
        UICollectionViewFlowLayout *newLayout = [[UICollectionViewFlowLayout alloc] init];
        newLayout.minimumLineSpacing = 0.0;
        newLayout.minimumInteritemSpacing = 0.0;
        newLayout.itemSize = CGSizeMake(90, 120.0);
        newLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        [self.collectionView setCollectionViewLayout:newLayout animated:NO];
        [self.collectionView setNeedsLayout];
        
        _collectionViewTopMargin.constant = (- _statuView.frame.origin.y - _statuView.frame.size.height);
        _collectionViewTrailingMargin.constant = ScreenWidth - 90.0 - ScreenStatusBarHeight;
        _collectionViewLeadingMargin.constant = 0.0 + ScreenStatusBarHeight;
        _collectionViewHeightConstraint.constant = ScreenHeight;
    }else{
        self.messageStatusBar.transform = CGAffineTransformIdentity;
        self.messageStatusBar.frame = [UIApplication sharedApplication].statusBarFrame;
        self.messageStatusBar.center = CGPointMake(ScreenWidth/2, ScreenHeight-10.0);
        self.messageStatusBar.transform = CGAffineTransformMakeRotation(M_PI );
        self.messageStatusBar.messageLabel.frame = self.messageStatusBar.bounds;

        if (deviceOrientaionBefore != UIDeviceOrientationLandscapeRight && deviceOrientaionBefore != UIDeviceOrientationLandscapeLeft) {
            self.localView.transform = CGAffineTransformIdentity;
            self.videoMainView.frame = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
             self.localView.transform = CGAffineTransformMakeRotation(M_PI );
            return;
        }
        
        //屏幕倒置
        self.videoMainView.frame = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
        self.localView.transform = CGAffineTransformIdentity;
        self.view.transform = CGAffineTransformIdentity;
        if (deviceOrientaionBefore == UIDeviceOrientationLandscapeLeft) {
            self.localView.transform = CGAffineTransformMakeRotation(-M_PI );
        }else if (deviceOrientaionBefore == UIDeviceOrientationLandscapeRight) {
            self.localView.transform = CGAffineTransformMakeRotation(M_PI );
        }
        
        if (self.observerIndex != RongRTC_User_Observer && [self.localVideoViewModel.userID isEqualToString:kDeviceUUID]) {
            self.videoMainView.frame = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
            if (self.isSwitchCamera) {
                self.localView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, 120, 120) withDisplayType:RongRTC_VideoViewDisplay_FullScreen];
                [self.localVideoViewModel.cellVideoView.superview addSubview:self.localView];
                
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(45, 60);
                    [self.localVideoViewModel.cellVideoView addSubview:self.localVideoViewModel.avatarView];
                }
                
                UIView *remoteVideoView = [self.rongRTCEngine changeRemoteVideoViewFrame:self.videoMainView.frame withUserID: self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.userID withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
                [self.videoMainView addSubview:remoteVideoView];
                if (self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Audio_Video_None || self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avType == RongRTC_User_Only_Audio) {
                    if (!self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView) {
                    }
                    self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width/2, self.videoMainView.frame.size.height/2);
                    [remoteVideoView addSubview:self.chatCollectionViewDataSourceDelegateImpl.originalSelectedViewModel.avatarView];
                }
            }else{
                self.localView.center = CGPointMake(ScreenWidth/2, ScreenHeight/2);
                if (self.localVideoViewModel.avType == RongRTC_User_Audio_Video_None || self.localVideoViewModel.avType == RongRTC_User_Only_Audio) {
                    self.localVideoViewModel.avatarView.center = CGPointMake(self.localView.superview.frame.size.width/2, self.localView.superview.frame.size.height/2);
                }
            }
        }
        
        self.chatViewBuilder.hungUpButton.center = CGPointMake(ScreenWidth/2, ScreenHeight-ButtonWidth);
        self.chatViewBuilder.openCameraButton.center = CGPointMake(ScreenWidth/2 - ButtonDistance - ButtonWidth/2, ScreenHeight-ButtonWidth);
        self.chatViewBuilder.microphoneOnOffButton.center = CGPointMake(ScreenWidth/2 + ButtonDistance+ButtonWidth/2, ScreenHeight-ButtonWidth);
        
        self.chatViewBuilder.upMenuView.center = CGPointMake(self.view.frame.size.width - self.homeImageView.frame.size.width/2 - 16.f, ScreenHeight/2+36/2);
        self.chatViewBuilder.rotateButton.center = CGPointMake(16.f+18.f, ScreenHeight-44.0);
        
        if (self.isOpenWhiteBoard) {
            whiteBoardWebView.frame = CGRectMake(0, CGRectGetMaxY(self.titleLabel.frame) , self.videoMainView.frame.size.width, self.videoMainView.frame.size.height - CGRectGetMaxY(self.titleLabel.frame) );
            [whiteBoardWebView reload];
        }

        self.chatViewBuilder.playbackModeButton.center = CGPointMake(self.chatViewBuilder.upMenuView.center.x, self.chatViewBuilder.upMenuView.frame.origin.y - 30.0);
        self.collectionView.collectionViewLayout = _collectionViewLayout;
        _collectionViewTopMargin.constant = 0;
        _collectionViewTrailingMargin.constant = 0.0;
        _collectionViewHeightConstraint.constant = 120.0;
    }
}

#pragma mark - click hungup button
- (void)didClickHungUpButton
{
    if (self.observerIndex == RongRTC_User_Observer) {
        RongRTCTalkAppDelegate *appDelegate = (RongRTCTalkAppDelegate *)[UIApplication sharedApplication].delegate;
        appDelegate.isForceLandscape = NO;
        [appDelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:self.view.window];
        self.localView.transform = CGAffineTransformIdentity;
        self.isOpenWhiteBoard = NO;
        self.localView.hidden = NO;
        [self showAlertLabelWithString:NSLocalizedString(@"chat_exiting", nil)];
        [self.rongRTCEngine leaveChannel];
        return;
    }
    
    if (self.isWhiteBoardExist && self.userIDArray.count == 0 && self.isNotLeaveMeAlone)
    {
        [self alertWith:@"" withMessage:        NSLocalizedString(@"chat_notice_exit_with_whiteboard", nil)
 withOKAction: [UIAlertAction actionWithTitle:        NSLocalizedString(@"chat_alert_btn_yes", nil)
 style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
             RongRTCTalkAppDelegate *appDelegate = (RongRTCTalkAppDelegate *)[UIApplication sharedApplication].delegate;
     
             appDelegate.isForceLandscape = NO;
     
             [appDelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:self.view.window];
            self.localView.transform = CGAffineTransformIdentity;

             self.isOpenWhiteBoard = NO;
             self.localView.hidden = NO;
             [self.localVideoViewModel.avatarView removeFromSuperview];
            [self showAlertLabelWithString:NSLocalizedString(@"chat_exiting", nil)];
            [self.rongRTCEngine leaveChannel];
        }] withCancleAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_no", nil) style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
    }
    else
    {
        RongRTCTalkAppDelegate *appDelegate = (RongRTCTalkAppDelegate *)[UIApplication sharedApplication].delegate;
        appDelegate.isForceLandscape = NO;
        [appDelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:self.view.window];
        self.localView.transform = CGAffineTransformIdentity;
        self.isOpenWhiteBoard = NO;
        [self.localVideoViewModel.avatarView removeFromSuperview];
        self.localView.hidden = NO;
        [self showAlertLabelWithString:NSLocalizedString(@"chat_exiting", nil)];
        [self.rongRTCEngine leaveChannel];
    }
}

#pragma mark - resume local/remote video view
- (void)resumeLocalView:(NSIndexPath *)indexPath
{
    NSInteger removeRow = indexPath.row;
    if (self.isSwitchCamera && removeRow == self.orignalRow)
    {
        self.localView = [self.rongRTCEngine changeLocalVideoViewFrame:CGRectMake(0, 0, ScreenWidth, ScreenHeight) withDisplayType:RongRTC_VideoViewDisplay_CompleteView];
        [self.videoMainView addSubview:self.localView];
        self.isSwitchCamera = !self.isSwitchCamera;
        self.orignalRow = -1;
    }
}

#pragma mark - turnMenuButtonToNormal
- (void)turnMenuButtonToNormal
{
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.raiseHandButton];
    [self switchMenuButtonEnable:self.chatViewBuilder.raiseHandButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.playbackModeButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.whiteBoardButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.switchCameraButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.openCameraButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.speakerOnOffButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.microphoneOnOffButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.startRecordingButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.stopRecordingButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.playRecordButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileDownButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileUpButton withEnable:YES];
}

#pragma mark - turnMenuButtonToObserver
- (void)turnMenuButtonToObserver
{
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.raiseHandButton];
    [self switchMenuButtonEnable:self.chatViewBuilder.raiseHandButton withEnable:YES];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.playbackModeButton];
    [self switchMenuButtonEnable:self.chatViewBuilder.playbackModeButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.raiseHandButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.whiteBoardButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.switchCameraButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.openCameraButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.speakerOnOffButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.microphoneOnOffButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.startRecordingButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.stopRecordingButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.playRecordButton withEnable:YES];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileUpButton withEnable:NO];
    [self switchMenuButtonEnable:self.chatViewBuilder.videoProfileDownButton withEnable:NO];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.openCameraButton];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.microphoneOnOffButton];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.openCameraButton];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.videoProfileUpButton];
    [self switchButtonBackgroundColor:NO button:self.chatViewBuilder.videoProfileDownButton];
}

#pragma mark = reset Btns
- (void)switchMenuButtonEnable:(UIButton *)button withEnable:(BOOL)enable
{
    button.enabled = enable;
    button.tintColor = enable ? [UIColor blackColor] : kUnableButtonColor;
}

#pragma mark - reset audio speaker button
- (void)resetAudioSpeakerButton
{
    self.isNotMute = NO;
    [self.rongRTCEngine muteMicrophone:self.isNotMute];
    [self switchButtonBackgroundColor:self.isNotMute button:self.chatViewBuilder.microphoneOnOffButton];
    [CommonUtility setButtonImage:self.chatViewBuilder.microphoneOnOffButton imageName:@"chat_microphone_on"];
    
    self.isSpeaker = YES;
    [self.rongRTCEngine switchSpeaker:self.isSpeaker];
    [self switchButtonBackgroundColor:!self.isSpeaker button:self.chatViewBuilder.speakerOnOffButton];
    [CommonUtility setButtonImage:self.chatViewBuilder.speakerOnOffButton imageName:@"chat_speaker_on"];
    
    [CommonUtility setButtonImage:silienceButton imageName:@"chat_menu"];
}

#pragma mark - switch menu button color
- (void)switchButtonBackgroundColor:(BOOL)is button:(UIButton *)btn
{
    btn.backgroundColor = is ? [UIColor whiteColor] : [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.4f];
}

#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.jsContext = [whiteBoardWebView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    self.jsContext[@"iosDelegate"] = self;//挂上代理  iosDelegate是window.document.iosDelegate.getImage(JSON.stringify(parameter)); 中的 iosDelegate
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception){
        context.exception = exception;
        DLog(@"LLH...... 获取 self.jsContext 异常信息：%@",exception);
    };
}

#pragma mark - JSDelegate
- (void)getImage:(id)parameter
{
    // 把 parameter json字符串解析成字典
    NSString *jsonStr = [NSString stringWithFormat:@"%@", parameter];
    NSDictionary *jsParameDic = [NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding ] options:NSJSONReadingAllowFragments error:nil];
    DLog(@"LLH...... js传来的json字典: %@", jsParameDic);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //[self takePhoto]; // 主队列 异步打开相机
        [self localPhoto];// 主队列 异步打开相册
    });
}

- (void)localPhoto
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

//  选择一张照片后进入这里
#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    //  当前选择的类型是照片
    if ([type isEqualToString:@"public.image"])
    {
        // 获取照片
        UIImage *getImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SealRTC"];
        BOOL isDir = TRUE;
        BOOL isExistDir = [fileManager fileExistsAtPath:path isDirectory:&isDir];
        if (!isExistDir)
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSString *imagePath = [path stringByAppendingPathComponent:@"uploadtemp.jpg"];
        BOOL isExist = [fileManager fileExistsAtPath:imagePath];
        if (isExist)
            [fileManager removeItemAtPath:imagePath error:NULL];
        
        NSData *imgData = UIImageJPEGRepresentation(getImage, 0.9);
        [imgData writeToFile:imagePath atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            JSValue *jsValue = self.jsContext[@"setImageWithPath"];
            [jsValue callWithArguments:@[@{@"imagePath":imagePath, @"iosContent":@""}]];
        });
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - ChatType
- (void)setType:(ChatType)type
{
    _type = type;
    if (type == ChatTypeVideo)
    {
        // Control buttons
        self.videoMainView.hidden = NO;
    }
    else
    {
        // Control buttons
        self.videoMainView.hidden = YES;
    }
    [self.collectionView reloadData];
}

- (void)onChatDeviceOrientationChange
{
    [self.chatViewBuilder reloadChatView];
}

#pragma mark - Speaker/Audio/Video button selected
- (void)selectSpeakerButtons:(BOOL)selected
{
    _speakerControlButton.selected = selected;
}

- (void)selectAudioMuteButtons:(BOOL)selected
{
    _audioMuteControlButton.selected = selected;
}

- (void)selectVideoMuteButtons:(BOOL)selected
{
    _cameraControlButton.selected = selected;
}

- (BOOL)isHeadsetPluggedIn
{
    AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [route outputs])
    {
        NSString *outputer = desc.portType;
        if ([outputer isEqualToString:AVAudioSessionPortHeadphones] || [outputer isEqualToString:AVAudioSessionPortBluetoothLE] || [outputer isEqualToString:AVAudioSessionPortBluetoothHFP] || [outputer isEqualToString:AVAudioSessionPortBluetoothA2DP])
            return YES;
    }
    return NO;
}

- (void)modifyAudioVideoType:(UIButton *)btn
{
    self.isCloseCamera = !self.isCloseCamera;
    [self.rongRTCEngine closeLocalVideo:self.isCloseCamera];
//    self.localView.hidden = self.isCloseCamera;
    [self switchButtonBackgroundColor:self.isCloseCamera button:btn];
    
    if (self.isCloseCamera)
    {
        [CommonUtility setButtonImage:btn imageName:@"chat_close_camera"];
 
        self.localVideoViewModel.avatarView.frame = BigVideoFrame;
        [self.videoMainView addSubview:self.localVideoViewModel.avatarView];
        self.localVideoViewModel.avatarView.center = CGPointMake(self.videoMainView.frame.size.width / 2, self.videoMainView.frame.size.height / 2);
    }
    else
    {
        [self.localVideoViewModel.avatarView removeFromSuperview];
        [CommonUtility setButtonImage:btn imageName:@"chat_open_camera"];
    }
}

- (void)updateAudioVideoType:(RongRTCAudioVideoType)type
{
    @synchronized(self){
    switch (type) {
        case RongRTC_User_Only_Audio:
            if (self.isNotMute) { //NO
                [self muteAudioButton:self.chatViewBuilder.microphoneOnOffButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Micphone open:YES];
            }
            if (!self.isCloseCamera) { //NO
                [self muteVideoButton:self.chatViewBuilder.openCameraButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Camera open:NO];
            }
            self.localVideoViewModel.avType = RongRTC_User_Only_Audio;
            break;
        case RongRTC_User_Audio_Video_None:
            {
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_CameraMicphone open:NO];
                if (!self.isNotMute) { //如果开启状态,关闭
                    [self muteAudioButton:self.chatViewBuilder.microphoneOnOffButton];
                }
                if (!self.isCloseCamera) { //
                    [self muteVideoButton:self.chatViewBuilder.openCameraButton];
                }
                self.localVideoViewModel.avType = RongRTC_User_Audio_Video_None;
            }
   
            break;
        case RongRTC_User_Audio_Video:
        {
            if (self.isNotMute) {
                [self muteAudioButton:self.chatViewBuilder.microphoneOnOffButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Micphone open:YES];
            }
            if (self.isCloseCamera) {
                [self muteVideoButton:self.chatViewBuilder.openCameraButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Camera open:YES];
            }
            self.localVideoViewModel.avType = RongRTC_User_Audio_Video;
         }
            break;
        case RongRTC_User_Only_Video:
            if (!self.isNotMute) {
                [self muteAudioButton:self.chatViewBuilder.microphoneOnOffButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Micphone open:NO];
            }
            if (self.isCloseCamera) {
                [self muteVideoButton:self.chatViewBuilder.openCameraButton];
                [self.rongRTCEngine controlAudioVideoDevice:RongRTC_Device_Camera open:YES];
            }
            self.localVideoViewModel.avType = RongRTC_User_Only_Video;

            break;
        default:
            break;
    }
    }
}

- (void)enableButton:(UIButton *)btn enable:(BOOL)flag
{
//    if (flag) {
//        [btn setTintColor:[UIColor blackColor]];
//        [btn setEnabled:YES];
//    }else{
//        [btn setTintColor:[UIColor colorWithRed:187.0/255.0 green:187.0/255.0 blue:187.0/255.0 alpha:1.0]];
//        [btn setEnabled:NO];
//    }
}

- (void)deleteTempFileFromDocuments
{
    NSString *diaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SealRTC"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:diaryDirectory error:NULL];
    NSEnumerator *enu = [contents objectEnumerator];
    NSString *filename;
    while (filename = [enu nextObject])
        [fileManager removeItemAtPath:[diaryDirectory stringByAppendingPathComponent:filename] error:NULL];
    
    //    NSString *captureDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"capture"];
    NSFileManager *captureFileManager = [NSFileManager defaultManager];
    NSArray *captureContents = [captureFileManager contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    NSEnumerator *captureEnu = [captureContents objectEnumerator];
    NSString *captureFilename;
    while (captureFilename = [captureEnu nextObject])
    {
        if ([captureFilename containsString:@"capture"] || [captureFilename containsString:@"trim."] )
            [captureFileManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:captureFilename] error:NULL];
    }
}

#pragma mark - AlertController
- (void)alertWith:(NSString *)title withMessage:(NSString *)msg withOKAction:(nullable  UIAlertAction *)ok withCancleAction:(nullable UIAlertAction *)cancel
{
    self.alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    if (cancel)
        [self.alertController addAction:cancel];
    if (!ok){
        UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"chat_alert_btn_confirm", nil) style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
            [self.alertController dismissViewControllerAnimated:YES completion:nil];
        }];
        [self.alertController addAction:ok];

    }else{
        [self.alertController addAction:ok];
    }
    [self presentViewController:self.alertController animated:YES completion:^{}];
    
}

#pragma mark: - UIPopoverPresentationControllerDelegate
//-(UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
//{
//    return UIModalPresentationNone;
//}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection
{
    return UIModalPresentationNone;

}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    return YES;//点击蒙版popover消失， 默认YES
}

@end
