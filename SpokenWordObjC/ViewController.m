//
//  ViewController.m
//  SpokenWordObjC
//
//  Created by ANTHONY CRUZ on 2/19/24.
//  Copyright © 2024 App Tyrant Corp. All rights reserved.

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController () <SFSpeechRecognizerDelegate>

@property (nonatomic,strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic,strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;

@property (nonatomic,strong) SFSpeechRecognitionTask *recognitionTask;

@property (nonatomic,strong) AVAudioEngine *audioEngine;

@property (nonatomic,weak) IBOutlet UITextView *textView;
@property (nonatomic,weak) IBOutlet UIButton *recordButton;
@property (nonatomic,weak) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic,strong) SFSpeechLanguageModelConfiguration *lmConfiguration;

@property (nonatomic) BOOL isSpeechAuthorizationRequestPending;
@property (nonatomic) BOOL isRequestingRecordPermission;

@end

@implementation ViewController

#pragma mark - View Controller Lifecycle
-(void)viewDidLoad
{
    [super viewDidLoad];
    self.isSpeechAuthorizationRequestPending = YES;
    // Disable the record buttons until authorization has been granted.
    self.recordButton.enabled = NO;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Configure the SFSpeechRecognizer object already
    // stored in a local member variable.
    self.speechRecognizer.delegate = self;
    
    // Ask for microphone permission right away.
    // If we don't ask for microphone permissions and wait until the "Start Recording!" button is pressed the UI will lock up for several seconds (which is unacceptable).
    // So we ask for microphone permissions up front.
    if ([AVAudioApplication sharedInstance].recordPermission != AVAudioApplicationRecordPermissionGranted)
    {
        self.isRequestingRecordPermission = YES;
        
        [AVAudioApplication requestRecordPermissionWithCompletionHandler:^(BOOL granted)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isRequestingRecordPermission = NO;
                if (SFSpeechRecognizer.authorizationStatus == SFSpeechRecognizerAuthorizationStatusAuthorized)
                {
                    self.recordButton.enabled = !self.isSpeechAuthorizationRequestPending;
                    
                }
            });
        }];
    }
    //-------
    
    
    // Make the authorization request.
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus authStatus)
    {
        // Divert to the app's main thread so that the UI can be updated.
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (authStatus)
            {
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        
                        NSString *assetPath = [[NSBundle mainBundle] pathForResource:@"CustomLMData" 
                                                                              ofType:@"bin"
                                                                         inDirectory:@"customlm/en_US"];
                        NSURL *assetUrl = [NSURL fileURLWithPath:assetPath];
                               
                        [SFSpeechLanguageModel prepareCustomLanguageModelForUrl:assetUrl
                                                               clientIdentifier:@"com.apple.SpokenWord" 
                                                                  configuration:self.lmConfiguration
                                                                     completion:^(NSError *_Nullable error)
                        {
                            if (error == nil)
                            {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self.isSpeechAuthorizationRequestPending = NO;
                                    self.recordButton.enabled = (!self.isSpeechAuthorizationRequestPending
                                                                 && !self.isRequestingRecordPermission);
                                });
                            }
                            else
                            {
                                NSLog(@"Failed to prepare custom LM: %@", [error localizedDescription]);
                            }
                        }];
                    });
                }
                break;
                    
                case SFSpeechRecognizerAuthorizationStatusDenied:
                {
                    self.recordButton.enabled = NO;
                    [self.recordButton setTitle:@"User denied access to speech recognition"
                                       forState:UIControlStateDisabled];
                    self.isSpeechAuthorizationRequestPending = NO;
                }
                break;
                    
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                {
                    self.recordButton.enabled = NO;
                    [self.recordButton setTitle:@"Speech recognition restricted on this device"
                                       forState:UIControlStateDisabled];
                    self.isSpeechAuthorizationRequestPending = NO;
                }
                break;
                    
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                {
                    self.recordButton.enabled = NO;
                    [self.recordButton setTitle:@"Speech recognition not yet authorized"
                                       forState:UIControlStateDisabled];
                    self.isSpeechAuthorizationRequestPending = NO;
                }
                break;
                    
                default:
                {
                    self.recordButton.enabled = NO;
                    self.isSpeechAuthorizationRequestPending = NO;
                }
                break;
            }
        });
    }];
}

-(BOOL)startRecordingAndReturnError:(NSError**)outError
{
    // Cancel the previous task if it's running.
    if (self.recognitionTask != nil)
    {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    
    // Configure the audio session for the app.
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession setCategory:AVAudioSessionCategoryRecord 
                              mode:AVAudioSessionModeMeasurement
                           options:AVAudioSessionCategoryOptionDuckOthers
                             error:outError])
    {
        return NO;
    }
    
    if (![audioSession setActive:YES 
                     withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                           error:outError])
    {
        return NO;
    }
    
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    
    // Create and configure the speech recognition request.
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc]init];
    if (self.recognitionRequest == nil) { NSAssert(NO, @"Unable to created a SFSpeechAudioBufferRecognitionRequest object"); }
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    // Keep speech recognition data on device
    self.recognitionRequest.requiresOnDeviceRecognition = YES;
    self.recognitionRequest.customizedLanguageModel = self.lmConfiguration;
    
    // Create a recognition task for the speech recognition session.
    // Keep a reference to the task so that it can be canceled.
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest
                                                               resultHandler:^(SFSpeechRecognitionResult *_Nullable result,
                                                                               NSError *_Nullable error)
    {
        BOOL isFinal = NO;
        if (result != nil)
        {
            // Update the text view with the results.
            self.textView.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
        }
        
        if (error != nil || isFinal)
        {
            // Stop recognizing speech if there is a problem.
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            self.recordButton.enabled = YES;
            [self.recordButton setTitle:@"Start Recording" forState:UIControlStateNormal];
        }
    }];
    
    // Configure the microphone input.
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    
    [inputNode installTapOnBus:0
                    bufferSize:1024
                        format:recordingFormat
                         block:^(AVAudioPCMBuffer *_Nonnull buffer, 
                                 AVAudioTime *_Nonnull when)
    {
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    if (![self.audioEngine startAndReturnError:outError])
    {
        return NO;
    }
    
    // Let the user know to start talking.
    self.textView.text = @"(Go ahead, I'm listening)";
    return YES;
}

#pragma  mark - SFSpeechRecognizerDelegate
-(void)speechRecognizer:(SFSpeechRecognizer*)speechRecognizer availabilityDidChange:(BOOL)available
{
   if (available)
   {
       // Only enable the button if our isSpeechAuthorizationRequestPending & isRequestingRecordPermission flags are NO because during testing
       // I've seen this delegate method get called with YES passed to the available parameter before we actually grant permission in the alert shown when SFSpeechRecognizer's +requestAuthorization: method is called.
       self.recordButton.enabled = (!self.isSpeechAuthorizationRequestPending
                                    && !self.isRequestingRecordPermission);
       [self.recordButton setTitle:@"Start Recording"
                          forState:UIControlStateNormal];
   }
   else
   {
       self.recordButton.enabled = NO;
       [self.recordButton setTitle:@"Recognition Not Available"
                          forState:UIControlStateDisabled];
   }
}

#pragma mark - Interface Builder actions
-(IBAction)recordButtonTapped:(id)sender
{
    if (self.audioEngine.isRunning)
    {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        self.recordButton.enabled = NO;
        [self.recordButton setTitle:@"Stopping"
                           forState:UIControlStateDisabled];
    }
    else
    {
        NSError *error = nil;
        if ([self startRecordingAndReturnError:&error])
        {
            [self.recordButton setTitle:@"Stop Recording"
                               forState:UIControlStateNormal];
        }
        else
        {
            [self.recordButton setTitle:@"Recording Not Available"
                               forState:UIControlStateNormal];
            NSLog(@"Recording failed with error: %@",error.localizedDescription);
        }
    }
}

-(IBAction)clearButtonTapped:(id)sender
{
    self.textView.text = @"";
}


#pragma mark - Getters
-(SFSpeechRecognizer*)speechRecognizer
{
    if (_speechRecognizer == nil)
    {
        _speechRecognizer = [[SFSpeechRecognizer alloc]initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
    }
    return _speechRecognizer;
}

-(AVAudioEngine*)audioEngine
{
    if (_audioEngine == nil)
    {
        _audioEngine = [[AVAudioEngine alloc]init];
    }
    return _audioEngine;
}

//#pragma mark - Custom LM Support
-(SFSpeechLanguageModelConfiguration*)lmConfiguration
{
    if (_lmConfiguration == nil)
    {
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
        NSURL *outputDir = [urls firstObject];
        NSURL *dynamicLanguageModel = [outputDir URLByAppendingPathComponent:@"LM"];
        NSURL *dynamicVocabulary = [outputDir URLByAppendingPathComponent:@"Vocab"];
        
        SFSpeechLanguageModelConfiguration *configuration = [[SFSpeechLanguageModelConfiguration alloc] initWithLanguageModel:dynamicLanguageModel vocabulary:dynamicVocabulary];
        _lmConfiguration = configuration;
    }
    return _lmConfiguration;
}

#pragma mark - Setters
-(void)setIsRequestingRecordPermission:(BOOL)isRequestingRecordPermission
{
    _isRequestingRecordPermission = isRequestingRecordPermission;
    if (isRequestingRecordPermission || self.isSpeechAuthorizationRequestPending)
    {
        [self.spinner startAnimating];
    }
    else
    {
        [self.spinner stopAnimating];
    }
}

-(void)setIsSpeechAuthorizationRequestPending:(BOOL)isSpeechAuthorizationRequestPending
{
    _isSpeechAuthorizationRequestPending = isSpeechAuthorizationRequestPending;
    if (isSpeechAuthorizationRequestPending || self.isRequestingRecordPermission)
    {
        [self.spinner startAnimating];
    }
    else
    {
        [self.spinner stopAnimating];
    }
}

@end
