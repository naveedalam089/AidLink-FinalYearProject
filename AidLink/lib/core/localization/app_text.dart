// Purpose: Localization strings for supported UI text (Urdu translations shown here).
// File: lib/core/localization/app_text.dart

import 'package:flutter/material.dart';

class AppText {
  // --- Urdu translation map keyed by English source text ---
  static const Map<String, String> _ur = {
    'Settings': 'ترتیبات',
    'Profile': 'پروفائل',
    'Preferences': 'ترجیحات',
    'Security': 'سیکیورٹی',
    'Account': 'اکاؤنٹ',
    'Language': 'زبان',
    'Choose app language': 'ایپ کی زبان منتخب کریں',
    'English': 'انگریزی',
    'Urdu': 'اردو',
    'Save Profile': 'پروفائل محفوظ کریں',
    'Saving...': 'محفوظ کیا جا رہا ہے...',
    'Push notifications': 'پش نوٹیفکیشنز',
    'Email updates': 'ای میل اپ ڈیٹس',
    'Appointment reminders': 'اپائنٹمنٹ یاد دہانیاں',
    'Change password': 'پاس ورڈ تبدیل کریں',
    'Send password reset email': 'پاس ورڈ ری سیٹ ای میل بھیجیں',
    'Help & Support': 'مدد اور معاونت',
    'Sign out': 'لاگ آؤٹ',
    'Nearby Doctors & Clinics': 'قریبی ڈاکٹرز اور کلینکس',
    'Free live map powered by OpenStreetMap':
        'اوپن اسٹریٹ میپ سے چلنے والا لائیو نقشہ',
    'Refresh': 'ریفریش',
    'See all nearby': 'تمام قریبی دیکھیں',
    'Doctor': 'ڈاکٹر',
    'Clinic': 'کلینک',
    'You': 'آپ',
    'View Profile': 'پروفائل دیکھیں',
    'Close': 'بند کریں',
    'Keep Browsing': 'مزید دیکھتے رہیں',
    'Unable to load nearby providers.': 'قریبی فراہم کنندگان لوڈ نہیں ہو سکے۔',
    'Unable to get your current location.': 'موجودہ لوکیشن حاصل نہیں ہو سکی۔',
    'nearby providers': 'قریبی فراہم کنندگان',
    'Open settings': 'ترتیبات کھولیں',
    'Choose how AidLink keeps you informed.':
        'منتخب کریں کہ AidLink آپ کو کیسے باخبر رکھے۔',
    'Language updated.': 'زبان اپ ڈیٹ ہو گئی۔',
    'Preferences saved.': 'ترجیحات محفوظ ہو گئیں۔',
    'Could not save preferences.': 'ترجیحات محفوظ نہیں ہو سکیں۔',
    'Could not load settings right now.': 'اس وقت ترتیبات لوڈ نہیں ہو سکیں۔',
    'Profile updated successfully.': 'پروفائل کامیابی سے اپ ڈیٹ ہو گیا۔',
    'Could not update profile.': 'پروفائل اپ ڈیٹ نہیں ہو سکا۔',
    'No email found': 'ای میل نہیں ملی',
    'Not synced yet': 'ابھی ہم آہنگ نہیں ہوا',
    'Synced just now': 'ابھی ہم آہنگ ہوا',
    'Welcome': 'خوش آمدید',
    'Find the right doctor for your health needs':
        'اپنی صحت کے لیے درست ڈاکٹر تلاش کریں',
    'Search by doctor or speciality...': 'ڈاکٹر یا تخصص سے تلاش کریں...',
    'Categories': 'اقسام',
    'Symptoms': 'علامات',
    'Recommended Doctors': 'تجویز کردہ ڈاکٹرز',
    'General Physician': 'جنرل فزیشن',
    'Cardiologist': 'قلب کے ڈاکٹر',
    'Dermatologist': 'جلد کے ڈاکٹر',
    'Dentist': 'دانتوں کے ڈاکٹر',
    'Neurologist': 'اعصاب کے ڈاکٹر',
    'Orthopedic': 'ہڈیوں کے ڈاکٹر',
    'Pediatrician': 'بچوں کے ڈاکٹر',
    'Gynecologist': 'ماہرِ امراضِ نسواں',
    'ENT Specialist': 'ناک کان گلا ماہر',
    'Psychiatrist': 'ماہرِ نفسیات',
    'Cough': 'کھانسی',
    'Fever': 'بخار',
    'Headache': 'سر درد',
    'Chest Pain': 'سینے میں درد',
    'Back Pain': 'کمر درد',
    'Dashboard': 'ڈیش بورڈ',
    'Book Appointment': 'اپائنٹمنٹ بُک کریں',
    'Upcoming Appointments': 'آنے والی اپائنٹمنٹس',
    'Appointment History': 'اپائنٹمنٹ ہسٹری',
    'My Prescriptions': 'میرے نسخے',
    'Chats': 'چیٹس',
    'Nearby Map': 'قریبی نقشہ',
    'Notifications': 'نوٹیفکیشنز',
    'Search Results': 'تلاش کے نتائج',
    'Doctors matching': 'مطابقت رکھنے والے ڈاکٹرز',
    'Top Doctors': 'نمایاں ڈاکٹرز',
    'Approved doctors matching your search and symptoms':
        'آپ کی تلاش اور علامات سے مطابقت رکھنے والے منظور شدہ ڈاکٹرز',
    'Unable to load doctors right now.': 'اس وقت ڈاکٹرز لوڈ نہیں ہو سکے۔',
    'No doctors match your filters':
        'آپ کے فلٹرز سے کوئی ڈاکٹر مطابقت نہیں رکھتا',
    'Search is unavailable right now.': 'اس وقت تلاش دستیاب نہیں ہے۔',
    'No doctors found for this search.': 'اس تلاش کے لیے کوئی ڈاکٹر نہیں ملا۔',
    'Could not send password reset email.':
        'پاس ورڈ ری سیٹ ای میل نہیں بھیجی جا سکی۔',
    'No account found for this email.':
        'اس ای میل کے لیے کوئی اکاؤنٹ نہیں ملا۔',
    'Could not verify email. Please try again.':
        'ای میل کی تصدیق نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔',
    'Something went wrong. Please try again.':
        'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔',
    'Email verification is blocked by Firestore permissions. Please contact support.':
        'فائر اسٹور اجازتوں کی وجہ سے ای میل کی تصدیق ممکن نہیں۔ براہ کرم سپورٹ سے رابطہ کریں۔',
    'Please verify your email before logging in. We sent a verification link too.':
        'براہ کرم لاگ ان سے پہلے اپنی ای میل کی تصدیق کریں۔ ہم نے ایک تصدیقی لنک بھی بھیج دیا ہے۔',
    'Verification email sent. Please check your inbox.':
        'تصدیقی ای میل بھیج دی گئی ہے۔ براہ کرم اپنا ان باکس چیک کریں۔',
    'Your account was created. Please verify your email before logging in.':
        'آپ کا اکاؤنٹ بن گیا ہے۔ براہ کرم لاگ ان سے پہلے اپنی ای میل کی تصدیق کریں۔',
    'Forgot Password?': 'پاس ورڈ بھول گئے؟',
    'Forgot Password': 'پاس ورڈ بھول گئے',
    'Enter your email': 'اپنی ای میل درج کریں',
    'Send Reset Link': 'ری سیٹ لنک بھیجیں',
    'Back to Login': 'لاگ ان پر واپس جائیں',
    'Invalid email format': 'ای میل فارمیٹ درست نہیں ہے',
    'Could not load doctors right now.': 'اس وقت ڈاکٹرز لوڈ نہیں ہو سکے۔',
    'Password updated successfully.': 'پاس ورڈ کامیابی سے اپ ڈیٹ ہو گیا۔',
    'No email address found for this account.':
        'اس اکاؤنٹ کے لیے ای میل ایڈریس نہیں ملا۔',
    'Could not change password.': 'پاس ورڈ تبدیل نہیں ہو سکا۔',
    'No email found for this account.': 'اس اکاؤنٹ کے لیے ای میل نہیں ملی۔',
    'Password reset email sent to': 'پاس ورڈ ری سیٹ ای میل بھیج دی گئی:',
    'If an account exists for this email, a reset link has been sent.':
        'اگر اس ای میل کے لیے اکاؤنٹ موجود ہے تو ری سیٹ لنک بھیج دیا گیا ہے۔',
    'Doctor Details': 'ڈاکٹر کی تفصیل',
    'About Doctor': 'ڈاکٹر کے بارے میں',
    'Consultation Availability': 'مشاورت کی دستیابی',
    'Schedule not available yet.': 'شیڈول ابھی دستیاب نہیں ہے۔',
    'Time': 'وقت',
    'Postponed Appointment': 'ملتوی شدہ اپائنٹمنٹ',
    'Your doctor postponed an appointment day.':
        'آپ کے ڈاکٹر نے اپائنٹمنٹ کا دن ملتوی کر دیا ہے۔',
    'Original date': 'اصل تاریخ',
    'Slot': 'وقت کا خانہ',
    'Status': 'حالت',
    'Decline / Cancel': 'رد کریں / منسوخ کریں',
    'Accept next day': 'اگلا دن قبول کریں',
    'Prescription Details': 'نسخے کی تفصیل',
    'Prescription for': 'نسخہ برائے',
    'Diagnosis': 'تشخیص',
    'Medicines': 'ادویات',
    'No medicines listed.': 'کوئی دوا درج نہیں۔',
    'Unnamed medicine': 'بے نام دوا',
    'Doctor Advice': 'ڈاکٹر کا مشورہ',
    'No advice': 'کوئی مشورہ نہیں',
    'Download PDF': 'پی ڈی ایف ڈاؤن لوڈ کریں',
    'Downloading...': 'ڈاؤن لوڈ ہو رہا ہے...',
    'Date': 'تاریخ',
    'Follow up': 'فالو اپ',
    'Today': 'آج',
    'Yesterday': 'گزشتہ روز',
    'Tomorrow': 'کل',
    'In': 'میں',
    'days': 'دن',
    'days ago': 'دن پہلے',
    'Upcoming': 'آنے والا',
    'Cancel Appointment': 'اپائنٹمنٹ منسوخ کریں',
    'Are you sure you want to cancel this appointment?':
        'کیا آپ واقعی یہ اپائنٹمنٹ منسوخ کرنا چاہتے ہیں؟',
    'No': 'نہیں',
    'Yes': 'ہاں',
    'Cancel': 'منسوخ کریں',
    'Cancelling...': 'منسوخ کیا جا رہا ہے...',
    'Chat': 'چیٹ',
    'No past appointments': 'گزشتہ اپائنٹمنٹس موجود نہیں',
    'Completed and cancelled visits will appear here.':
        'مکمل اور منسوخ شدہ وزٹس یہاں ظاہر ہوں گے۔',
    'View Upcoming': 'آنے والی دیکھیں',
    'Unable to load appointment history right now.':
        'اس وقت اپائنٹمنٹ ہسٹری لوڈ نہیں ہو سکی۔',
    'No upcoming appointments': 'کوئی آنے والی اپائنٹمنٹ نہیں',
    'Book your next consultation to see it here.':
        'یہاں دیکھنے کے لئے اپنی اگلی مشاورت بُک کریں۔',
    'Unable to load upcoming appointments right now.':
        'اس وقت آنے والی اپائنٹمنٹس لوڈ نہیں ہو سکیں۔',
    'Please select doctor, date and slot':
        'براہ کرم ڈاکٹر، تاریخ اور وقت کا خانہ منتخب کریں',
    'Please log in again.': 'براہ کرم دوبارہ لاگ ان کریں۔',
    'Appointment requested successfully.':
        'اپائنٹمنٹ کی درخواست کامیابی سے بھیج دی گئی۔',
    'Slot already taken. Please choose another.':
        'یہ وقت پہلے سے لیا جا چکا ہے۔ براہ کرم دوسرا منتخب کریں۔',
    '1. Select Doctor': '1. ڈاکٹر منتخب کریں',
    '2. Select Date & Slot': '2. تاریخ اور وقت کا خانہ منتخب کریں',
    '3. Symptoms & Notes': '3. علامات اور نوٹس',
    'Select a doctor first': 'پہلے ڈاکٹر منتخب کریں',
    'Select a date': 'تاریخ منتخب کریں',
    'No slots available for the selected date.':
        'منتخب تاریخ کے لیے کوئی وقت دستیاب نہیں۔',
    'This doctor has not added availability yet. Please try another doctor.':
        'اس ڈاکٹر نے ابھی دستیابی شامل نہیں کی۔ براہ کرم دوسرا ڈاکٹر آزمائیں۔',
    'is not in this doctor\'s working days.':
        'اس ڈاکٹر کے کام کے دنوں میں شامل نہیں ہے۔',
    'Pick a doctor, choose a time slot, and submit your request in seconds.':
        'ڈاکٹر منتخب کریں، وقت کا خانہ چنیں، اور چند لمحوں میں درخواست جمع کریں۔',
    'Book Your Consultation': 'اپنی مشاورت بُک کریں',
    'Choose a date': 'تاریخ منتخب کریں',
    'Booking...': 'بکنگ ہو رہی ہے...',
    'Confirm Appointment': 'اپائنٹمنٹ کی تصدیق کریں',
    'Search FAQs or topics': 'اکثر سوالات یا موضوعات تلاش کریں',
    'Quick Actions': 'فوری اقدامات',
    'Book an appointment': 'ایک اپائنٹمنٹ بُک کریں',
    'Go directly to the booking flow.': 'براہ راست بکنگ کے عمل پر جائیں۔',
    'View prescriptions': 'نسخے دیکھیں',
    'Open your saved prescriptions.': 'اپنے محفوظ نسخے کھولیں۔',
    'Update account and notification preferences.':
        'اکاؤنٹ اور نوٹیفکیشن ترجیحات اپ ڈیٹ کریں۔',
    'Frequently Asked Questions': 'اکثر پوچھے جانے والے سوالات',
    'Send a Support Request': 'مدد کی درخواست بھیجیں',
    'Contact Support': 'مدد سے رابطہ کریں',
    'Emergency Notice': 'ہنگامی اطلاع',
    'Sending...': 'بھیجا جا رہا ہے...',
    'Send Request': 'درخواست بھیجیں',
    'Your support request has been sent.':
        'آپ کی مدد کی درخواست بھیج دی گئی ہے۔',
    'Could not send your request right now.':
        'اس وقت آپ کی درخواست نہیں بھیجی جا سکی۔',
    'copied to clipboard.': 'کلپ بورڈ میں کاپی کر لیا گیا۔',
    'No FAQ matches your search. Try a different keyword or send a support request below.':
        'آپ کی تلاش سے کوئی سوال نہیں ملا۔ کوئی اور لفظ آزمائیں یا نیچے مدد کی درخواست بھیجیں۔',
    'Name': 'نام',
    'Email': 'ای میل',
    'Category': 'زمرہ',
    'Subject': 'موضوع',
    'Describe your issue': 'اپنا مسئلہ بیان کریں',
    'Enter a subject': 'موضوع درج کریں',
    'Please enter a message': 'براہ کرم پیغام درج کریں',
    'Please provide a little more detail': 'براہ کرم تھوڑی مزید تفصیل دیں',
    'Copy': 'کاپی',
    'Hours': 'اوقات',
    'AidLink support is for app-related issues only. For urgent medical emergencies, contact local emergency services immediately.':
        'AidLink مدد صرف ایپ سے متعلق مسائل کے لیے ہے۔ فوری طبی ہنگامی صورت میں فوراً مقامی ایمرجنسی سروس سے رابطہ کریں۔',
    'We are here to help': 'ہم مدد کے لیے حاضر ہیں',
    'Search answers, contact support, or send a request right from the app.':
        'جوابات تلاش کریں، مدد سے رابطہ کریں، یا ایپ سے براہ راست درخواست بھیجیں۔',
    '24h response target': '24 گھنٹے جواب کا ہدف',
    'Secure support requests': 'محفوظ مدد کی درخواستیں',
    'Human support team': 'انسانی مدد ٹیم',
    'Appointments': 'اپائنٹمنٹس',
    'Prescriptions': 'نسخے',
    'Technical': 'تکنیکی',
    'Other': 'دیگر',
    'How do I book an appointment?': 'میں اپائنٹمنٹ کیسے بُک کروں؟',
    'Open the dashboard, choose a doctor, and tap Book Appointment.':
        'ڈیش بورڈ کھولیں، ڈاکٹر منتخب کریں، اور اپائنٹمنٹ بُک کریں دبائیں۔',
    'Can I cancel an appointment?': 'کیا میں اپائنٹمنٹ منسوخ کر سکتا ہوں؟',
    'Yes. Open Upcoming Appointments and tap Cancel on the card.':
        'جی ہاں۔ آنے والی اپائنٹمنٹس کھولیں اور کارڈ پر منسوخ کریں دبائیں۔',
    'Where are my prescriptions?': 'میرے نسخے کہاں ہیں؟',
    'Go to My Prescriptions to view the full prescription history.':
        'مکمل نسخہ ہسٹری دیکھنے کے لئے میرے نسخے میں جائیں۔',
    'How do I update my details?': 'میں اپنی تفصیلات کیسے اپ ڈیٹ کروں؟',
    'Open Settings to change your profile and notification options.':
        'اپنا پروفائل اور نوٹیفکیشن اختیارات بدلنے کے لئے ترتیبات کھولیں۔',
    'How do I reset my password?': 'میں اپنا پاس ورڈ کیسے ری سیٹ کروں؟',
    'Use Settings > Send password reset email or Change password.':
        'ترتیبات > پاس ورڈ ری سیٹ ای میل بھیجیں یا پاس ورڈ تبدیل کریں استعمال کریں۔',
    'The app is behaving strangely. What should I do?':
        'ایپ غیر معمولی برتاؤ کر رہی ہے۔ مجھے کیا کرنا چاہیے؟',
    'Try signing out and back in, then send a support request below.':
        'لاگ آؤٹ کر کے دوبارہ لاگ اِن کریں، پھر نیچے مدد کی درخواست بھیجیں۔',
    'OPEN': 'کھولیں',
    'Prescription PDF': 'نسخہ پی ڈی ایف',
    'Prescription PDF downloaded.': 'نسخے کی پی ڈی ایف ڈاؤن لوڈ ہو گئی۔',
    'Could not download PDF.': 'پی ڈی ایف ڈاؤن لوڈ نہیں ہو سکی۔',
    'Unable to load slots due to permissions. Please try again in a moment.':
        'اجازت کے مسئلے کی وجہ سے سلاٹس لوڈ نہیں ہو سکے۔ براہ کرم تھوڑی دیر میں دوبارہ کوشش کریں۔',
    'Unable to load slots right now. Please try again.':
        'اس وقت سلاٹس لوڈ نہیں ہو سکے۔ براہ کرم دوبارہ کوشش کریں۔',
    'Booking is blocked by Firestore permissions. Please contact support.':
        'Firestore اجازتوں کی وجہ سے بکنگ رکی ہوئی ہے۔ براہ کرم مدد سے رابطہ کریں۔',
    'Unable to book right now. Please try another slot.':
        'اس وقت بکنگ ممکن نہیں۔ براہ کرم دوسرا سلاٹ آزمائیں۔',
    'Dr.': 'ڈاکٹر',
    'General': 'جنرل',
    'Logout': 'لاگ آؤٹ',
    'Add any details for the doctor...':
        'ڈاکٹر کے لیے کوئی بھی تفصیل شامل کریں...',
    'AidLink': 'ایڈلنک',
    'Appointment cancelled successfully.': 'اپائنٹمنٹ کامیابی سے منسوخ ہو گئی۔',
    'Could not cancel appointment right now.':
        'اس وقت اپائنٹمنٹ منسوخ نہیں ہو سکی۔',
    'No chats found': 'کوئی چیٹ نہیں ملی',
    'No diagnosis provided': 'کوئی تشخیص فراہم نہیں کی گئی',
    'No prescriptions available': 'کوئی نسخہ دستیاب نہیں',
    'Specialist': 'ماہر',
    'Type a message...': 'پیغام لکھیں...',
    'Unable to load prescriptions right now.': 'اس وقت نسخے لوڈ نہیں ہو سکے۔',
    'User not logged in': 'صارف لاگ اِن نہیں ہے',
    'View': 'دیکھیں',
    'Patient current position: \$pos': 'مریض کی موجودہ پوزیشن: \$pos',
    'Error while resolving current position: \$e':
        'موجودہ پوزیشن معلوم کرتے وقت خرابی: \$e',
    'Error while loading nearby providers: \$e':
        'قریبی فراہم کنندگان لوڈ کرتے وقت خرابی: \$e',
    'Clinics fetch failed (continuing with doctors only): \$e':
        'کلینکس حاصل نہ ہو سکے (صرف ڈاکٹرز کے ساتھ جاری): \$e',
  };

  static String of(BuildContext context, String english) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ur') {
      return _ur[english] ?? english;
    }
    return english;
  }
}
