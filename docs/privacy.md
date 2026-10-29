---
layout: legal
title: Privacy Policy
# The landing page and store registration URLs point to /privacy/ with a trailing slash, so publish this
# as a directory index rather than privacy.html
permalink: /privacy/
---

# Privacy Policy

bannzai (the "Provider") sets out this Privacy Policy (this "Policy") on how user information is handled in the macOS app "PasteCheck" (the "App"). The App is in development, and this Policy is written based on the design of the first public version (`documents/PROJECT.md`). It will be updated against the implementation at release.

## Summary

- The App does not collect, transmit, or sell user information. The Provider does not operate any servers, and nothing done in the App ever reaches the Provider
- Inspection of clipboard contents (text and images) happens only inside the user's Mac. Clipboard contents are never sent to the network
- The App contains no analytics, advertising, crash reporting, or tracking, and requires no account

## Information the App handles inside the user's Mac

### Clipboard contents

The App checks whether the text or images the user copies contain strings that look like sensitive information (API keys, access tokens, private keys, credit card numbers, and so on), and shows a warning if they do. All inspection happens inside the user's Mac, and clipboard contents are not written to files, logs, the App's settings, or the network, and the App does not hand them to other apps or command-line tools, with no exceptions. A warning shows only the type and position of what was detected and, when available, the name of the app that was in front when the clipboard change was noticed, never the detected value itself.

<!-- source: PasteCheckCore/Sources/PasteCheckCore/WarningMessage.swift: body(textFindings:imageFindings:frontmostAppName:) appends ", while <app> was in front" when frontmostAppName is not nil. documents/PROJECT.md "Invariants" 1 is the scope of what is not written or passed on. -->


### Settings

Settings such as enabling or disabling inspection, turning each detection type on or off, and launching at login are stored only inside the user's Mac (the App's settings file).

### Permissions

When the App asks for a macOS permission (for example, launching at login), it explains the reason on the App's screen, and the user manages allowing or denying it in macOS System Settings.

## Information the Provider collects and purposes of use

The Provider does not collect user information through the App. If a user contacts the Provider by email, the Provider uses that contact information and content only to answer that inquiry. It is not used for any other purpose.

## What the App does not use

- Analytics and usage measurement (analytics tools such as Google Analytics or Firebase Analytics): not used. The App does not send information outside
- Advertising and advertising identifiers: not used
- External AI services and cloud language models: not used. All inspection happens inside the user's Mac, and clipboard contents are never sent to an external AI
- Contractors handling information (servers, analytics providers, and so on): none
- Provision to third parties in foreign countries: none

## Provision to third parties

The Provider does not hold user information, so it never provides any to third parties. Information contained in inquiries is not provided to third parties except as required by law.

## Requests for disclosure, correction, or suspension of use

The only user information the Provider holds is the information contained in inquiries from users. If you wish to have it disclosed, corrected, suspended from use, or deleted, contact the Provider at the address under "Contact" below. The Provider will respond without delay after verifying your identity.

## Deleting information

All of the App's data is inside the user's Mac, and settings are stored in the App's container folder (`~/Library/Containers/com.bannzai.PasteCheck/`). This folder may remain after the App is deleted, so to remove everything including settings, delete this folder. The App does not store clipboard contents, so there is nothing to delete for them.

<!-- source: PasteCheck/PasteCheck.entitlements (com.apple.security.app-sandbox = true). That a sandboxed app's data is placed in ~/Library/Containers/<bundle id>/ follows the container description in Apple's App Sandbox documentation (https://developer.apple.com/documentation/security/app-sandbox). Whether the container remains after the app is deleted could not be confirmed in Apple's primary sources, so this says it "may remain" -->


## Contact

For inquiries about this Policy and the handling of information, contact:

- bannzai.app@gmail.com

## Changes to this Policy

The Provider may change this Policy. The latest version is always published at this address, and the history of changes can be viewed in the source repository.

Effective date: October 10, 2026
