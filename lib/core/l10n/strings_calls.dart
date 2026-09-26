import 'app_strings.dart';

/// Missed-dose calls. The call itself says the medicine name, not these lines.
extension CallStrings on AppStrings {
  String get callDemo => pick('Call demo', 'कॉल डेमो');

  String callDemoConfirm(String phone, String medicines) => pick(
    'Request a call to $phone about $medicines? The call says that name only.',
    '$phone पर $medicines के लिए कॉल का अनुरोध करें? कॉल में सिर्फ़ यही नाम बोला जाएगा।',
  );

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
