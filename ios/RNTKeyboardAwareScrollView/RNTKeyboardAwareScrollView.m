
#import "RNTKeyboardAwareScrollView.h"

const CGFloat RNTDetectCaretPositionTrialCount = 20;
NSString * const RCTUIManagerCaretErrorDomain = @"RCTUIManagerCaretErrorDomain";

typedef enum : NSUInteger {
    RCTUIManagerCaretRectFailNotDetected = 1001,
    RCTUIManagerCaretRectFailEndOfText
} RCTUIManagerCaretRectFail;

@implementation RNTKeyboardAwareScrollView

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

RCT_EXPORT_METHOD(viewIsDescendantOf:(nonnull NSNumber *)reactTag
                  ancestor:(nonnull NSNumber *)ancestorReactTag
                  callback:(RCTResponseSenderBlock)callback) {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        UIView *inputView = [uiManager viewForReactTag:reactTag];
        UIView *ancestorView = [uiManager viewForReactTag:ancestorReactTag];
        if (!inputView || !ancestorView) {
            callback(@[@"Couldn't find views"]);
            return;
        }
        BOOL result = [inputView isDescendantOfView:ancestorView];
        callback(@[[NSNull null], @(result)]);
    }];
}

RCT_EXPORT_METHOD(measureSelectionInWindow:(nonnull NSNumber *)reactTag callback:(RCTResponseSenderBlock)callback)
{
    __weak typeof(self) weakSelf = self;
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        UIView *newResponder = [uiManager viewForReactTag:reactTag];
        if ( !newResponder ) {
            RCTLogWarn(@"measureSelectionInWindow cannot find view with tag #%@", reactTag);
            callback(@[@"View doesn't exist"]);
            return;
        }
        if ( [newResponder conformsToProtocol:@protocol(UITextInput)] ) {
            id<UITextInput> textInput = (id<UITextInput>)newResponder;
            UITextPosition *endPosition = textInput.selectedTextRange.end;
            if ( endPosition ) {
                [weakSelf rnt_caretRectIn:textInput trialCount:RNTDetectCaretPositionTrialCount completion:^(NSError *error, CGRect selectionEndRect) {
                    if (error) {
                        switch (error.code) {
                            case RCTUIManagerCaretRectFailNotDetected:
                                RCTLogWarn(@"measureSelectionInWindow cannot find the caret rect in view with tag #%@", reactTag);
                                callback(@[@"Caret rect could not be determined"]);
                                break;
                            case RCTUIManagerCaretRectFailEndOfText:
                                callback(@[@"Caret rect could not be determined but detected that it is at the end of the text"]);
                                break;
                        }
                        return;
                    }
                    CGRect windowFrame = [newResponder.window convertRect:newResponder.frame fromView:newResponder.superview];
                    CGFloat textViewHeight = [weakSelf rnt_contentHeightIn:textInput defaultHeight:windowFrame.size.height];
                    CGFloat textInputBottomTextInset = 0;
                    if ( [textInput isKindOfClass:[UITextView class]] ) {
                        textInputBottomTextInset = ((UITextView *)textInput).textContainerInset.bottom;
                    }
                    callback(@[[NSNull null],
                               @(windowFrame.origin.x),  //text input x
                               @(windowFrame.origin.y),  //text input y
                               @(windowFrame.size.width),  //text input width
                               @(textViewHeight),  //text input height
                               @(windowFrame.origin.x + selectionEndRect.origin.x),  //caret x
                               @(windowFrame.origin.y + selectionEndRect.origin.y),  //caret y
                               @(selectionEndRect.origin.x),  //caret relative x
                               @(selectionEndRect.origin.y),  //caret relative y
                               @(selectionEndRect.size.width),  //caret width
                               @(selectionEndRect.size.height),  //caret height
                               @(textInputBottomTextInset)  // text input bottom text inset
                               ]);
                    return;
                    
                }];
                return;
            }
        }
        callback(@[@"Text selection not available"]);
    }];
}

- (CGFloat)rnt_contentHeightIn:(id<UITextInput>)textInput defaultHeight:(CGFloat)defaultHeight {
    if ([textInput isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)textInput;
        // This is a workaround to get the result height of the textview after its content is changed
        // sometimes at this point the height of the textview is calculated wrongly and
        // calling layoutIfNeeded doesn't help with that so we call sizeThatFits
        return [textView sizeThatFits:textView.frame.size].height;
    }
    return defaultHeight;
}

- (void)rnt_caretRectIn:(id<UITextInput>)textInput trialCount:(NSInteger)trialCount completion:(void (^)(NSError *error, CGRect rect))completion {
    if ( trialCount == 0 ) {
        //We tried but couldn't find, return an error
        completion([[NSError alloc] initWithDomain:RCTUIManagerCaretErrorDomain
                                              code:RCTUIManagerCaretRectFailNotDetected
                                          userInfo:nil],
                   CGRectZero);
        return;
    }
    NSComparisonResult result = [textInput comparePosition:textInput.endOfDocument toPosition:textInput.selectedTextRange.end];
    if( result == NSOrderedSame ) {
        //caretRectForPosition can't detect the rect when caret is at the end of the text
        //so we aren't going to try that and lose time here
        completion([[NSError alloc] initWithDomain:RCTUIManagerCaretErrorDomain
                                              code:RCTUIManagerCaretRectFailEndOfText
                                          userInfo:nil],
                   CGRectZero);
        return;
    }
    UITextPosition *endPosition = textInput.selectedTextRange.end;
    CGRect selectionEndRect = [textInput caretRectForPosition:endPosition];
    if ((CGRectGetMinY(selectionEndRect) < 0) ||
        (INFINITY == CGRectGetMinY(selectionEndRect))) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       ^{
                           // Recall
                           [self rnt_caretRectIn:textInput trialCount:trialCount - 1 completion: completion];
                       });
        return;
    }
    completion(nil, selectionEndRect);
}

@end
