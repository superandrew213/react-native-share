#import <MessageUI/MessageUI.h>
#import "RNShare.h"
#import "RCTConvert.h"

_Bool INSTAGRAM_ONLY = NO;

@implementation UIActivityViewControllerInstagramOnly : UIActivityViewController
- (BOOL)_shouldExcludeActivityType:(UIActivity *)activity
{
//    NSLog(@"%@", [activity activityType]);
    if (!INSTAGRAM_ONLY) {
        return NO;
    }
    if ([[activity activityType] isEqualToString:@"com.burbn.instagram.shareextension"] || [[activity activityType] isEqualToString:@"com.apple.UIKit.activity.Open.Copy.com.burbn.instagram"]) {
        return NO;
    }
    return YES;
}
@end

@implementation RNShare

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
    BOOL instagramOnly = [RCTConvert BOOL:options[@"instagramOnly"]];
    BOOL restrictLocalStorage = [RCTConvert BOOL:options[@"restrictLocalStorage"]];

    if (instagramOnly) {
        INSTAGRAM_ONLY = YES;
    } else {
        INSTAGRAM_ONLY = NO;
    }

    NSURL *fileToShare;
    if (isRemote) {
        // Download file first
        NSURL *fileUrl = [NSURL URLWithString:shareFile];
        fileToShare = [self downloadFile:fileUrl];
    } else {
        fileToShare = [NSURL fileURLWithPath:shareFile];
    }

    if (fileToShare) {
        [self displayDocument:fileToShare restrictLocalStorage:restrictLocalStorage callback:callback];
    }
}

- (void) displayDocument:(NSURL*)fileUrl restrictLocalStorage:(BOOL)restrictLocalStorage callback:(RCTResponseSenderBlock)callback {
    UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    NSArray *items = @[fileUrl];
    UIActivityViewController *activityController = [[UIActivityViewControllerInstagramOnly alloc]initWithActivityItems:items applicationActivities:nil];

    if (restrictLocalStorage) {
        activityController.excludedActivityTypes = @[
            // UIActivityTypePostToFacebook,
            // UIActivityTypePostToTwitter,
            // UIActivityTypePostToWeibo,
            // UIActivityTypeMessage,
            // UIActivityTypeMail,
            // UIActivityTypePrint,
            UIActivityTypeCopyToPasteboard,
            UIActivityTypeAssignToContact,
            UIActivityTypeSaveToCameraRoll,
            UIActivityTypeAddToReadingList,
            // UIActivityTypePostToFlickr,
            // UIActivityTypePostToVimeo,
            // UIActivityTypePostToTencentWeibo,
            UIActivityTypeAirDrop,
            UIActivityTypeOpenInIBooks,
            @"com.apple.reminders.RemindersEditorExtension",
            @"com.apple.mobilenotes.SharingExtension",
            // @"com.google.Drive.ShareExtension"
        ];
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

    [activityController setCompletionHandler:^(NSString *activityType, BOOL completed) {
        callback(@[[NSNull null], @{
                       @"activityType": activityType ?: [NSNull null],
                       @"completed": [NSNumber numberWithBool:completed],
                       }]);
    }];

    [ctrl presentViewController:activityController animated:YES completion:nil];
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
