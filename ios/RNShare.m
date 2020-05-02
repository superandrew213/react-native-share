
#import "RNShare.h"
#import <MessageUI/MessageUI.h>
#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <AssetsLibrary/AssetsLibrary.h>

@import Photos;

@implementation RNShare

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(open:(NSDictionary *)options :(RCTResponseSenderBlock)callback)
{
    NSString *shareFile = [RCTConvert NSString:options[@"share_file"]];
    NSString *fileType = [RCTConvert NSString:options[@"fileType"]] ?: @"image";
    BOOL shareToIgDirectly = [RCTConvert BOOL:options[@"shareToIgDirectly"]];
    // Checks if http or https
    BOOL isRemote = [NSURL URLWithString:shareFile].scheme;
    BOOL restrictLocalStorage = [RCTConvert BOOL:options[@"restrictLocalStorage"]];
    BOOL instagramOnly = [shareFile hasSuffix:@".igo"];

    NSURL *fileToShare;
    if (isRemote) {
        // Download file first
        NSURL *fileUrl = [NSURL URLWithString:shareFile];
        fileToShare = [self downloadFile:fileUrl];
    } else {
        fileToShare = [NSURL fileURLWithPath:shareFile];
    }

    if (fileToShare) {
        if (shareToIgDirectly) {
            // Check if we have access to phone library - media must be stored to phone library first before we can share it to IG
            // directly
            [self requestPhotoAuthorization:^(BOOL granted) {
                if (granted) {
                    [self shareToIg:fileToShare fileType:fileType callback:callback];
                } else {
                    callback(@[RCTMakeError(@"photo_library_permission_required", nil, nil)]);
                }
            }];

        } else {
            if (instagramOnly) {
                [self displayDocumentIGO:fileToShare callback:callback];
            } else {
                [self displayDocument:fileToShare restrictLocalStorage:restrictLocalStorage callback:callback];
            }

        }
    } else {
        callback(@[RCTMakeError(@"failed_to_share", nil, nil)]);
    }
}

- (void)requestPhotoAuthorization:(void (^)(BOOL granted))granted
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        granted(YES);
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                granted(YES);
            } else {
                granted(NO);
            }
        }];
    } else {
        granted(NO);
    }

}

- (BOOL) canShareToIg {
    NSURL *appURL = [NSURL URLWithString:@"instagram://app"];
    return [[UIApplication sharedApplication] canOpenURL:appURL];
}

- (void) shareToIg:(NSURL*)fileUrl fileType:(NSString*)fileType callback:(RCTResponseSenderBlock)callback {
    // Check if IG installed
    if (![self canShareToIg]) {
        callback(@[RCTMakeError(@"cannot_open_ig", nil, nil)]);
        return;
    }

    __block NSString* localId;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *assetChangeRequest;
        if ([fileType isEqualToString:@"video"]) {
            assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileUrl];
        } else {
            assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileUrl];
        }
        localId = [[assetChangeRequest placeholderForCreatedAsset] localIdentifier];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success) {
            NSURL *instagramURL = [NSURL URLWithString: [@"instagram://library?LocalIdentifier=" stringByAppendingString:localId]];
            [[UIApplication sharedApplication] openURL:instagramURL];
            callback(@[[NSNull null], @{
                           @"activityType": @"com.burbn.instagram",
                           @"completed": [NSNumber numberWithBool:success],
                           }]);
        }
        else {
            callback(@[RCTMakeError(@"failed_to_share", error, nil)]);
        }
    }];
}

- (void) displayDocument:(NSURL*)fileUrl restrictLocalStorage:(BOOL)restrictLocalStorage callback:(RCTResponseSenderBlock)callback {
    UIViewController *viewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    NSArray *items = @[fileUrl];
    UIActivityViewController *activityController = [[UIActivityViewController alloc]initWithActivityItems:items applicationActivities:nil];

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
                                                     // @"com.google.Drive.ShareExtension",
                                                     // @"com.apple.UIKit.activity.Open.Copy.com.burbn.instagram"
                                                     // @"com.burbn.instagram.shareextension"
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

        [viewController setPreferredContentSize:CGSizeMake(320, 480)];
    }

    [activityController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        callback(@[[NSNull null], @{
                       @"activityType": activityType ?: [NSNull null],
                       @"completed": [NSNumber numberWithBool:completed],
                       }]);
    }];

    [viewController presentViewController:activityController animated:YES completion:nil];
}

- (void) displayDocumentIGO:(NSURL*)fileUrl callback:(RCTResponseSenderBlock)callback {
    UIViewController *viewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

    UIDocumentInteractionController *documentController = [UIDocumentInteractionController interactionControllerWithURL:fileUrl];

    documentController.delegate = self;
    documentController.UTI = @"com.instagram.exclusivegram";

    while (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
    }

    if ([documentController presentOpenInMenuFromRect:viewController.view.bounds inView:viewController.view animated:YES]) {
        callback(@[[NSNull null], @{
                       @"activityType": @"com.burbn.instagram",
                       @"completed": @true,
                       }]);
    } else {
       callback(@[RCTMakeError(@"cannot_open_ig", nil, nil)]);
    }
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
