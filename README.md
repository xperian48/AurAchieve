# AuraAscend

**Fix you damn life.**

AuraAscend is the only self-improvement app you'll ever need. Earn Aura for every good thing you do. Prove it with AI, a timer, or just your honesty.

Get it now through [GitHub actions](https://github.com/NiceSapien/AuraAscend/actions).

## Self-hosting

If you wish to self-host AuraAscend for some reason, you'll have to clone the [backend](https://github.com/NiceSapien/AuraAscend-backend) repository aswell, written in ExpressJS. The instructions to setup the backend are present in the repository readme.

To setup the frontend:

1. Clone the repository
2. Install flutter and download packages

```bash
pub get && flutter pub get
```

3. Edit lib/api_service.dart with your own backend URL. Do **not** use our API link!

4. Update lib/main.dart with you own appwrite project. Do **not** use our project ID!

5. Build. That's all.

```bash
flutter build apk --debug
```

## Contributing

There's not much about contributing yet. Make sure to deploy your own backend and not use our API link for testing. After you're done, revert it back to ours and make a pull request. Here's how you may make commits:

`feat`: For new features

`improve`: For improvement of existing features

`fix`: For bug fixes

`delete`: For deleting something

`upgrade`: For upgrading/updating something, such as dependencies

`docs`: Anything related to documentation and not to the codebase itself

`refactor`: When refactoring some part of the codebase.

## Sponsors

Currently, there are no sponsors.

If you appreciate AuraAscend and want to keep it free for everyone, please [Sponsor](https://github.com/sponsors/NiceSapien) me.



Current goals:

Any amount - Show appreciation and help keep AuraAscend free

**20$** - Buy a domain for the website

**100$** - Publish AuraAscend on the Apple App Store