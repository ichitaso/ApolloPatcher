#import <Foundation/Foundation.h>

__BEGIN_DECLS

// Archive of Documents, Library, preferences and keychain. nil on error.
NSURL *APCreateBackup(NSString **error);
// Extracts the archive into the staging directory and returns its manifest. nil on error.
NSDictionary *APPrepareRestore(NSURL *archiveURL, NSString **error);
// Marks the staged backup to be restored on the next launch.
BOOL APCommitRestore(void);
void APCancelRestore(void);
// Called at launch before the app loads its data. Returns a message to show, or nil if nothing was restored.
NSString *APApplyPendingRestore(void);

__END_DECLS
