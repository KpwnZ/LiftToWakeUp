#import <SpringBoard/SpringBoard.h>
#import <CoreMotion/CoreMotion.h>
// #import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOReturn.h>

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
    FaceUp,
    FaceDown,
    LandscapeLeft,
    LandscapeRight,
    Unknown
};

static DeviceMotionType motionType = Unknown;
#define isPuttingDownDevice(newMotion) (motionType == Portrait && newMotion == FaceUp)
#define isTurningDownDevice(newMotion) (motionType != FaceDown && newMotion == FaceDown)

@interface SystemSleepManager : NSObject
{
    IOPMAssertionID displaySleepAssertionID;
    IOPMAssertionID idleSleepAssertionID;
}
-(void)disableOrEnableIdleSleep:(BOOL)arg1;
@end

@implementation SystemSleepManager
-(void)disableOrEnableIdleSleep:(BOOL)arg1 {
    if (!idleSleepAssertionID && arg1) {
        // CFSTR("NoIdleSleepAssertion") 255
        IOPMAssertionCreate(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn, &idleSleepAssertionID);
        NSLog(@"SystemSleepManager: disable system sleep");
    } else {
        IOPMAssertionRelease(idleSleepAssertionID);
        idleSleepAssertionID = 0;
    }
}
@end

@implementation CMMotionManager(update)
-(void)update {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateData) userInfo:nil repeats:YES];
    if (!timer)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateData) userInfo:nil repeats:YES];
    }
}

-(void)updateData {
    [[%c(SBLockScreenManager) sharedInstance] updateMotionType];
}
@end


%hook SBLockScreenManager
%property (nonatomic, retain) CMMotionManager *motionManager;
-(id)init {

    //[[LiftToWakeUpManager alloc] init];
    SystemSleepManager *ssm = [[SystemSleepManager alloc] init];
    [ssm disableOrEnableIdleSleep:YES];
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 1 / 25.0;
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

    if (fabs(x) < 0.45 && y < -0.45 && y > -1 && z <= 0 && z > -0.6)
    {
        nowMotionType = Portrait;
    }else if (fabs(y) <= 0.15 && z <= -0.8)
    {
        nowMotionType = FaceUp;
    }else if (fabs(y) <= 0.15 && z >= 0.8)
    {
        nowMotionType = FaceDown;
    }

    if (nowMotionType != motionType)
    {
        if (nowMotionType == Portrait)
        {
            [self wakeUp];
        }else if (isPuttingDownDevice(nowMotionType) || isTurningDownDevice(nowMotionType))
        {
            [self lockDevice];
        }
    }
    
    motionType = nowMotionType;
}

%new
-(void)wakeUp {
    if (![[UIApplication sharedApplication] isLocked])
    {
        return;
    }
    while([[[%c(SBLockScreenManager) sharedInstance] dashBoardViewController] isInScreenOffMode]) {
        [[UIApplication sharedApplication] _simulateHomeButtonPress];
    }
    motionType = Unknown;
}

%new
-(void)lockDevice {
    if (![[UIApplication sharedApplication] isLocked])
    {
        return;
    }
    if(![[[%c(SBLockScreenManager) sharedInstance] dashBoardViewController] isInScreenOffMode]) { // it will take some time to lock screen, so while(screenOff) should be replaced.
        [[UIApplication sharedApplication] _simulateLockButtonPress];
    }
    motionType = Unknown;
}

%end