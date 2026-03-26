# Google Play Console - Data Safety Form Answers

Based on your app's architecture (LearnED flutter app with Supabase, auth, material uploads, and payments), here is a simple guide on exactly how to answer the Data Safety questionnaire in the Google Play Console.

## 1. Data Collection and Security
*   **Does your app collect or share any of the required user data types?**
    *   **Answer:** Yes
*   **Is all of the user data collected by your app encrypted in transit?** 
    *   **Answer:** Yes (Supabase and standard HTTPS connections handle this).
*   **Which of the following methods of account creation does your app support?**
    *   **Answer:** Username and password (and/or OAuth if you use Google/Apple sign-in via Supabase).

## 2. Data Deletion
*   **Do you provide a way for users to request that their data is deleted?**
    *   **Answer:** Yes
*   **Add a link that users can use to request that their account and associated data be deleted:**
    *   **Answer:** `https://learnedtech.in/delete-account`

## 3. Data Types Collected
Here are the specific data types you should declare based on your app's features (classrooms, payments, material uploads):

### Personal Info
*   **Name:** Collected -> Yes. Shared -> No. 
    *   *Purpose:* App Functionality, Account Management.
*   **Email address:** Collected -> Yes. Shared -> No.
    *   *Purpose:* App Functionality, Account Management, Developer Communications.
*   **User IDs:** Collected -> Yes. Shared -> No.
    *   *Purpose:* App Functionality, Account Management.

### Financial Info
*   **Purchase history** (Due to your Payment System): Collected -> Yes. Shared -> No (unless shared with external non-payment-processor 3rd parties).
    *   *Purpose:* App Functionality.

### Files and Docs
*   **Files and docs** (Due to your Learning Materials Uploads): Collected -> Yes. Shared -> No.
    *   *Purpose:* App Functionality.

### App Info and Performance
*   **Crash logs & Diagnostics:** Collected -> Yes (if you use Firebase Crashlytics, Sentry, or similar). Shared -> No.
    *   *Purpose:* Analytics, Developer Communications.

### App Activity
*   **App interactions:** Collected -> Yes. Shared -> No.
    *   *Purpose:* Analytics (if you track views/clicks).

---

### How to use this:
You can either fill out the web form in the Google Play Console manually using the answers above, or if you prefer to upload the CSV directly to the console, let me know and I can update your `data_safety_export.csv` with these exact true/false flags.