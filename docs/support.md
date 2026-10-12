---
layout: legal
title: Support
# The landing page and store registration URLs point to /support/ with a trailing slash, so publish this
# as a directory index rather than support.html
permalink: /support/
---

# Support

PasteCheck is a menu bar app that checks, inside your Mac, whether the text or images you copied to the clipboard contain strings that look like sensitive information, and warns you before you paste. This page covers frequently asked questions and how to contact the provider. PasteCheck is in development, and the descriptions of features on this page are what is planned for the first public version.

## Contact

- Email: bannzai.app@gmail.com
- In the app: click the menu bar icon and choose "Contact" to open an email addressed to the address above
- Bug reports and feature requests: https://github.com/bannzai/pastecheck/issues

Please do not write the detected value itself (the actual API key or token) in emails or issues. Describe the detection type and what format the string had.

## Frequently asked questions

### Something that should be detected is not detected

Detection is an estimate based on string patterns and cannot detect every kind of sensitive information. Please let us know the missed format through the contact above (do not write the actual value; describe only the format).

### Something that is not sensitive information is detected

Please let us know the falsely detected format through the contact above. You can turn each detection type on or off.

### Are clipboard contents sent anywhere?

No. All inspection happens inside your Mac, and clipboard contents are never written to files or the network. See the [Privacy Policy](../privacy/) for details.

### How do I delete my data?

PasteCheck's only data is its settings, which are in the app's container folder (`~/Library/Containers/com.bannzai.PasteCheck/`). The folder may remain after the app is deleted, so to remove everything, delete this folder.

## Privacy

PasteCheck does not collect user information. See the [Privacy Policy](../privacy/).
