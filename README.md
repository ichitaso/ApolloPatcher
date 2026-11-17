# ApolloPatcher
Apollo for Reddit tweak with in-app configurable API keys  

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/2e71cc2d-a913-484e-864a-4d6c92be30ae" width="320" alt="Settings Cell">

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/ba4e2be9-3aa3-4bb3-bb02-c36ceb143275" width="320" alt="Settings View">

## Notes
- **There is a known issue with crashes when trying to use Apollo Pro or Ultra features.**
- **Apollo version 1.15.11 or lower is required.**
  
If you are jailbroken, please downgrade via AppStore++.

TrollStore IPA: [AppStore++_TrollStore_v1.0.3-2.ipa](https://github.com/CokePokes/AppStorePlus-TrollStore/releases/download/v1.2-1/AppStore++_TrollStore_v1.0.3-2.ipa)

Repo: https://cokepokes.github.io

> [!WARNING]
> Per the recent [Responsible Builder Policy](https://www.reddit.com/r/redditdev/comments/1oug31u/introducing_the_responsible_builder_policy_new/), you can no longer generated new API keys that use Oauth without Reddit's explicit approval. If you have an existing key, you should still be able to use this. If you do not and/or are setting this up for the first time, you are out of luck.

## Reddit Settings

sign out of all accounts in Apollo before installing

1. Sign into your reddit account (on desktop) and go here:  
    [https://reddit.com/prefs/apps](https://reddit.com/prefs/apps)
3. Click the `are you a developer? create an app...` button
4. Fill in the fields
	* name: Use whatever
	* Choose `Installed App`
	* description: blank space
	* about url: blank space
	* redirect uri: **`apollo://reddit-oauth`**
5. `create app`

6. After creating the app you'll get a client identifier

7. Enter it in the "Reddit API Key" in the settings.

8. It currently works without Imgur settings.

## Imgur Settings
**The Imgur client ID is tentatively created by me, but may stop if there are too many requests.**

### How to create

1. If you do not have an Imgur account, please create one:  
   https://imgur.com/

2. After creating an account, create an app from the following page  
   https://api.imgur.com/oauth2/addclient

3. Authorization type: is OK with "OAuth 2 authorization without a callback URL

4. Fill in the other fields to get a "Client ID".
  
   https://imgur.com/account/settings/apps  
   You can also check the Client ID from the above link if you are logged in.

5. Enter it in the "Imgur API Key" in the settings.

  Added ability to upload and delete images to Imgur
  Multiple images (album creation) fails at first but works the next time.

## Backup & Restore

Back up and restore Apollo's data from the ApolloPatcher settings.

- **Backup**: Saves accounts, settings, filters, themes, saved items and keychain to a `.tar` file (Files app, AirDrop, etc.).
- **Restore**: Select a backup file. Apollo closes and restores it on the next launch.

Useful when reinstalling Apollo or moving between jailbreak, TrollStore and sideloading.

> [!CAUTION]
> The backup file contains your login tokens unencrypted. Keep it safe and do not share it.

## For sideloading

the IPA is available on the GitHub release page.

"ApolloPatcher.dylib" are already included, so all you need to do is install them from AltStore or other sources.  

If you make your own, use decrypted IPA and deb files  
(Do not use the IPA file from the release page)

## Packages Repo
https://cydia.ichitaso.com

## Description page
[ApolloPatcher | ichitaso's Repository](https://cydia.ichitaso.com/depiction/apollopatcher.html)

## Donation
- https://cydia.ichitaso.com/donation.html
- https://ko-fi.com/ichitaso

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/ed25cfcf-922e-4c7b-9bbd-f32d86deeb32" width="320" alt="demo">
