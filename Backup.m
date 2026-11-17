#import "Backup.h"
#import <Security/Security.h>
#import <sys/stat.h>
#import <sys/time.h>

#define TAR_BLOCK 512
#define COPY_BUFFER_SIZE (1024 * 1024)

static NSString *const kManifestName = @"ApolloPatcher/manifest.plist";
static NSString *const kPreferencesName = @"ApolloPatcher/preferences.plist";
static NSString *const kKeychainName = @"ApolloPatcher/keychain.plist";
static NSString *const kGroupPreferencesName = @"ApolloPatcher/group-preferences.plist";
static NSString *const kReadyName = @".ready";

// Accounts, filters and themes are stored here
static NSString *const kAppGroup = @"group.com.christianselig.apollo";

static NSArray *topDirectories(void) {
    return @[@"Documents", @"Library"];
}

// Preferences are restored through CFPreferences, the others are managed by the system
// (SyncedPreferences cannot be modified from the sandbox)
static NSArray *excludedLibraryDirectories(void) {
    return @[@"Caches", @"Preferences", @"SplashBoard", @"Saved Application State", @"SyncedPreferences"];
}

static NSString *stagingDirectory(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"ApolloPatcherRestore"];
}

#pragma mark - tar (ustar + GNU long names)

static void tarOctal(char *field, size_t len, unsigned long long value) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%0*llo", (int)len - 1, value);
    memcpy(field, buf, len - 1);
    field[len - 1] = '\0';
}

static BOOL tarPad(FILE *fp, unsigned long long size) {
    static const char zeros[TAR_BLOCK];
    size_t pad = (TAR_BLOCK - size % TAR_BLOCK) % TAR_BLOCK;
    return pad == 0 || fwrite(zeros, 1, pad, fp) == pad;
}

static BOOL tarWriteRawHeader(FILE *fp, NSData *name, char type, unsigned long long size, mode_t mode, time_t mtime) {
    char header[TAR_BLOCK] = {0};
    memcpy(header, name.bytes, MIN(name.length, (NSUInteger)100));
    tarOctal(header + 100, 8, mode & 07777);
    tarOctal(header + 108, 8, 501);
    tarOctal(header + 116, 8, 501);
    tarOctal(header + 124, 12, size);
    tarOctal(header + 136, 12, mtime);
    header[156] = type;
    memcpy(header + 257, "ustar", 6);
    memcpy(header + 263, "00", 2);
    memset(header + 148, ' ', 8);
    unsigned int sum = 0;
    for (int i = 0; i < TAR_BLOCK; i++) sum += (unsigned char)header[i];
    snprintf(header + 148, 8, "%06o", sum);
    header[155] = ' ';
    return fwrite(header, 1, TAR_BLOCK, fp) == TAR_BLOCK;
}

static BOOL tarWriteHeader(FILE *fp, NSString *name, char type, unsigned long long size, mode_t mode, time_t mtime) {
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    if (nameData.length > 100) {
        NSMutableData *longName = [nameData mutableCopy];
        [longName appendBytes:"" length:1];
        if (!tarWriteRawHeader(fp, [@"././@LongLink" dataUsingEncoding:NSUTF8StringEncoding], 'L', longName.length, 0644, 0)) return NO;
        if (fwrite(longName.bytes, 1, longName.length, fp) != longName.length) return NO;
        if (!tarPad(fp, longName.length)) return NO;
    }
    return tarWriteRawHeader(fp, nameData, type, size, mode, mtime);
}

static BOOL tarWriteData(FILE *fp, NSString *name, NSData *data) {
    if (!tarWriteHeader(fp, name, '0', data.length, 0644, time(NULL))) return NO;
    if (data.length && fwrite(data.bytes, 1, data.length, fp) != data.length) return NO;
    return tarPad(fp, data.length);
}

// Unreadable files are skipped. A file that shrinks while being read is padded with zeros.
static BOOL tarWriteFile(FILE *fp, NSString *name, NSString *path, struct stat *st, char *buffer) {
    FILE *in = fopen(path.fileSystemRepresentation, "rb");
    if (!in) {
        NSLog(@"ApolloPatcher:Skip %@ (%d)", name, errno);
        return YES;
    }
    unsigned long long size = st->st_size;
    BOOL ok = tarWriteHeader(fp, name, '0', size, st->st_mode, st->st_mtime);
    unsigned long long remain = size;
    while (ok && remain > 0) {
        size_t chunk = (size_t)MIN(remain, (unsigned long long)COPY_BUFFER_SIZE);
        size_t n = fread(buffer, 1, chunk, in);
        if (n < chunk) memset(buffer + n, 0, chunk - n);
        ok = fwrite(buffer, 1, chunk, fp) == chunk;
        remain -= chunk;
    }
    fclose(in);
    return ok && tarPad(fp, size);
}

static NSString *tarField(const char *header, size_t offset, size_t len) {
    return [[NSString alloc] initWithBytes:header + offset length:strnlen(header + offset, len) encoding:NSUTF8StringEncoding];
}

static unsigned long long tarParseOctal(const char *header, size_t offset, size_t len) {
    char buf[16] = {0};
    memcpy(buf, header + offset, MIN(len, sizeof(buf) - 1));
    return strtoull(buf, NULL, 8);
}

static BOOL tarChecksumValid(const char *header) {
    unsigned int sum = 0;
    for (int i = 0; i < TAR_BLOCK; i++) sum += (i >= 148 && i < 156) ? ' ' : (unsigned char)header[i];
    return sum == tarParseOctal(header, 148, 8);
}

static BOOL isSafeName(NSString *name) {
    if (name.length == 0 || [name hasPrefix:@"/"]) return NO;
    for (NSString *component in [name componentsSeparatedByString:@"/"]) {
        if ([component isEqualToString:@".."]) return NO;
    }
    return YES;
}

static BOOL tarSkip(FILE *fp, unsigned long long size) {
    unsigned long long padded = (size + TAR_BLOCK - 1) / TAR_BLOCK * TAR_BLOCK;
    return fseeko(fp, (off_t)padded, SEEK_CUR) == 0;
}

static BOOL tarExtract(NSString *archivePath, NSString *destination) {
    FILE *fp = fopen(archivePath.fileSystemRepresentation, "rb");
    if (!fp) return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    char header[TAR_BLOCK];
    char *buffer = malloc(COPY_BUFFER_SIZE);
    NSString *longName = nil;
    BOOL ok = NO;

    while (fread(header, 1, TAR_BLOCK, fp) == TAR_BLOCK) {
        if (header[0] == '\0') {
            ok = YES;
            break;
        }
        if (!tarChecksumValid(header)) break;

        char type = header[156];
        unsigned long long size = tarParseOctal(header, 124, 12);
        NSString *name = longName;
        longName = nil;
        if (!name) {
            name = tarField(header, 0, 100);
            NSString *prefix = tarField(header, 345, 155);
            if (memcmp(header + 257, "ustar", 5) == 0 && prefix.length) {
                name = [prefix stringByAppendingPathComponent:name];
            }
        }

        if (type == 'L') {
            if (size == 0 || size > 4096) break;
            NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
            if (fread(data.mutableBytes, 1, (size_t)size, fp) != size) break;
            if (fseeko(fp, (off_t)((TAR_BLOCK - size % TAR_BLOCK) % TAR_BLOCK), SEEK_CUR) != 0) break;
            longName = tarField(data.bytes, 0, (size_t)size);
            continue;
        }

        if (!name || !isSafeName(name)) break;
        NSString *path = [destination stringByAppendingPathComponent:name];

        if (type == '5') {
            if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) break;
            if (!tarSkip(fp, size)) break;
            continue;
        }
        if (type != '0' && type != '\0') {
            if (!tarSkip(fp, size)) break;
            continue;
        }

        [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        FILE *out = fopen(path.fileSystemRepresentation, "wb");
        if (!out) break;
        BOOL fileOK = YES;
        unsigned long long remain = size;
        while (fileOK && remain > 0) {
            size_t chunk = (size_t)MIN(remain, (unsigned long long)COPY_BUFFER_SIZE);
            fileOK = fread(buffer, 1, chunk, fp) == chunk && fwrite(buffer, 1, chunk, out) == chunk;
            remain -= chunk;
        }
        fclose(out);
        if (!fileOK) break;
        chmod(path.fileSystemRepresentation, (mode_t)(tarParseOctal(header, 100, 8) & 0777) | S_IRUSR | S_IWUSR);
        time_t mtime = (time_t)tarParseOctal(header, 136, 12);
        struct timeval times[2] = {{mtime, 0}, {mtime, 0}};
        utimes(path.fileSystemRepresentation, times);
        if (fseeko(fp, (off_t)((TAR_BLOCK - size % TAR_BLOCK) % TAR_BLOCK), SEEK_CUR) != 0) break;
    }

    free(buffer);
    fclose(fp);
    return ok;
}

#pragma mark - Keychain

static NSArray *secClasses(void) {
    return @[(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecClassInternetPassword,
             (__bridge id)kSecClassKey,
             (__bridge id)kSecClassCertificate];
}

// Attributes that can be passed back to SecItemAdd, per class
static NSArray *restorableKeys(id secClass) {
    NSArray *common = @[(__bridge id)kSecAttrAccessGroup,
                        (__bridge id)kSecAttrAccessible,
                        (__bridge id)kSecAttrSynchronizable,
                        (__bridge id)kSecAttrLabel];
    if ([secClass isEqual:(__bridge id)kSecClassKey]) {
        return [common arrayByAddingObjectsFromArray:@[(__bridge id)kSecAttrKeyClass,
                                                       (__bridge id)kSecAttrKeyType,
                                                       (__bridge id)kSecAttrKeySizeInBits,
                                                       (__bridge id)kSecAttrEffectiveKeySize,
                                                       (__bridge id)kSecAttrApplicationLabel,
                                                       (__bridge id)kSecAttrApplicationTag,
                                                       (__bridge id)kSecAttrCanEncrypt,
                                                       (__bridge id)kSecAttrCanDecrypt,
                                                       (__bridge id)kSecAttrCanDerive,
                                                       (__bridge id)kSecAttrCanSign,
                                                       (__bridge id)kSecAttrCanVerify,
                                                       (__bridge id)kSecAttrCanWrap,
                                                       (__bridge id)kSecAttrCanUnwrap]];
    }
    if ([secClass isEqual:(__bridge id)kSecClassCertificate]) {
        return common;
    }
    return [common arrayByAddingObjectsFromArray:@[(__bridge id)kSecAttrAccount,
                                                   (__bridge id)kSecAttrService,
                                                   (__bridge id)kSecAttrGeneric,
                                                   (__bridge id)kSecAttrDescription,
                                                   (__bridge id)kSecAttrComment,
                                                   (__bridge id)kSecAttrCreator,
                                                   (__bridge id)kSecAttrType,
                                                   (__bridge id)kSecAttrIsInvisible,
                                                   (__bridge id)kSecAttrIsNegative,
                                                   (__bridge id)kSecAttrServer,
                                                   (__bridge id)kSecAttrProtocol,
                                                   (__bridge id)kSecAttrAuthenticationType,
                                                   (__bridge id)kSecAttrPort,
                                                   (__bridge id)kSecAttrPath,
                                                   (__bridge id)kSecAttrSecurityDomain]];
}

// Secure Enclave keys cannot be exported
static BOOL isTokenItem(NSDictionary *item) {
    return item[(__bridge id)kSecAttrTokenID] != nil;
}

static NSArray *copyItems(id secClass, id synchronizable) {
    NSDictionary *query = @{(__bridge id)kSecClass: secClass,
                            (__bridge id)kSecAttrSynchronizable: synchronizable,
                            (__bridge id)kSecReturnAttributes: @YES,
                            (__bridge id)kSecReturnPersistentRef: @YES,
                            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return @[];
    if (status != errSecSuccess) {
        NSLog(@"ApolloPatcher:SecItemCopyMatching(%@):%d", secClass, (int)status);
        return nil;
    }
    return (__bridge_transfer NSArray *)result;
}

// *data is nil for an item without data
static BOOL copyItemData(NSDictionary *item, NSData **data) {
    NSDictionary *query = @{(__bridge id)kSecValuePersistentRef: item[(__bridge id)kSecValuePersistentRef],
                            (__bridge id)kSecReturnData: @YES};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        NSLog(@"ApolloPatcher:SecItemCopyMatching(data):%d", (int)status);
        return NO;
    }
    *data = (__bridge_transfer NSData *)result;
    return YES;
}

static NSArray *backupKeychain(void) {
    NSMutableArray *keychainArray = [NSMutableArray array];
    for (id secClass in secClasses()) {
        NSArray *items = copyItems(secClass, (__bridge id)kSecAttrSynchronizableAny);
        if (!items) return nil;
        for (NSDictionary *item in items) {
            if (isTokenItem(item)) continue;
            NSData *data = nil;
            if (!copyItemData(item, &data)) return nil;
            NSMutableDictionary *itemCopy = [NSMutableDictionary dictionary];
            for (id key in restorableKeys(secClass)) {
                if (item[key]) itemCopy[key] = item[key];
            }
            itemCopy[(__bridge id)kSecClass] = secClass;
            if (data) itemCopy[(__bridge id)kSecValueData] = data;
            [keychainArray addObject:itemCopy];
        }
    }
    return keychainArray;
}

// Only the items stored on this device; deleting iCloud Keychain items would affect other devices
static void wipeLocalKeychain(void) {
    for (id secClass in secClasses()) {
        for (NSDictionary *item in copyItems(secClass, @NO)) {
            if (isTokenItem(item)) continue;
            NSDictionary *query = @{(__bridge id)kSecValuePersistentRef: item[(__bridge id)kSecValuePersistentRef]};
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
            if (status != errSecSuccess && status != errSecItemNotFound) {
                NSLog(@"ApolloPatcher:SecItemDelete(%@):%d", secClass, (int)status);
            }
        }
    }
}

// The access group (team ID prefix) differs when sideloaded, and iCloud Keychain is often unavailable,
// so the items go to the default access group of this device only.
static NSUInteger restoreKeychain(NSArray *keychainArray) {
    wipeLocalKeychain();
    NSUInteger failed = 0;
    for (NSDictionary *item in keychainArray) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSMutableDictionary *query = [item mutableCopy];
        [query removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
        [query removeObjectForKey:(__bridge id)kSecAttrSynchronizable];
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        if (status != errSecSuccess && status != errSecDuplicateItem) {
            NSLog(@"ApolloPatcher:SecItemAdd:%d", (int)status);
            failed++;
        }
    }
    return failed;
}

#pragma mark - Preferences

static NSString *preferencesDirectory(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences"];
}

static NSDictionary *backupPreferences(void) {
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSMutableSet *domains = [NSMutableSet setWithObject:[NSBundle mainBundle].bundleIdentifier];
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:preferencesDirectory() error:nil]) {
        if ([file.pathExtension isEqualToString:@"plist"]) {
            [domains addObject:file.stringByDeletingPathExtension];
        }
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *domain in domains) {
        CFDictionaryRef values = CFPreferencesCopyMultiple(NULL, (__bridge CFStringRef)domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (values) result[domain] = (__bridge_transfer NSDictionary *)values;
    }
    return result;
}

static void restorePreferences(NSDictionary *preferences) {
    for (NSString *domain in preferences) {
        NSDictionary *values = preferences[domain];
        if (![domain isKindOfClass:[NSString class]] || ![values isKindOfClass:[NSDictionary class]]) continue;
        CFStringRef appID = (__bridge CFStringRef)domain;
        CFArrayRef keys = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keys) {
            CFPreferencesSetMultiple(NULL, keys, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            CFRelease(keys);
        }
        CFPreferencesSetMultiple((__bridge CFDictionaryRef)values, NULL, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    }
}

// A suite instance resolves the app group container (or the home directory when the group is unavailable)
static NSDictionary *backupGroupPreferences(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroup];
    [defaults synchronize];
    return [defaults persistentDomainForName:kAppGroup] ?: @{};
}

static void restoreGroupPreferences(NSDictionary *values) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroup];
    for (NSString *key in [defaults persistentDomainForName:kAppGroup]) {
        [defaults removeObjectForKey:key];
    }
    for (NSString *key in values) {
        [defaults setObject:values[key] forKey:key];
    }
    [defaults synchronize];
}

#pragma mark - Backup

static BOOL writePlist(FILE *fp, NSString *name, id plist) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    return data && tarWriteData(fp, name, data);
}

static BOOL writeDirectory(FILE *fp, NSString *top, char *buffer) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSString *topPath = [home stringByAppendingPathComponent:top];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:topPath isDirectory:&isDir] || !isDir) return YES;

    BOOL isLibrary = [top isEqualToString:@"Library"];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:topPath];
    for (NSString *relative in enumerator) {
        if (isLibrary && enumerator.level == 1 && [excludedLibraryDirectories() containsObject:relative]) {
            [enumerator skipDescendants];
            continue;
        }
        NSString *name = [top stringByAppendingPathComponent:relative];
        NSString *path = [home stringByAppendingPathComponent:name];
        struct stat st;
        if (lstat(path.fileSystemRepresentation, &st) != 0) continue;
        if (S_ISDIR(st.st_mode)) {
            if (!tarWriteHeader(fp, [name stringByAppendingString:@"/"], '5', 0, st.st_mode, st.st_mtime)) return NO;
        } else if (S_ISREG(st.st_mode)) {
            if (!tarWriteFile(fp, name, path, &st, buffer)) return NO;
        }
    }
    return YES;
}

NSURL *APCreateBackup(NSString **error) {
    NSArray *keychain = backupKeychain();
    if (!keychain) {
        if (error) *error = @"Failed to read the keychain.";
        return nil;
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"apollo-backup-%@.tar", [formatter stringFromDate:[NSDate date]]];
    NSString *archivePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    FILE *fp = fopen(archivePath.fileSystemRepresentation, "wb");
    if (!fp) {
        if (error) *error = @"Could not create the backup file.";
        return nil;
    }

    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSDictionary *manifest = @{@"format": @1,
                               @"bundleID": [NSBundle mainBundle].bundleIdentifier ?: @"",
                               @"appVersion": info[@"CFBundleShortVersionString"] ?: @"",
                               @"date": [NSDate date]};

    char *buffer = malloc(COPY_BUFFER_SIZE);
    BOOL ok = writePlist(fp, kManifestName, manifest)
           && writePlist(fp, kPreferencesName, backupPreferences())
           && writePlist(fp, kGroupPreferencesName, backupGroupPreferences())
           && writePlist(fp, kKeychainName, keychain);
    for (NSString *top in topDirectories()) {
        ok = ok && writeDirectory(fp, top, buffer);
    }
    free(buffer);

    static const char zeros[TAR_BLOCK * 2];
    ok = ok && fwrite(zeros, 1, sizeof(zeros), fp) == sizeof(zeros);
    ok = (fclose(fp) == 0) && ok;

    if (!ok) {
        [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
        if (error) *error = @"Failed to write the backup file. Check the free storage.";
        return nil;
    }
    return [NSURL fileURLWithPath:archivePath];
}

#pragma mark - Restore

NSDictionary *APPrepareRestore(NSURL *archiveURL, NSString **error) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *stage = stagingDirectory();
    [fm removeItemAtPath:stage error:nil];
    [fm createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:nil error:nil];

    BOOL extracted = tarExtract(archiveURL.path, stage);
    NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:[stage stringByAppendingPathComponent:kManifestName]];
    if (!extracted || ![manifest[@"format"] isKindOfClass:[NSNumber class]]) {
        [fm removeItemAtPath:stage error:nil];
        if (error) *error = extracted ? @"This is not an ApolloPatcher backup file." : @"Failed to read the backup file.";
        return nil;
    }
    return manifest;
}

BOOL APCommitRestore(void) {
    NSString *ready = [stagingDirectory() stringByAppendingPathComponent:kReadyName];
    return [[NSData data] writeToFile:ready atomically:YES];
}

void APCancelRestore(void) {
    [[NSFileManager defaultManager] removeItemAtPath:stagingDirectory() error:nil];
}

static void replaceDirectory(NSString *top, NSString *stage, NSMutableArray *failed) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *target = [NSHomeDirectory() stringByAppendingPathComponent:top];
    NSArray *keep = [top isEqualToString:@"Library"] ? excludedLibraryDirectories() : @[];

    for (NSString *item in [fm contentsOfDirectoryAtPath:target error:nil]) {
        if ([keep containsObject:item]) continue;
        [fm removeItemAtPath:[target stringByAppendingPathComponent:item] error:nil];
    }
    [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *source = [stage stringByAppendingPathComponent:top];
    for (NSString *item in [fm contentsOfDirectoryAtPath:source error:nil]) {
        if ([keep containsObject:item]) continue;
        NSError *moveError = nil;
        if (![fm moveItemAtPath:[source stringByAppendingPathComponent:item]
                         toPath:[target stringByAppendingPathComponent:item]
                          error:&moveError]) {
            NSLog(@"ApolloPatcher:Move %@:%@", item, moveError);
            [failed addObject:[top stringByAppendingPathComponent:item]];
        }
    }
}

NSString *APApplyPendingRestore(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *stage = stagingDirectory();
    if (![fm fileExistsAtPath:stage]) return nil;
    if (![fm fileExistsAtPath:[stage stringByAppendingPathComponent:kReadyName]]) {
        [fm removeItemAtPath:stage error:nil];
        return nil;
    }

    NSMutableArray *failed = [NSMutableArray array];
    for (NSString *top in topDirectories()) {
        replaceDirectory(top, stage, failed);
    }

    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:[stage stringByAppendingPathComponent:kPreferencesName]];
    if (preferences) restorePreferences(preferences);

    NSDictionary *groupPreferences = [NSDictionary dictionaryWithContentsOfFile:[stage stringByAppendingPathComponent:kGroupPreferencesName]];
    if (groupPreferences) restoreGroupPreferences(groupPreferences);

    NSUInteger keychainFailed = 0;
    NSData *keychainData = [NSData dataWithContentsOfFile:[stage stringByAppendingPathComponent:kKeychainName]];
    if (keychainData) {
        NSArray *keychain = [NSPropertyListSerialization propertyListWithData:keychainData options:NSPropertyListImmutable format:NULL error:nil];
        if ([keychain isKindOfClass:[NSArray class]]) keychainFailed = restoreKeychain(keychain);
    }

    [fm removeItemAtPath:stage error:nil];

    if (failed.count) return [NSString stringWithFormat:@"Some files could not be restored.\n%@", [failed componentsJoinedByString:@"\n"]];
    if (keychainFailed) return [NSString stringWithFormat:@"Restore completed.\n(Failed to restore %lu keychain items)", (unsigned long)keychainFailed];
    return @"Restore completed.";
}
