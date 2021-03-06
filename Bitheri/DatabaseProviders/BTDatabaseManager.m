//
//  BTDatabaseManager.m
//  bitheri
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "BTDatabaseManager.h"

NSString *const TX_DB_VERSION = @"db_version";
NSString *const TX_DB_NAME = @"bitheri.sqlite";
const int CURRENT_TX_DB_VERSION = 2;

NSString *const ADDRESS_DB_VERSION = @"address_db_version";
NSString *const ADDRESS_DB_NAME = @"address.sqlite";
const int CURRENT_ADDRESS_DB_VERSION = 4;

static BOOL canOpenTxDb;
static BOOL canOpenAddressDb;

@interface BTDatabaseManager ()


#pragma mark - tx db
@property(nonatomic, readonly) NSString *blocksSql;
@property(nonatomic, readonly) NSString *indexBlocksBlockNoSql;
@property(nonatomic, readonly) NSString *indexBlocksBlockPrevSql;
@property(nonatomic, readonly) NSString *txsSql;
@property(nonatomic, readonly) NSString *indexTxsBlockNoSql;
@property(nonatomic, readonly) NSString *addressesTxsSql;
@property(nonatomic, readonly) NSString *insSql;
@property(nonatomic, readonly) NSString *indexInsPrevTxHashSql;
@property(nonatomic, readonly) NSString *outsSql;
@property(nonatomic, readonly) NSString *indexOutsOutAddressSql;
@property(nonatomic, readonly) NSString *peersSql;
@property(nonatomic, readonly) NSString *hdAccountAddress;
@property(nonatomic, readonly) NSString * indexHDAccountAddress;

#pragma mark - address db
@property(nonatomic, readonly) NSString *passwordSeedSql;
@property(nonatomic, readonly) NSString *addressesSql;
@property(nonatomic, readonly) NSString *hdSeedsSql;
@property(nonatomic, readonly) NSString *hdmAddressesSql;
@property(nonatomic, readonly) NSString *hdmBidSql;
@property(nonatomic, readonly) NSString *aliasesSql;
@property(nonatomic, readonly) NSString *hdAccountSql;
@property(nonatomic, readonly) NSString *vanityAddressSql;


@property(nonatomic, strong) FMDatabaseQueue *txQueue;
@property(nonatomic, strong) FMDatabaseQueue *addressQueue;
@end

static BTDatabaseManager *databaseProvide;

@implementation BTDatabaseManager : NSObject

+ (instancetype)instance {
    @synchronized (self) {
        if (databaseProvide == nil) {
            databaseProvide = [[self alloc] init];
            [databaseProvide initDatabase];
        }
    }
    return databaseProvide;
}
//init 1.0.1
- (instancetype)init {
    if (!(self = [super init])) return nil;

#pragma mark - tx db
    _blocksSql = @"create table if not exists blocks "
            "(block_no integer not null"
            ", block_hash text not null primary key"
            ", block_root text not null"
            ", block_ver integer not null"
            ", block_bits integer not null"
            ", block_nonce integer not null"
            ", block_time integer not null"
            ", block_prev text"
            ", is_main integer not null);";
    _indexBlocksBlockNoSql = @"create index idx_blocks_block_no on blocks (block_no);";
    _indexBlocksBlockPrevSql = @"create index idx_blocks_block_prev on blocks (block_prev);";
    _txsSql = @"create table if not exists txs "
            "(tx_hash text primary key"
            ", tx_ver integer"
            ", tx_locktime integer"
            ", tx_time integer"
            ", block_no integer"
            ", source integer);";
    _indexTxsBlockNoSql = @"create index idx_tx_block_no on txs (block_no);";
    _addressesTxsSql = @"create table if not exists addresses_txs "
            "(address text not null"
            ", tx_hash text not null"
            ", primary key (address, tx_hash));";
    _insSql = @"create table if not exists ins "
            "(tx_hash text not null"
            ", in_sn integer not null"
            ", prev_tx_hash text"
            ", prev_out_sn integer"
            ", in_signature text"
            ", in_sequence integer"
            ", primary key (tx_hash, in_sn));";
    _indexInsPrevTxHashSql = @"create index idx_in_prev_tx_hash on ins (prev_tx_hash);";
    _outsSql = @"create table if not exists outs "
            "(tx_hash text not null"
            ", out_sn integer not null"
            ", out_script text not null"
            ", out_value integer not null"
            ", out_status integer not null"
            ", out_address text"
            ", hd_account_id integer "
            ", primary key (tx_hash, out_sn));";
    _indexOutsOutAddressSql = @"create index idx_out_out_address on outs (out_address);";
    _peersSql = @"create table if not exists peers "
            "(peer_address integer primary key"
            ", peer_port integer not null"
            ", peer_services integer not null"
            ", peer_timestamp integer not null"
            ", peer_connected_cnt integer not null);";

    _hdAccountAddress = @"create table if not exists hd_account_addresses "
            "(path_type integer not null"
            ", address_index integer not null"
            ", is_issued integer not null"
            ", address text not null"
            ", pub text not null"
            ", is_synced integer not null"
            ", primary key (address));";
    _indexHDAccountAddress=@"create index idx_hd_address_address on hd_account_addresses (address);";

#pragma mark - address db

    _passwordSeedSql = @"create table if not exists password_seed "
            "(password_seed text not null primary key);";
    _addressesSql = @"create table if not exists addresses "
            "(address text not null primary key"
            ", encrypt_private_key text"
            ", pub_key text not null"
            ", is_xrandom integer not null"
            ", is_trash integer not null"
            ", is_synced integer not null"
            ", sort_time integer not null);";
    _hdSeedsSql = @"create table if not exists hd_seeds "
            "(hd_seed_id integer not null primary key autoincrement"
            ", encrypt_seed text not null"
            ", encrypt_hd_seed text"
            ", hdm_address text not null"
            ", is_xrandom integer not null"
            ", singular_mode_backup text);";
    _hdmAddressesSql = @"create table if not exists hdm_addresses "
            "(hd_seed_id integer not null"
            ", hd_seed_index integer not null"
            ", pub_key_hot text not null"
            ", pub_key_cold text not null"
            ", pub_key_remote text"
            ", address text"
            ", is_synced integer not null"
            ", primary key (hd_seed_id, hd_seed_index));";
    _hdmBidSql = @"create table if not exists hdm_bid "
            "(hdm_bid text not null primary key"
            ", encrypt_bither_password text not null);";
    _aliasesSql = @"create table if not exists aliases "
            "(address text not null primary key"
            ", alias text not null);";
    _hdAccountSql = @"create table if not exists  hd_account "
            "( hd_account_id integer not null primary key autoincrement"
            ", encrypt_seed text not null"
            ", encrypt_mnemonic_seed text"
            ", hd_address text not null"
            ", external_pub text not null"
            ", internal_pub text not null"
            ", is_xrandom integer not null);";
    _vanityAddressSql=@"create table if not exists vanity_address "
            "(address text not null primary key"
            " , vanity_len integer );";

    return self;
}

- (BOOL)initDatabase {
    BOOL result = YES;
    result &= [self initTxDb];
    result &= [self initAddressDb];
    return result;
}

- (BOOL)initTxDb {
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    int txDbVersion = (int) [userDefaultUtil integerForKey:TX_DB_VERSION];
    canOpenTxDb = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *documentsDirectory = paths[0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:TX_DB_NAME];
        canOpenTxDb = [fm fileExistsAtPath:writableDBPath];
        if (!canOpenTxDb) {
            txDbVersion = 0;
        }
        self.txQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.txQueue inDatabase:^(FMDatabase *db) {
            BOOL success = YES;
            if (txDbVersion < CURRENT_TX_DB_VERSION) {
                switch (txDbVersion) {
                    case 0://new
                        success = [self txInit:db];
                        if(success){
                            [self setTxDbVersion];
                        }
                        break;
                    case 1://upgrade v1.3.2->new version
                        success &= [self txV1ToV2:db];
                        if (success){
                            [self setTxDbVersion];
                        }
                    default:
                        break;
                }
            }
            canOpenTxDb=success;
        }];
    } else {
        canOpenTxDb = NO;
    }
    return canOpenTxDb;
}
-(void) setTxDbVersion{
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    [userDefaultUtil setInteger:CURRENT_TX_DB_VERSION forKey:TX_DB_VERSION];
    [userDefaultUtil synchronize];
}

- (BOOL)initAddressDb {
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    int addressDbVersion = (int) [userDefaultUtil integerForKey:ADDRESS_DB_VERSION];
    canOpenAddressDb = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths && paths.count > 0) {
        NSString *documentsDirectory = paths[0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:ADDRESS_DB_NAME];
        canOpenAddressDb = [fm fileExistsAtPath:writableDBPath];
        if (!canOpenAddressDb) {
            addressDbVersion = 0;
        }
        self.addressQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.addressQueue inDatabase:^(FMDatabase *db) {
            BOOL success = YES;
            if (addressDbVersion < CURRENT_ADDRESS_DB_VERSION) {
                switch (addressDbVersion) {
                    case 0://new
                        success = [self addressInit:db];
                        if (success) {
                            [self setAddressDbVersion];
                        }

                        break;
                    case 1://upgrade v1.3.1->v1.3.2
                        success &=[self addressV1ToV2:db];
                    case 2://upgrade v1.3.2->v1..3.4
                        success &= [self addressV2ToV3:db];
                    case 3://upgrade v1.3.4->1.3.5
                        success &=[self addressV3tOv4:db];
                        if (success) {
                            [self setAddressDbVersion];
                        }

                    default:
                        break;
                }
            }
            canOpenAddressDb = success;
        }];
    } else {
        canOpenAddressDb = NO;
    }
    return canOpenAddressDb;
}
-(void)setAddressDbVersion{
    NSUserDefaults *userDefaultUtil = [NSUserDefaults standardUserDefaults];
    [userDefaultUtil setInteger:CURRENT_ADDRESS_DB_VERSION forKey:ADDRESS_DB_VERSION];
    [userDefaultUtil synchronize];
}


- (BOOL)txInit:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.blocksSql];
        [db executeUpdate:self.indexBlocksBlockNoSql];
        [db executeUpdate:self.indexBlocksBlockPrevSql];
        [db executeUpdate:self.txsSql];
        [db executeUpdate:self.indexTxsBlockNoSql];
        [db executeUpdate:self.addressesTxsSql];
        [db executeUpdate:self.insSql];
        [db executeUpdate:self.indexInsPrevTxHashSql];
        [db executeUpdate:self.outsSql];
        [db executeUpdate:self.indexOutsOutAddressSql];
        [db executeUpdate:self.peersSql];
        [db executeUpdate:self.hdAccountAddress];
        [db executeUpdate:self.indexHDAccountAddress];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)addressInit:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.passwordSeedSql];
        [db executeUpdate:self.addressesSql];
        [db executeUpdate:self.hdSeedsSql];
        [db executeUpdate:self.hdmAddressesSql];
        [db executeUpdate:self.hdmBidSql];
        [db executeUpdate:self.aliasesSql];
        [db executeUpdate:self.hdAccountSql];
        [db executeUpdate:self.vanityAddressSql];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}
//v1.3.1
- (BOOL)addressV1ToV2:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.aliasesSql];
        [db executeUpdate:@"alter table hd_seeds add column singular_mode_backup text;"];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}
//v1.3.2
- (BOOL)addressV2ToV3:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.hdAccountSql];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}
-(BOOL)addressV3tOv4:(FMDatabase *)db{
    if([db open]){
        [db beginTransaction];
        [db executeUpdate:self.vanityAddressSql];
        [db commit];
        return YES;
    } else{
        return NO;
    }
}
//v1.3.2
- (BOOL)txV1ToV2:(FMDatabase *)db {
    if ([db open]) {
        [db beginTransaction];
        [db executeUpdate:self.hdAccountAddress];
        [db executeUpdate:self.indexHDAccountAddress];
        [db executeUpdate:@"alter table outs add column hd_account_id integer;"];
        [db commit];
        return YES;
    } else {
        return NO;
    }
}

- (FMDatabaseQueue *)getTxDbQueue {
    return self.txQueue;
}

- (FMDatabaseQueue *)getAddressDbQueue {
    return self.addressQueue;
}

- (void)closeDatabase {
    [self.txQueue close];
    [self.addressQueue close];
}

- (void)rebuildTxDb:(FMDatabase *)db {
    [db executeUpdate:@"drop table txs;"];
    [db executeUpdate:@"drop table ins;"];
    [db executeUpdate:@"drop table outs;"];
    [db executeUpdate:@"drop table addresses_txs;"];
    [db executeUpdate:@"drop table peers;"];

    [db executeUpdate:self.txsSql];
    [db executeUpdate:self.indexTxsBlockNoSql];

    [db executeUpdate:self.addressesTxsSql];
    [db executeUpdate:self.insSql];

    [db executeUpdate:self.indexInsPrevTxHashSql];
    [db executeUpdate:self.outsSql];
    [db executeUpdate:self.indexOutsOutAddressSql];
    [db executeUpdate:self.peersSql];

}

- (void)rebuildPeers:(FMDatabase *)db {
    [db executeUpdate:@"drop table peers;"];
    [db executeUpdate:[BTDatabaseManager instance].peersSql];
}

@end
