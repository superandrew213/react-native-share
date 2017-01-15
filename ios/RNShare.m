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
    
    if (isRemote) {
        NSURL *fileUrl = [NSURL URLWithString:shareFile];
        NSURL *downloadedFileUrl = [self downloadFile:fileUrl];
        if (downloadedFileUrl) {
            [self displayDocument:downloadedFileUrl];
        }
    } else {
        NSURL *fileUrl = [NSURL fileURLWithPath:shareFile];
        [self displayDocument:fileUrl];
    }
}

- (void) displayDocument:(NSURL*)fileUrl {
    self.documentController = [UIDocumentInteractionController interactionControllerWithURL:fileUrl];
    self.documentController.delegate = self;
    UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [self.documentController presentOptionsMenuFromRect:ctrl.view.bounds inView:ctrl.view animated:YES];
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
