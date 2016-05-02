//
//  ViewController.h
//  JVChatClient
//
//  Created by Vu Ngoc Anh on 4/27/16.
//  Copyright © 2016 Justin Vu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <NSStreamDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITextField *inputNameField;
@property (weak, nonatomic) IBOutlet UIView *joinView;
@property (weak, nonatomic) IBOutlet UITextField *inputMessageField;
@property (weak, nonatomic) IBOutlet UITableView *contentTableView;
@property (weak, nonatomic) IBOutlet UIView *chatView;

- (IBAction)joinChat:(id)sender;
- (IBAction)sendMessage:(id)sender;

@end
