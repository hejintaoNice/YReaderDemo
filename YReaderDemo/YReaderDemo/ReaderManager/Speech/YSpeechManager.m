//
//  YSpeechManager.m
//  YAVSpeechSynthesizerDemo
//
//  Created by yanxuewen on 2017/3/2.
//  Copyright © 2017年 YXW. All rights reserved.
//

#import "YSpeechManager.h"
#import <AVFoundation/AVFoundation.h>

@interface YSpeechManager ()<AVSpeechSynthesizerDelegate>

@property (strong, nonatomic) AVSpeechSynthesizer *speechSynthesizer;
@property (strong, nonatomic) NSArray *speechArray;
@property (assign, nonatomic) NSUInteger speechCount;
@property (assign, nonatomic) double speechRate;    // Values are pinned between AVSpeechUtteranceMinimumSpeechRate:0 and AVSpeechUtteranceMaximumSpeechRate:1.
@property (assign, nonatomic) double speechVolume;  // [0-1] Default = 1
@property (strong, nonatomic) AVSpeechSynthesisVoice *voiceType;//zh-CN
@property (assign, nonatomic) NSRange speechRange;
@property (copy, nonatomic) NSString *sourceSpeechString;
@property (strong, nonatomic) AVSpeechUtterance *speechUtterance;

@end

@implementation YSpeechManager

+ (instancetype)shareSpeechManager {
    static YSpeechManager *speechManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        speechManager = [[YSpeechManager alloc] init];
    });
    return speechManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
//        _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
//        _speechSynthesizer.delegate = self;
        _speechCount = 0;
        _speechRate = AVSpeechUtteranceDefaultSpeechRate;
        _speechVolume = 1;
        _voiceType = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    }
    return self;
}

- (void)startSpeechWith:(NSString *)string speechRate:(double)speechRate{
    if (![string isNotBlank]) {
        [self p_speechUpdateState:YSpeechStateFinish];
        return;
    }
    _sourceSpeechString = string;
    _speechArray = [string componentsSeparatedByString:@"\n"];
    _speechCount = 0;
    if (!_speechArray) {
        _speechArray = @[string];
    }
    
    [self checkSpeechStringValid];
    if (_speechCount >= _speechArray.count) {
        [self p_speechUpdateState:YSpeechStateFinish];
        return;
    }
    
    NSError *error = NULL;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if(error) {
        // Do some error handling
    }
    [session setActive:YES error:&error];
    if (error) {
        // Do some error handling
    }
    
    NSRange range = [_sourceSpeechString rangeOfString:_speechArray[_speechCount]];
    if (range.location != NSNotFound && range.length > 0) {
        _speechRange.location = range.location - 1;
    }
    
    _speechRate = (speechRate - 0.5) / 2.0 + 0.5;
    [self p_startSpeechWith:_speechArray[_speechCount]];
}

- (void)p_startSpeechWith:(NSString *)string {
    AVSpeechUtterance *speechUtterance = [[AVSpeechUtterance alloc] initWithString:string];
    speechUtterance.voice = _voiceType;
    speechUtterance.volume = _speechVolume;
    speechUtterance.rate = _speechRate;
    [self.speechSynthesizer speakUtterance:speechUtterance];
    _speechUtterance = speechUtterance;
}

- (void)continueSpeech {
    [_speechSynthesizer continueSpeaking];
}

- (void)pauseSpeech {
    [_speechSynthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

- (void)exitSpeech {
    [_speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryWord];
    _speechSynthesizer.delegate = nil;
    _speechSynthesizer = nil;
    _state = YSpeechStateNone;
    _sourceSpeechString = nil;
    _speechArray = nil;
}

- (void)changeSpeechRate:(double)rate {
    double newRate = (rate - 0.5) / 2.0 + 0.5;
    if (newRate != _speechRate) {
        _speechRate = newRate;
        [_speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        _speechRange = [_sourceSpeechString rangeOfString:self.speakingString];
        [self p_startSpeechWith:_speechArray[_speechCount]];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"%s",__func__);
    [self p_speechUpdateState:YSpeechStateStart];
    if (self.delegate && [self.delegate respondsToSelector:@selector(speechManagerWillChangeSection:string:)]) {
        [self.delegate speechManagerWillChangeSection:_speechCount string:_speechArray[_speechCount]];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"%s",__func__);
    _speechCount++;
    [self checkSpeechStringValid];
    if (_speechCount < _speechArray.count) {
        NSRange range = [_sourceSpeechString rangeOfString:_speechArray[_speechCount]];
        if (range.location != NSNotFound && range.length > 0) {
            _speechRange.location = range.location - 1;
        }
        [self p_startSpeechWith:_speechArray[_speechCount]];
    } else {
        
        [self p_speechUpdateState:YSpeechStateFinish];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didPauseSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"%s",__func__);
    [self p_speechUpdateState:YSpeechStatePause];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didContinueSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"%s",__func__);
    [self p_speechUpdateState:YSpeechStateContinue];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    NSLog(@"%s",__func__);
    [self p_speechUpdateState:YSpeechStateCancel];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer willSpeakRangeOfSpeechString:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance {
    //    NSLog(@"%s",__func__);
//        NSLog(@"characterRange:%@",NSStringFromRange(characterRange));
    _speechRange = NSMakeRange(_speechRange.location+characterRange.length, characterRange.length);
    if (self.delegate && [self.delegate respondsToSelector:@selector(speechManagerWillSpeakRange:)]) {
        [self.delegate speechManagerWillSpeakRange:_speechRange];
    }
}

- (void)p_speechUpdateState:(YSpeechState)state {
    if (self.delegate && [self.delegate respondsToSelector:@selector(speechManagerUpdateState:)]) {
        [self.delegate speechManagerUpdateState:state];
    }
    _state = state;
}

#pragma mark - 检查下一个要读段落是否包含中文
- (void)checkSpeechStringValid {
    while (_speechCount < _speechArray.count) {
        NSString *str = _speechArray[_speechCount];
        NSRange range = [str rangeOfString:@"[\u4e00-\u9fff]" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound && range.length > 0) {
            break;
        }
        _speechCount++;
    }
}

- (AVSpeechSynthesizer *)speechSynthesizer {
    if (!_speechSynthesizer) {
        _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
        _speechSynthesizer.delegate = self;
    }
    return _speechSynthesizer;
}

- (NSString *)speakingString {
    return _speechUtterance.speechString;
}

- (NSUInteger)sectionStringCount {
    NSRange range = [_sourceSpeechString rangeOfString:_speechUtterance.speechString];
    if (range.location != NSNotFound) {
        return range.location;
    }
    return 0;
}

@end
