# ApolloPatcher
Apollo for Reddit tweak with in-app configurable API keys  

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/2e71cc2d-a913-484e-864a-4d6c92be30ae" width="320" alt="Settings Cell">

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/ba4e2be9-3aa3-4bb3-bb02-c36ceb143275" width="320" alt="Settings View">

## Notes
- **There is a known issue with crashes when trying to use Apollo Pro or Ultra features.**
- **Apollo version 1.15.11 or lower is required.**

## Installation

Download the IPA from the [Releases](https://github.com/ichitaso/ApolloPatcher/releases) page. ApolloPatcher is already included.

| IPA | iOS |
|---|---|
| `Apollo-1.15.11_ApolloPatcher_x.x.x.ipa` | iOS 15 or later |
| `Apollo-1.8.7_ApolloPatcher_x.x.x.ipa` | iOS 13 / 14 |

`Apollo-1.15.11_ApolloPatcher_x.x.x_full.ipa` keeps the app extensions (widgets, Safari extension, etc.). Use it only with a paid developer certificate, since extensions need extra App IDs and make sideloading tools warn.

Install it with whichever works on your device:

| Your device | How to install |
|---|---|
| TrollStore supported (iOS 14.0–16.6.1, 16.7 RC, 17.0) | TrollStore |
| Jailbroken (any version) | TrollStore Lite or AppSync Unified |
| Others | Sideloading (AltStore, Sideloadly, etc.) |

### Jailbreak (deb)

If Apollo 1.15.11 or lower is already installed, you can install ApolloPatcher from the repo instead: https://cydia.ichitaso.com

App Store downgrade tools (AppStore++, MuffinStore, etc.) may no longer work, so use the IPA if you can't downgrade. Don't install the deb together with the IPA.

> [!WARNING]
> Per the recent [Responsible Builder Policy](https://www.reddit.com/r/redditdev/comments/1oug31u/introducing_the_responsible_builder_policy_new/), you can no longer generated new API keys that use Oauth without Reddit's explicit approval. If you have an existing key, you should still be able to use this. If you do not have one, see [No API key? Use Dystopia](#no-api-key-use-dystopia).

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

## No API key? Use Dystopia

If you can't create your own Reddit API key, you can use the App ID of [Dystopia for Reddit](https://apps.apple.com/us/app/dystopia-for-reddit/id1430599061) instead.

### 1. Get the App ID from Dystopia

1. Install **Dystopia** from the App Store (any iPhone/iPad is fine).
2. Open Dystopia, sign in with your Reddit account and tap **Allow**.
3. Reddit sends you an email titled **"You've authorized a new app in your Reddit account"**.
4. Copy the text after **"App ID"** in that email.

### 2. Set up ApolloPatcher

1. Open the ApolloPatcher settings in Apollo.
2. Paste the App ID into **Reddit API Key**.
3. Turn on **Use Dystopia**.
4. Tap **Apply** (Apollo closes).

### 3. Sign in to Apollo

1. Open Apollo again and add your Reddit account.
2. Reddit asks you to connect your account to **Dystopia**. Tap **Allow**.
3. Done!

> [!NOTE]
> Turn **Use Dystopia** off again if you switch back to your own API key.

Credits: [Apollo-Reborn](https://github.com/Apollo-Reborn/Apollo-Reborn) and [patcheddit](https://github.com/wchill/patcheddit) for the original workaround.

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

## Building the IPA

Put the decrypted `Apollo-1.15.11.ipa` / `Apollo-1.8.7.ipa` in `jailed/` and run `jailed/build.sh`. The IPAs are written to `jailed/out/`.

## Packages Repo
https://cydia.ichitaso.com

## Description page
[ApolloPatcher | ichitaso's Repository](https://cydia.ichitaso.com/depiction/apollopatcher.html)

## Donation
- https://cydia.ichitaso.com/donation.html
- https://ko-fi.com/ichitaso

<img src="https://github.com/ichitaso/ApolloPatcher/assets/980215/ed25cfcf-922e-4c7b-9bbd-f32d86deeb32" width="320" alt="demo">
