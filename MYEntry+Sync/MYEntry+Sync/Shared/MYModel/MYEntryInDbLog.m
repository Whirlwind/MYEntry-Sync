//
//  ONEBaseUserDataBaseLog.m
//  ONEBase
//
//  Created by Whirlwind on 12-11-28.
//  Copyright (c) 2012年 BOOHEE. All rights reserved.
//

#import "MYEntryInDbLog.h"
#import "MYDbManager.h"

static NSString *_logTableName = nil;
static FMDatabaseQueue *_logDbQueue = nil;
static BOOL uploading = NO;

@implementation MYEntryInDbLog

+ (NSString *)tableName {
    if (_logTableName == nil) {
        return @"my_user_entry_logs";
    }
    return _logTableName;
}

+ (void)setTableName:(NSString *)tableName {
    _logTableName = tableName;
}

+ (FMDatabaseQueue *)dbQueue {
    if (_logDbQueue == nil) {
        return [MYDbManager sharedDbQueue];
    }
    return _logDbQueue;
}

+ (void)setDbQueue:(FMDatabaseQueue *)dbQueue {
    _logDbQueue = nil;
    _logDbQueue = dbQueue;
}

+ (BOOL)logChangeForModel:(NSString *)modelName
                  localId:(NSNumber *)localId
                 uniqueId:(NSNumber *)uniqueId
                  userKey:(NSString *)userKey
                  changes:(NSDictionary *)changes
                updatedAt:(MYDateTime *)updatedAt
                  usingDb:(FMDatabase *)db {
    __block BOOL status = YES;
    [changes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![self logChangeForModel:modelName
                             localId:localId
                            uniqueId:uniqueId
                             userKey:userKey
                           fieldName:key
                          fieldValue:[obj description]
                           updatedAt:updatedAt
                             usingDb:db]) {
            *stop = YES;
            status = NO;
        }
    }];
    MY_BACKGROUND_BEGIN
    POST_BROADCAST_WITH_NAME(@"dbLogChanged");
    MY_BACKGROUND_COMMIT
    return status;

}
+ (BOOL)logChangeForModel:(NSString *)modelName
                  localId:(NSNumber *)localId
                 uniqueId:(NSNumber *)uniqueId
                  userKey:(NSString *)userKey
                fieldName:(NSString *)fieldName
               fieldValue:(NSString *)fieldValue
                updatedAt:(MYDateTime *)updatedAt
                  usingDb:(FMDatabase *)db {
    if ([fieldName isEqualToString:@"updated_at"] || [fieldName isEqualToString:@"created_at"]) {
        return YES;
    }
    if ([db executeUpdate:[NSString stringWithFormat:@"DELETE FROM `%@` WHERE local_id = ? AND model_name = ? AND field_name = ?", self.tableName], localId, modelName, fieldName]) {
        if ([db executeUpdate:[NSString stringWithFormat:@"INSERT INTO `%@` (`user_key`, `model_name`, `local_id`, `remote_id`, `field_name`, `field_value`, `exec_type`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, 'U', ?)", self.tableName], userKey, modelName, localId, uniqueId, fieldName, fieldValue, updatedAt]) {
            return YES;
        }
    }
    LogError(@"LOG ERROR! %@", [db lastErrorMessage]);
    return NO;
}

+ (BOOL)logDeleteForModel:(NSString *)modelName
                  localId:(NSNumber *)localId
                 uniqueId:(NSNumber *)uniqueId
                  userKey:(NSString *)userKey
                updatedAt:(NSString *)updatedAt
                  usingDb:(FMDatabase *)db {
    if ([db executeUpdate:[NSString stringWithFormat:@"DELETE FROM `%@` WHERE local_id = ? AND model_name = ?", self.tableName], localId, modelName]) {
        if (uniqueId == nil || [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO `%@` (`user_key`, `model_name`, `local_id`, `remote_id`, `updated_at`, `exec_type`) VALUES (?, ?, ?, ?, ?, 'D')", self.tableName], userKey, modelName, localId, uniqueId, updatedAt, nil]) {
            MY_BACKGROUND_BEGIN
            POST_BROADCAST_WITH_NAME(@"dbLogChanged");
            MY_BACKGROUND_COMMIT
            return YES;
        }
    }
    LogError(@"LOG ERROR! %@", [db lastErrorMessage]);
    return NO;
}

+ (NSDictionary *)outputLogWihtMaxId:(NSNumber *)maxId userKey:(NSString *)userKey {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM `%@` WHERE `id` <= ? AND user_key = ?", self.tableName], maxId, userKey, nil];
        while ([rs next]) {
            NSString *modelName = [rs stringForColumn:@"model_name"];
            NSMutableDictionary *dic = [result valueForKey:modelName];
            if (dic == nil) {
                dic = [NSMutableDictionary dictionary];
                [result setValue:dic forKey:modelName];
            }
            if ([[rs stringForColumn:@"exec_type"] isEqualToString:@"U"]) { // update
                NSMutableDictionary *updateDic = [dic valueForKey:@"update"];
                if (updateDic == nil) {
                    updateDic = [NSMutableDictionary dictionary];
                    [dic setValue:updateDic forKey:@"update"];
                }
                NSString *localId = [NSString stringWithFormat:@"%d", [rs intForColumn:@"local_id"]];
                NSMutableDictionary *modelDic = [updateDic valueForKey:localId];
                if (modelDic == nil) {
                    modelDic = [NSMutableDictionary dictionary];
                    [updateDic setValue:modelDic forKey:localId];
                }
                [modelDic setValue:[rs stringForColumn:@"field_value"] forKey:[rs stringForColumn:@"field_name"]];
            } else { // delete
                NSMutableArray *deleteArray = [dic valueForKey:@"delete"];
                if (deleteArray == nil) {
                    deleteArray = [NSMutableArray array];
                    [dic setValue:deleteArray forKey:@"delete"];
                }
                [deleteArray addObject:[rs objectForColumnName:@"remote_id"]];
            }
        }
        [rs close];
    }];
    [result enumerateKeysAndObjectsUsingBlock:^(id key, NSDictionary *obj, BOOL *stop) {
        NSDictionary *update = [obj valueForKey:@"update"];
        if (update) {
            [obj setValue:[update allValues] forKey:@"update"];
        }
    }];
    return result;
}

+ (BOOL)clearLogWithMaxId:(NSNumber *)maxId userKey:(NSString *)userKey {
    return [self.dbQueue executeUpdate:[NSString stringWithFormat:@"DELETE FROM `%@` WHERE id <= ? AND user_key = ?", self.tableName], maxId, userKey, nil];
}

+ (BOOL)tryUploadLogWithUserKey:(NSString *)userKey {
    if (uploading) {
        return NO;
    }
    uploading = YES;
    NSInteger retryCounter = 1;
    while (retryCounter <= 3) {
        if (![self uploadLogWithUserKey:userKey]) {
            retryCounter++;
        } else {
            retryCounter = 1;
        }
    }
    uploading = NO;
    POST_BROADCAST_WITH_NAME(@"logUploadCompleted");
    return YES;
}

+ (BOOL)uploadLogWithUserKey:(NSString *)userKey {
    __block NSNumber *maxId = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT MAX(id) FROM %@ WHERE user_key = ?", self.tableName], userKey, nil];
        if ([rs next]) {
            maxId = [rs objectForColumnIndex:0];
        }
        [rs close];
    }];
    if (maxId && ![maxId isKindOfClass:[NSNull class]]) {
        if ([self uploadLogWithMaxId:maxId userKey:userKey]) {
            return [self clearLogWithMaxId:maxId userKey:userKey];
        }
        return NO;
    } else {
        return YES;
    }
}

+ (NSDictionary *)uploadLogWithMaxId:(NSNumber *)maxId userKey:(NSString *)userKey {
    NSDictionary *log = [self outputLogWihtMaxId:maxId userKey:userKey];
    return [self uploadLog:log];
}

#pragma mark - for override
+ (NSDictionary *)uploadLog:(NSDictionary *)log {
    return nil;
}
@end
