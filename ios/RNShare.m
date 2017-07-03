#import <MessageUI/MessageUI.h>
#import "RNShare.h"
#import "RCTConvert.h"

@implementation RNShare

static NSString *const tempFilePath = @"MyThingNotificationKey";

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(open:(NSDictionary *)options :(RCTResponseSenderBlock)callback)
{
    NSString *shareFile = [RCTConvert NSString:options[@"share_file"]];
    
    // Checks if http or https
    BOOL isRemote = [NSURL URLWithString:shareFile].scheme;
    // Check if limited
    BOOL isLimited = [RCTConvert BOOL:options[@"limited"]];
    
    NSURL *fileToShare;
    if (isRemote) {
        // Download file first
        NSURL *fileUrl = [NSURL URLWithString:shareFile];
        fileToShare = [self downloadFile:fileUrl];
    } else {
        fileToShare = [NSURL fileURLWithPath:shareFile];
    }
    
    if (fileToShare) {
        [self displayDocument:fileToShare isLimited:isLimited callback:callback];
    }
}

- (void) displayDocument:(NSURL*)fileUrl isLimited:(BOOL)isLimited callback:(RCTResponseSenderBlock)callback {
    UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    NSArray *items = @[fileUrl];
    UIActivityViewController *activityController = [[UIActivityViewController alloc]initWithActivityItems:items applicationActivities:nil];

    if (isLimited) {
        activityController.excludedActivityTypes = @[UIActivityTypeAirDrop,
                                                    UIActivityTypeAddToReadingList,
                                                    UIActivityTypeCopyToPasteboard,
                                                    UIActivityTypeSaveToCameraRoll,
                                                    UIActivityTypePrint,
                                                    UIActivityTypeAssignToContact,
                                                    UIActivityTypeCopyToPasteboard,
                                                    @"com.apple.reminders.RemindersEditorExtension",
                                                    @"com.apple.mobilenotes.SharingExtension",
                                                    @"com.apple.mobileslideshow.StreamShareService"];
    }
    
    // For iPad only
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityController.modalPresentationStyle = UIModalPresentationPopover;
        
        UIPopoverPresentationController *presentationController = activityController.popoverPresentationController;
        [presentationController setDelegate:self];
        presentationController.permittedArrowDirections = 0;
        presentationController.sourceView = [[UIApplication sharedApplication] keyWindow];
        presentationController.sourceRect = [[UIApplication sharedApplication] keyWindow].bounds;
        
        [ctrl setPreferredContentSize:CGSizeMake(320, 480)];
    }
    
    [ctrl presentViewController:activityController animated:YES completion:^{
        callback(@[[NSNull null]]);
    }];
}

- (NSURL*) downloadFile:(NSURL *)fileUrl {
    NSString *fileName = [fileUrl lastPathComponent];
    NSURL *tmpDir = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString  *tmpFilePath = [NSString stringWithFormat:@"%@/%@", [tmpDir path], fileName];
    NSURL *tmpFileUrl = [NSURL fileURLWithPath:tmpFilePath];
    NSData *urlData = [NSData dataWithContentsOfURL:fileUrl];
    [urlData writeToFile:tmpFilePath atomically:YES];
    return tmpFileUrl;
}

@end
