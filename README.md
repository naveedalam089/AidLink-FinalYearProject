AidLink — Hybrid Healthcare Platform

AidLink is a hybrid healthcare mobile application built with Flutter and Firebase, designed to connect patients and doctors through a seamless, secure, and user-friendly platform. This repository contains the complete and final version of the project as submitted in the FYP Report, developed at COMSATS University Islamabad, Abbottabad Campus, and successfully defended before an external evaluation committee.

Project Team
Naveed Alam
Moazzam Ali

Supervisor: Ms. Sadaf Riaz

Features
Doctor Discovery — Search and view doctor profiles, with location-based discovery using OpenStreetMap and geolocation services.
Appointment Booking — Patients can book appointments directly through the app.
Encrypted Chat — Real-time, in-app encrypted messaging between doctors and patients for secure consultation.
Reviews & Ratings — Patients can rate doctors and leave feedback after appointments.
Push Notifications — Real-time updates via Firebase Cloud Messaging and local notifications.
Reports & Sharing — Generate and share PDF reports, with file picking and printing support.
Data Visualization — Interactive charts for health/appointment data using fl_chart.
Tech Stack
Frontend: Flutter (Dart SDK ^3.10.0)
Backend: Firebase (Authentication, Firestore, Cloud Storage, Cloud Messaging)
Maps & Location: flutter_map, latlong2, geolocator
Dependencies / Libraries

Environment

Dart SDK: ^3.10.0

Core Dependencies

firebase_core: ^4.5.0
cloud_firestore: ^6.1.3
firebase_auth: ^6.2.0
firebase_messaging: ^16.2.0
firebase_storage: ^13.1.0
flutter_map: ^7.0.2
latlong2: ^0.9.1
geolocator: ^12.0.0
flutter_local_notifications: ^21.0.0
fl_chart: ^0.65.0
smooth_page_indicator: ^1.0.0
lottie: ^2.6.0
cupertino_icons: ^1.0.8
file_picker: ^8.0.0
share_plus: ^10.0.0
path_provider: ^2.1.0
pdf: ^3.11.1
printing: ^5.13.4
shared_preferences: ^2.3.2
http: ^1.6.0
url_launcher: ^6.3.1
flutter_svg: ^2.0.0
intl: ^0.20.2

Dev Dependencies

flutter_test (Flutter SDK)
table_calendar: ^3.0.9
flutter_lints: ^6.0.0
Database / Backend

This project uses Firebase Firestore as its database (NoSQL, cloud-hosted). No separate database installation is required — data is managed entirely through Firebase.

Configuration Files Required
google-services.json (for Android) — placed in android/app/
GoogleService-Info.plist (for iOS) — placed in ios/Runner/

Note: These files contain sensitive credentials and are not included in the repository. Reviewers should generate their own Firebase project (with Authentication, Firestore, Storage, and Cloud Messaging enabled) to run the app, or contact the project team for test credentials.

Setup, Installation, and Run Instructions
Clone the repository:
git clone https://github.com/naveedalam089/AidLink-FinalYearProject.git
Navigate to the project directory:
cd AidLink-FinalYearProject
Install Flutter dependencies:
flutter pub get
Set up Firebase:
Create a Firebase project at firebase.google.com
Enable Authentication, Firestore, Cloud Storage, and Cloud Messaging
Download and add google-services.json (Android) and/or GoogleService-Info.plist (iOS) to the appropriate folders
Run the app:
flutter run

Documentation

Full project documentation, including system design, use case diagrams, and detailed feature descriptions, is available in the submitted FYP Report.

License

This project was developed for academic purposes as part of a Final Year Project at COMSATS University Islamabad.
