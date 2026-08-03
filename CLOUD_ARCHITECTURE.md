# FinPulse Cloud Architecture & App Overview

FinPulse is a privacy-first, intelligent personal finance tracker built to empower users with behavioral insights while maintaining absolute control over their sensitive financial data.

## 1. App Ecosystem Overview

FinPulse bridges the gap between automated tracking and manual budgeting by leveraging on-device SMS parsing and local analytics.

*   **Primary Platform**: Flutter (Cross-platform support for Android, iOS, and Desktop).
*   **Key Value Proposition**: Real-time financial health monitoring without sacrificing privacy to the cloud.

---

## 2. Cloud Architecture

While FinPulse is "local-first," it utilizes cloud services to provide a seamless multi-device experience and secure identity management.

### A. Authentication (Firebase Auth)
The identity layer is powered by **Firebase Authentication**, providing a secure and scalable way to manage user sessions.
- **Methods**: Google Sign-In and Email/Password.
- **Purpose**: Identity resolution for cloud sync and secure account recovery.

### B. Cloud Database (Google Cloud Firestore)
Firestore acts as a **Selective Sync Layer**. Unlike traditional apps that upload every transaction, FinPulse only syncs high-level aggregated data.
- **Document Path**: `users/{uid}`
- **Synced Entities**:
    - **User Profile**: Age, Gender, and Basic Info.
    - **Health Scores**: Aggregated `financialHealthScore`.
    - **Behavioral Insights**: `impulseScore` and `savingConsistencyScore`.
    - **Metadata**: Timestamps of the last synchronization.

### C. Sync Strategy: "Local-First, Insight-Cloud"
1.  **Persistence**: Raw financial data (Transactions, SMS details, specific Goals) is stored **locally** in an encrypted SQLite database.
2.  **Aggregation**: The `ScoreService` and `ImpulseAnalysisService` process raw data into scores on the device.
3.  **Synchronization**: The `FirestoreUserService` upserts these scores to the cloud. This ensures that even if a device is lost, the user’s overall financial profile and progress are preserved without ever exposing their raw transaction history to the cloud.

---

## 3. Key Technical Features

### Live SMS Intelligence
- **Platform Channels**: Uses Android platform channels to capture incoming SMS messages in real-time.
- **Regex-Based Parsing**: Robust parsing engine identifies merchant names and amounts from diverse bank SMS formats.
- **Auto-Categorization**: Merchant-to-Category mapping (e.g., *Swiggy* → *Food*) using local heuristics.

### Behavioral Analytics Engine
FinPulse goes beyond tracking numbers by calculating psychological financial metrics:
- **Impulse Score**: Analyzes spending patterns (e.g., weekend vs. weekday) to identify potential impulsive behavior.
- **Savings Consistency**: Uses Holt’s linear trend forecasting to predict future savings and score consistency.
- **Health Gauge**: A weighted scoring system (Savings Ratio, Diversity, Budget Adherence) provided in a real-time visual gauge.

---

## 4. Privacy & Security Architecture

1.  **On-Device Processing**: 100% of the PII (Personally Identifiable Information) in financial SMS is processed and discarded after storage in the local SQLite DB.
2.  **No-Op on Desktop**: Cloud sync is intentionally disabled on Desktop platforms (Linux/Windows/macOS) To ensure maximum privacy for desktop users where identity persistence is less critical.
3.  **Non-Destructive Upserts**: Firestore updates use `SetOptions(merge: true)` to ensure data integrity and prevent accidental overwrites during concurrent device syncs.

---

> [!IMPORTANT]
> **Data Sovereignity**: FinPulse operates on the principle that the user owns their raw data. The cloud layer is purely for metadata preservation and cross-device insight continuity.
