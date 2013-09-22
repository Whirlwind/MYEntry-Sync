//
//  MYEntryWithSync.h
//  ONEBase
//
//  Created by Whirlwind on 12-12-1.
//  Copyright (c) 2012年 BOOHEE. All rights reserved.
//

#import "MYEntry.h"
#import "MYEntrySqlAccessWithLog.h"
#import "MYEntry+SqlAccess.h"

#import "MYEntry+JsonAccess.h"

@interface MYEntryWithSync : MYEntry <MYEntrySqlAccessProtocol>

@property (assign, nonatomic) BOOL needLog;

@property (strong, nonatomic) MYDateTime *remoteUpdatedAt;
@property (strong, nonatomic) MYDateTime *remoteCreatedAt;

@property (strong, nonatomic) NSMutableArray *ignoreLogProperties;
@property (strong, nonatomic) NSMutableArray *extendLogProperties;

+ (BOOL)needLog;

+ (NSString *)selectFirstRemoteCreateDateInLocal;
+ (NSString *)selectLatestRemoteUpdateDateInLocal;

+ (BOOL)destoryInLocalWithRemoteIdArray:(NSArray *)ids;
+ (BOOL)clearInLocal;

+ (BOOL)saveInLocalWithJSONDictionary:(NSDictionary *)dic;
+ (BOOL)saveInLocalWithJSONArray:(NSArray *)array;

+ (BOOL)existAnonymousData;
+ (BOOL)setAnonymousDataToCurrentUserData;

@end
