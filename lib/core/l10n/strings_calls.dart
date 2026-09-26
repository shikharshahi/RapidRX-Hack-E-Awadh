import 'app_strings.dart';

/// Missed-dose calls. The call itself says the medicine name, not these lines.
extension CallStrings on AppStrings {
  String get callDemo => pick('Demo Medicine Call', 'डेमो दवाई कॉल');

  String get bayUpdated =>
      pick('Shown in the notification bay.', 'नोटिफिकेशन बे में दिख गया।');

  String get bayMissed => pick(
    'The notification bay did not update.',
    'नोटिफिकेशन बे अपडेट नहीं हुआ।',
  );

  String get whatsAppSent =>
      pick('WhatsApp alert sent.', 'WhatsApp अलर्ट भेज दिया।');

  String get whatsAppNeedsSender => pick(
    'WhatsApp needs the Twilio sender number.',
    'WhatsApp के लिए Twilio का नंबर सेट नहीं है।',
  );

  String get whatsAppFailed =>
      pick('WhatsApp was not sent.', 'WhatsApp नहीं गया।');

  String get callNotConfigured => pick(
    'Calls are not configured. No call was placed.',
    'कॉल सेट नहीं है। कोई कॉल नहीं गई।',
  );

  String get callRequested => pick('Call requested.', 'कॉल का अनुरोध हो गया।');

  String get callFailed =>
      pick('The call could not be requested.', 'कॉल का अनुरोध नहीं हो सका।');

  String get callNoPhone => pick(
    'No mobile number on this profile.',
    'इस प्रोफ़ाइल पर मोबाइल नंबर नहीं है।',
  );

  String get callNoDose => pick(
    'No medicine is due, so nothing was called.',
    'कोई दवाई बाकी नहीं है, इसलिए कॉल नहीं गई।',
  );

  String callUnanswered(String name, String slot) => pick(
    '$name: nobody answered the call about the $slot medicines.',
    '$name: $slot की दवाई वाली कॉल का जवाब नहीं मिला।',
  );

  String callHelp(String name, String slot) => pick(
    '$name: asked us to tell you about the $slot medicines.',
    '$name: $slot की दवाई के बारे में आपको बताने को कहा है।',
  );
}
