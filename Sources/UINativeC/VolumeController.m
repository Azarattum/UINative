#import "include/VolumeController.h"

@interface AVSystemController
+ (instancetype)sharedAVSystemController;
-(BOOL)setVolumeTo:(float)arg1 forCategory:(id)arg2 ;
-(BOOL)getVolume:(float *)arg1 forCategory:(id)arg2 ;
@end

@implementation VolumeController

+ (void) setVolume: (float)to {
    AVSystemController *controller = [AVSystemController sharedAVSystemController];
    [controller setVolumeTo:to forCategory:@"Audio/Video"];
}

+ (float) getVolume {
    AVSystemController *controller = [AVSystemController sharedAVSystemController];

    float volume = 0;
    [controller getVolume:&volume forCategory:@"Audio/Video"];
    return volume;
}

@end