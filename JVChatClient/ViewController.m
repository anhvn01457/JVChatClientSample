//
//  ViewController.m
//  JVChatClient
//
//  Created by Vu Ngoc Anh on 4/27/16.
//  Copyright © 2016 Justin Vu. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSMutableArray *messages;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initNetworkCommunication];
    messages = [@[] mutableCopy];
}

- (IBAction)joinChat:(id)sender {
    NSString *response = [NSString stringWithFormat:@"iam:%@", self.inputNameField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    [self.view bringSubviewToFront:self.chatView];
}

- (IBAction)sendMessage:(id)sender {
    NSString *response = [NSString stringWithFormat:@"msg:%@", self.inputMessageField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    self.inputMessageField.text = @"";
}

#pragma mark - TableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ChatCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    NSString *message = (NSString *)messages[indexPath.row];
    cell.textLabel.text = message;
    return cell;
}

#pragma mark - NSStreamDelegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSLog(@"%@ stream event: %lu", (aStream == inputStream) ? @"input" : @"output", (unsigned long)eventCode);
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
        case NSStreamEventHasBytesAvailable: {
            if (aStream == inputStream) {
                uint8_t buffer[1024];
                NSInteger len;
                while ([inputStream hasBytesAvailable]) {
                    len = [inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len) {
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        if (output) {
                            NSLog(@"Server said: %@", output);
                            [self messageReceived:output];
                        }
                    }
                }
            }
            break;
        }
        case NSStreamEventErrorOccurred:
            NSLog(@"Cannot connect to host!");
            break;
        case NSStreamEventEndEncountered:
            [aStream close];
            [aStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            break;
        default:
            NSLog(@"Unknown Event");
            break;
    }
}

#pragma mark - Helper methods
- (void)initNetworkCommunication {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"localhost", 80, &readStream, &writeStream);
    inputStream = (NSInputStream *)CFBridgingRelease(readStream);
    outputStream = (NSOutputStream *)CFBridgingRelease(writeStream);
    
    inputStream.delegate = self;
    outputStream.delegate = self;
    
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
}

- (void)messageReceived:(NSString *)message {
    [messages addObject:message];
    [self.contentTableView reloadData];
    NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:messages.count - 1 inSection:0];
    [self.contentTableView scrollToRowAtIndexPath:topIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

@end
