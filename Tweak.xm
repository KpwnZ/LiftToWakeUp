#import <SpringBoard/SpringBoard.h>
#import <CoreMotion/CoreMotion.h>

@interface SBHomeHardwareButtonActions : NSObject
-(id)init;
-(void)performSinglePressUpActions;
@end

@interface SBLockScreenManager : NSObject
+(id)_sharedInstanceCreateIfNeeded:(BOOL)arg1 ;
+(id)sharedInstance;
+(id)sharedInstanceIfExists;
-(id)init;
@property (nonatomic, retain) CMMotionManager *motionManager;
@end

typedef NS_ENUM(NSInteger,DeviceMotionType){
    Portrait,
    UpsideDown,
    LandscapeLeft,
    LandscapeRight,
    Unknown
};

static DeviceMotionType motionType = Unknown;



@implementation CMMotionManager(update)
-(void)update {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateData) userInfo:nil repeats:YES];
    if (!timer)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateData) userInfo:nil repeats:YES];
    }
}

-(void)updateData {
    [[%c(SBLockScreenManager) sharedInstance] wakeUp];
}
@end


%hook SBLockScreenManager
%property (nonatomic, retain) CMMotionManager *motionManager;
-(id)init {

    //[[LiftToWakeUpManager alloc] init];
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 1 / 5.0;
    [self.motionManager update];
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *accelerometerData, NSError *error) {
        [self updateMotionType];
    }];

    return %orig;
}

%new
-(void)updateMotionTimer {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateMotionType) userInfo:nil repeats:YES];
    if (!timer)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateMotionType) userInfo:nil repeats:YES];
    }
}

%new
-(void)updateMotionType {

    DeviceMotionType nowMotionType = Unknown;

    float x = self.motionManager.deviceMotion.gravity.x;
    float y = self.motionManager.deviceMotion.gravity.y;
    float z = self.motionManager.deviceMotion.gravity.z;

    // z (-0.6, 0)
    // y (-1, -0.45)
    // x (-0.45, 0.45)

    NSLog(@"DeviceMotionType updateMotionType x=%f y=%f z=%f", x, y, z);

    if (fabs(x) < 0.45 && y < -0.45 && y > -1 && z < 0 && z < 60)
    {
        nowMotionType = Portrait;
    }

    if (nowMotionType != motionType && nowMotionType != Unknown)
    {
        [self wakeUp];
    }
    
    motionType = nowMotionType;
}

%new
-(void)wakeUp {
    while([[[%c(SBLockScreenManager) sharedInstance] dashBoardViewController] isInScreenOffMode]) {
        [[UIApplication sharedApplication] _simulateHomeButtonPress];
    }
    motionType = Unknown;
}
%end