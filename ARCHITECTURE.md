# FinPulse — Backend Logic & Architecture

> A personal finance tracker built with Flutter, Firebase Auth, and on-device SQLite persistence. All financial data stays on the user's device — nothing is synced to the cloud.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Project Structure](#project-structure)
3. [App Lifecycle & Entry Point](#app-lifecycle--entry-point)
4. [Authentication Layer](#authentication-layer)
5. [Data Layer](#data-layer)
   - [SQLite Database](#sqlite-database)
   - [Data Models](#data-models)
   - [Database Helper — Full API Reference](#database-helper--full-api-reference)
6. [Service Layer](#service-layer)
   - [Financial Health Score](#financial-health-score)
   - [SMS Transaction Parser](#sms-transaction-parser)
7. [Feature Modules](#feature-modules)
   - [Dashboard](#dashboard)
   - [Transaction History](#transaction-history)
   - [Add Transaction](#add-transaction)
   - [Goals](#goals)
   - [Insights](#insights)
   - [Settings & Preferences](#settings--preferences)
8. [Data Flow Diagrams](#data-flow-diagrams)
9. [State Management Pattern](#state-management-pattern)
10. [Database Schema](#database-schema)
11. [Dependencies](#dependencies)

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Flutter UI                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────┐ │
│  │Dashboard │ │ History  │ │ Insights │ │ Goals  │ │ More │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ └──┬───┘ │
│       │            │            │            │         │     │
│  ─────┴────────────┴────────────┴────────────┴─────────┴──── │
│                     Service Layer                            │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │  ScoreService    │  │   SMSService     │                  │
│  │  (score calc)    │  │  (SMS parsing)   │                  │
│  └────────┬─────────┘  └────────┬─────────┘                  │
│           │                     │                            │
│  ─────────┴─────────────────────┴──────────────────────────── │
│                     Data Layer                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              DatabaseHelper (Singleton)                   │ │
│  │  ┌─────────────────┐     ┌──────────────────┐            │ │
│  │  │  transactions   │     │     goals         │            │ │
│  │  │  (SQLite table) │     │  (SQLite table)   │            │ │
│  │  └─────────────────┘     └──────────────────┘            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              SharedPreferences                            │ │
│  │  (toggle states: sms_sync, notifications, biometrics,     │ │
│  │   dark_mode)                                              │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Firebase Auth                                │ │
│  │  (Email/Password + Google Sign-In)                        │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**Key principle**: Firebase handles authentication only. All financial data (transactions, goals, scores) is stored **on-device** in SQLite via the `sqflite` package. User preferences are persisted in `SharedPreferences`.

---

## Project Structure

```
lib/
├── main.dart                          # App entry point, Firebase init
├── app.dart                           # MaterialApp config
│
├── core/
│   ├── constants/colors.dart          # App-wide color constants
│   └── theme/app_theme.dart           # ThemeData configuration
│
├── data/
│   ├── local/
│   │   └── database_helper.dart       # SQLite singleton — all DB operations
│   ├── models/
│   │   ├── transaction_model.dart     # Transaction data class
│   │   └── goal_model.dart            # Goal data class
│   └── services/
│       ├── score_service.dart         # Financial health score calculator
│       └── sms_service.dart           # SMS transaction auto-parser
│
├── features/
│   ├── auth/
│   │   ├── auth_service.dart          # Firebase Auth abstraction
│   │   ├── auth_wrapper.dart          # StreamBuilder gate (logged in vs out)
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   │
│   ├── navigation/
│   │   └── main_navigation_screen.dart  # Bottom nav + IndexedStack
│   │
│   ├── dashboard/
│   │   ├── dashboard_screen.dart        # Main dashboard (fetches all data)
│   │   └── widgets/
│   │       ├── score_gauge.dart          # Animated health score arc
│   │       ├── income_expense_card.dart  # Income/expense with change %
│   │       ├── spending_trend_card.dart  # 4-week bar chart
│   │       ├── category_card.dart        # Category breakdown (week/month)
│   │       └── recent_transactions_section.dart  # Last 5 transactions
│   │
│   ├── transactions/
│   │   └── screens/
│   │       ├── add_transaction_screen.dart       # Manual entry form
│   │       ├── daywise_transactions_screen.dart  # Day/Week/Month tabs
│   │       ├── weekwise_transactions_screen.dart
│   │       └── monthly_history_screen.dart
│   │
│   ├── goals/
│   │   └── goals_screen.dart           # Savings goals CRUD
│   │
│   ├── insights/
│   │   └── insights_screen.dart        # Analytics (pie chart, behavior)
│   │
│   ├── settings/
│   │   └── settings_screen.dart        # Preferences + clear data
│   │
│   ├── profile/
│   │   └── screens/profile_screen.dart
│   │
│   ├── notifications/
│   │   └── notification_screen.dart
│   │
│   └── onboarding/
│       └── onboarding_screen.dart
```

---

## App Lifecycle & Entry Point

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FinPulseApp());
}
```

**Boot sequence:**

1. **`main()`** → Initialize Flutter bindings, then Firebase.
2. **`FinPulseApp`** → `MaterialApp` with dark theme, routes to `AuthWrapper`.
3. **`AuthWrapper`** → Listens to `FirebaseAuth.authStateChanges()` stream:
   - `ConnectionState.waiting` → shows loading spinner
   - `snapshot.hasData` (user logged in) → shows `MainNavigationScreen`
   - No data → shows `LoginScreen`
4. **`MainNavigationScreen`** → `IndexedStack` with 5 tabs: Dashboard, History, Insights, Goals, Profile. Floating action button opens `AddTransactionScreen`.

> **Persistent login** is handled natively by Firebase Auth on mobile — the SDK caches the auth token on disk, so users stay logged in across app restarts without any custom `SharedPreferences` logic.

---

## Authentication Layer

### AuthService (`features/auth/auth_service.dart`)

Wraps `FirebaseAuth` and `GoogleSignIn` into a clean API:

| Method | Description |
|--------|------------|
| `signInWithEmail(email, password)` | Email/password login, returns `UserCredential` |
| `signUpWithEmail(email, password)` | Email/password registration |
| `signInWithGoogle()` | Google OAuth flow (cancellable) |
| `signOut()` | Signs out of both Firebase + Google simultaneously |
| `authStateChanges` | `Stream<User?>` for reactive UI updates |
| `currentUser` | Synchronous getter for the current Firebase user |

**Error handling**: `_mapFirebaseError()` converts Firebase error codes into user-friendly strings:

```
user-not-found     → "No account found for this email."
wrong-password     → "Incorrect password."
email-already-in-use → "Email is already registered."
weak-password      → "Password is too weak."
network-request-failed → "Network error. Check your connection."
```

### AuthWrapper (`features/auth/auth_wrapper.dart`)

A `StreamBuilder<User?>` that reactively switches between `LoginScreen` and `MainNavigationScreen` based on auth state. No manual navigation required — the stream handles login/logout transitions automatically.

---

## Data Layer

### SQLite Database

**Package**: `sqflite` (on-device SQLite)  
**Database name**: `finpulse.db`  
**Current version**: `2`  
**Pattern**: Singleton via `DatabaseHelper.instance`

The database is created lazily on first access. Schema versioning ensures smooth upgrades:

```dart
static DatabaseHelper get instance => _instance;

Future<Database> get database async {
  _database ??= await _initDB('finpulse.db');
  return _database!;
}
```

#### Schema Migration (v1 → v2)

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
    await db.execute('CREATE TABLE IF NOT EXISTS goals (...)');
  }
}
```

### Data Models

#### TransactionModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | `int?` | Auto-incremented primary key |
| `smsId` | `String?` | Unique SMS identifier (prevents duplicates) |
| `amount` | `double` | Transaction amount in ₹ |
| `merchant` | `String` | Merchant/payee name |
| `category` | `String` | Category label (Food, Transport, etc.) |
| `type` | `String` | `"Credit"` or `"Debit"` |
| `timestamp` | `String` | ISO 8601 datetime string |
| `notes` | `String?` | Optional user notes |

**Serialization**: `toMap()` / `fromMap()` for SQLite read/write.

#### GoalModel

| Field | Type | Description |
|-------|------|-------------|
| `id` | `int?` | Auto-incremented primary key |
| `title` | `String` | Goal name (e.g., "New Laptop") |
| `iconIndex` | `int` | Index into a predefined icon list |
| `colorValue` | `int` | ARGB color integer (e.g., `0xFF3B82F6`) |
| `target` | `double` | Target amount in ₹ |
| `saved` | `double` | Amount saved so far |
| `createdAt` | `String` | ISO 8601 creation timestamp |

**Serialization**: `toMap()` / `fromMap()` / `copyWith()` for immutable updates.

### Database Helper — Full API Reference

All methods are accessed via `DatabaseHelper.instance`:

#### Transaction Operations

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `insertTransaction` | `TransactionModel` | `int` (row ID) | Insert a new transaction |
| `getAllTransactions` | — | `List<TransactionModel>` | All transactions, newest first |
| `getTransactionsByDateRange` | `start`, `end` (ISO strings) | `List<TransactionModel>` | Filter by date range |
| `getTransactionsByType` | `type` (`"Credit"` / `"Debit"`) | `List<TransactionModel>` | Filter by type |
| `getTransactionsByCategory` | `category` | `List<TransactionModel>` | Filter by category |
| `getRecentTransactions` | `limit` (default 5) | `List<TransactionModel>` | Most recent N transactions |
| `deleteTransaction` | `id` | `int` | Delete by ID |
| `getTransactionCount` | — | `int` | Total row count |

#### Aggregation & Analytics

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `getIncomeExpense` | `start`, `end` | `Map<String, double>` (`income`, `expense`) | Sum of credits vs debits in range |
| `getCategorySums` | `start`, `end` | `List<Map>` (`category`, `total`) | Expense totals per category, sorted desc |
| `getMonthlyTotals` | `months` (default 6) | `List<Map>` (`month`, `total`) | Monthly expense totals for trend charts |
| `getWeeklySpending` | `weeks` (default 4) | `List<double>` | Total spending per week (most recent N weeks) |
| `getWeekendVsTotal` | `start`, `end` | `Map<String, double>` (`weekend`, `total`) | Weekend debit spending vs all debit spending |

#### Goal Operations

| Method | Returns | Description |
|--------|---------|-------------|
| `insertGoal(GoalModel)` | `int` | Insert new goal |
| `getAllGoals()` | `List<GoalModel>` | All goals, newest first |
| `updateGoal(GoalModel)` | `int` | Update existing goal |
| `deleteGoal(int id)` | `int` | Delete goal by ID |

#### Utility

| Method | Description |
|--------|-------------|
| `clearAll()` | Deletes all rows from `transactions` and `goals` tables |

---

## Service Layer

### Financial Health Score

**File**: `data/services/score_service.dart`

Computes a **0–100 score** based on the user's transaction history over the last 90 days.

#### Formula

```
score = savingsRatio × 30
      + categoryDiversity × 15
      + budgetAdherence × 25
      + consistency × 15
      + lowImpulse × 15
```

#### Component Breakdown

| Component | Weight | Metric | Range | How It's Calculated |
|-----------|--------|--------|-------|---------------------|
| **Savings Ratio** | 30% | `(income − expense) / income` | 0.0 – 1.0 | Higher savings → higher score. If income = 0, score = 0. |
| **Category Diversity** | 15% | `uniqueCategories / 6` | 0.0 – 1.0 | Tracks how many distinct expense categories exist. Capped at 6. More categories = more diversified spending = higher score. |
| **Budget Adherence** | 25% | Penalty if expense > 70% of income | 0.0 – 1.0 | If expense ≤ 70% of income → score = 1.0. Otherwise, penalized proportionally up to 100%. |
| **Consistency** | 15% | Monthly variance from average | 0.0 – 1.0 | Counts how many months (out of last 6) have spending within ±15% of the average. Consistent spending = higher score. |
| **Low Impulse** | 15% | `1 − (weekendSpending / totalSpending)` | 0.0 – 1.0 | Less weekend spending (proxy for impulse buying) = higher score. |

#### Labels & Colors

| Score Range | Label | Color |
|-------------|-------|-------|
| 80 – 100 | Excellent | Green (#22C55E) |
| 60 – 79 | Good | Blue (#3B82F6) |
| 40 – 59 | Average | Orange (#FF8A34) |
| 20 – 39 | Poor | Red-Orange (#FF6B4A) |
| 0 – 19 | Critical | Red (#EF4444) |

#### Data Flow

```
ScoreService
  └─→ DatabaseHelper.getIncomeExpense(90 days)      → savings ratio
  └─→ DatabaseHelper.getCategorySums(90 days)        → diversity
  └─→ DatabaseHelper.getIncomeExpense(90 days)       → budget adherence
  └─→ DatabaseHelper.getMonthlyTotals(6)             → consistency
  └─→ DatabaseHelper.getWeekendVsTotal(90 days)      → impulse score
  └─→ Final score = weighted sum, clamped [0, 100]
```

### SMS Transaction Parser

**File**: `data/services/sms_service.dart`

Automatically detects and parses financial SMS messages from banks.

**Pipeline:**
1. **Permission check** → requests SMS read permission via `permission_handler`
2. **Fetch SMS** → uses a platform channel (`MethodChannel('sms_channel')`) to read device SMS
3. **Filter** → `_isTransactionMessage()` checks for financial keywords (`debited`, `credited`, `spent`, `received`, etc.)
4. **Extract** → Regex-based extraction of:
   - **Amount**: Patterns like `Rs.1,500.00`, `INR 2000`, `₹500`
   - **Merchant**: Text after `at`, `to`, `from` keywords
5. **Categorize** → `detectCategory()` maps merchant names to categories:
   - `Swiggy`, `Zomato` → **Food**
   - `Uber`, `Ola`, `fuel` → **Transport**
   - `Amazon`, `Flipkart` → **Shopping**
   - `Netflix`, `Spotify` → **Entertainment**
   - Credit transactions → **Income**
   - Default → **Other**
6. **Persist** → Creates a `TransactionModel` and calls `DatabaseHelper.insertTransaction()`

---

## Feature Modules

### Dashboard

**Screen**: `features/dashboard/dashboard_screen.dart` (StatefulWidget)

On `initState()`, fetches 7 data points in parallel using `Future.wait`:

```dart
final results = await Future.wait([
  _scoreService.calculateScore(),                    // → double (0-100)
  _db.getIncomeExpense(startOfMonth, endOfMonth),    // → {income, expense}
  _db.getIncomeExpense(prevMonthStart, prevMonthEnd),// → prev month (for %)
  _db.getWeeklySpending(4),                          // → List<double>
  _db.getCategorySums(weekStart, now),               // → weekly categories
  _db.getCategorySums(startOfMonth, now),            // → monthly categories
  _db.getRecentTransactions(5),                      // → latest 5 tx
]);
```

Each result feeds into a dedicated widget:

| Widget | Data Source | Display |
|--------|-----------|---------|
| `ScoreGauge` | `ScoreService.calculateScore()` | Animated arc gauge with label |
| `IncomeExpenseCard` | `getIncomeExpense()` × 2 months | Income/Expense with month-over-month ∆% |
| `SpendingTrendCard` | `getWeeklySpending(4)` | 4-bar chart with trend % |
| `CategoryCard` | `getCategorySums()` × 2 | Category icons + amounts (week/month toggle) |
| `RecentTransactionsSection` | `getRecentTransactions(5)` | Last 5 transactions with icons |

**Pull-to-refresh**: `RefreshIndicator` wrapping `SingleChildScrollView` calls `_loadData()`.

### Transaction History

**Screen**: `features/transactions/screens/daywise_transactions_screen.dart`

Three tabs (Day / Week / Month), all querying the database:

| Tab | Query | Display |
|-----|-------|---------|
| **Day** | `getTransactionsByDateRange(dayStart, dayEnd)` | List of transactions for selected date |
| **Week** | `getTransactionsByDateRange(weekStart, weekEnd)` | Transactions grouped by the selected week |
| **Month** | `getTransactionsByDateRange(monthStart, monthEnd)` | All transactions + category breakdown summary |

**Features:**
- **Date navigation**: Arrow buttons to go to previous/next day/week/month
- **Swipe-to-delete**: `Dismissible` widget calls `DatabaseHelper.deleteTransaction(id)`
- **Income/expense summary**: Aggregated totals shown at top of each period
- **Empty states**: Informative message when no transactions exist

### Add Transaction

**Screen**: `features/transactions/screens/add_transaction_screen.dart`

**Form fields:**

| Field | Input Type | Validation |
|-------|-----------|------------|
| Amount | `TextInputType.number` | Required, must be > 0 |
| Merchant | `TextInputType.text` | Required, non-empty |
| Category | Dropdown selector | 8 predefined categories |
| Type | Toggle (`Credit` / `Debit`) | Default: Debit |
| Date | DatePicker | Default: today |
| Notes | Optional text | No validation |

**Save logic:**
```dart
final tx = TransactionModel(
  amount: parsedAmount,
  merchant: merchantName,
  category: selectedCategory,
  type: selectedType,
  timestamp: selectedDate.toIso8601String(),
  notes: notesText.isEmpty ? null : notesText,
);
await DatabaseHelper.instance.insertTransaction(tx);
Navigator.pop(context, true);  // signals parent to refresh
```

### Goals

**Screen**: `features/goals/goals_screen.dart`

Full CRUD for savings goals:

| Action | UI | DB Method |
|--------|----|-----------|
| **Create** | Bottom sheet with name, target, saved, icon, color | `insertGoal(goal)` |
| **Read** | List with progress bars | `getAllGoals()` |
| **Update** | AlertDialog to edit saved amount | `updateGoal(goal.copyWith(saved: newAmount))` |
| **Delete** | Tap delete icon | `deleteGoal(id)` |

**Summary tiles** show total saved (₹) and active goal count.

### Insights

**Screen**: `features/insights/insights_screen.dart`

Three tabs using `TabController`:

| Tab | Content | Data Source |
|-----|---------|-------------|
| **Overview** | Income/Expense/Net summary + Pie chart by category | `getIncomeExpense()`, `getCategorySums()` |
| **Spending** | Top 5 categories (horizontal bars) + Recent debits list | `getCategorySums()`, `getTransactionsByType('Debit')` |
| **Psychology** | Behavioral insight cards | `getWeekendVsTotal()`, `getCategorySums()`, `getTransactionCount()` |

**Behavioral insights** (Psychology tab):

| Insight | Logic |
|---------|-------|
| Weekend Splurger | If weekend spending > 40% of total |
| Top Spending | Category with highest total |
| Daily Average | `total_expense / days_elapsed_in_month` |
| Transaction Count | Total entries with frequency commentary |

### Settings & Preferences

**Screen**: `features/settings/settings_screen.dart`

**Persistent toggles** (saved to `SharedPreferences`):

| Key | Default | Description |
|-----|---------|-------------|
| `sms_sync` | `true` | Auto-detect transactions from SMS |
| `notifications` | `true` | Push notification alerts |
| `biometrics` | `false` | Fingerprint unlock |
| `dark_mode` | `true` | App-wide dark theme |

**Clear All Data:**
```dart
onPressed: () async {
  await DatabaseHelper.instance.clearAll();  // deletes transactions + goals
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

---

## Data Flow Diagrams

### Adding a Transaction

```
User fills form
    │
    ▼
AddTransactionScreen._saveTransaction()
    │
    ├─→ Validates input
    ├─→ Creates TransactionModel
    ├─→ DatabaseHelper.insertTransaction(model)
    │       └─→ SQLite INSERT INTO transactions
    │
    ▼
Navigator.pop(context, true)
    │
    ▼
Parent screen detects `result == true`
    │
    ▼
Calls _loadData() → refetches all widgets
```

### Dashboard Load Sequence

```
DashboardScreen.initState()
    │
    ▼
_loadData()
    │
    ├─→ Future.wait([
    │     ScoreService.calculateScore(),        ─┐
    │     DB.getIncomeExpense(thisMonth),         │
    │     DB.getIncomeExpense(prevMonth),         │  7 parallel queries
    │     DB.getWeeklySpending(4),               │
    │     DB.getCategorySums(thisWeek),           │
    │     DB.getCategorySums(thisMonth),          │
    │     DB.getRecentTransactions(5),           ─┘
    │   ])
    │
    ▼
setState() → UI rebuilds with live data
```

### Score Calculation Flow

```
ScoreService.calculateScore()
    │
    ├─→ DB.getIncomeExpense(90 days)
    │       └─→ savingsRatio = (income - expense) / income
    │
    ├─→ DB.getCategorySums(90 days)
    │       └─→ categoryDiversity = uniqueCount / 6
    │
    ├─→ Budget adherence from income/expense ratio
    │       └─→ adherence = 1.0 if expense ≤ 70% income
    │
    ├─→ DB.getMonthlyTotals(6)
    │       └─→ consistency = months within ±15% of avg
    │
    ├─→ DB.getWeekendVsTotal(90 days)
    │       └─→ lowImpulse = 1 - (weekend / total)
    │
    ▼
score = (ratio×30 + diversity×15 + adherence×25
       + consistency×15 + impulse×15).clamp(0, 100)
```

---

## State Management Pattern

FinPulse uses **vanilla Flutter state management** — no Provider, Riverpod, or Bloc:

| Pattern | Where Used |
|---------|-----------|
| `StatefulWidget` + `setState` | All data-fetching screens (Dashboard, History, Goals, Insights) |
| `StreamBuilder` | `AuthWrapper` for auth state |
| `IndexedStack` | `MainNavigationScreen` (preserves tab state) |
| `Future.wait` | Dashboard parallel data loading |
| Singleton | `DatabaseHelper.instance` (one DB connection) |
| `SharedPreferences` | Settings toggle persistence |

**Data refresh triggers:**
- `initState()` — initial load on screen mount
- `RefreshIndicator` — pull-to-refresh
- `Navigator.pop(context, true)` — child signals parent to reload after mutation
- Direct `_loadData()` calls after insert/update/delete operations

---

## Database Schema

### `transactions` table (v2)

```sql
CREATE TABLE transactions (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  sms_id    TEXT,
  amount    REAL     NOT NULL,
  merchant  TEXT     NOT NULL,
  category  TEXT     NOT NULL,
  type      TEXT     NOT NULL,        -- 'Credit' or 'Debit'
  timestamp TEXT     NOT NULL,        -- ISO 8601
  notes     TEXT                      -- added in v2
)
```

### `goals` table (v2)

```sql
CREATE TABLE goals (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT    NOT NULL,
  icon_index  INTEGER NOT NULL DEFAULT 0,
  color_value INTEGER NOT NULL DEFAULT 4282560530,
  target      REAL    NOT NULL,
  saved       REAL    NOT NULL DEFAULT 0,
  created_at  TEXT    NOT NULL         -- ISO 8601
)
```

### Migration Strategy

```dart
_onUpgrade(Database db, int oldVersion, int newVersion) {
  if (oldVersion < 2) {
    db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
    db.execute('CREATE TABLE IF NOT EXISTS goals (...)');
  }
  // Future migrations: if (oldVersion < 3) { ... }
}
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.12.1 | Firebase initialization |
| `firebase_auth` | ^5.5.1 | Email/password + Google authentication |
| `google_sign_in` | ^6.2.2 | Google OAuth flow |
| `sqflite` | ^2.4.2 | On-device SQLite database |
| `path` | ^1.9.1 | Database file path resolution |
| `shared_preferences` | ^2.5.3 | Key-value persistence for settings |
| `intl` | ^0.20.2 | Date/number formatting (₹ currency, dates) |
| `fl_chart` | ^0.70.2 | Bar charts, pie charts (dashboard/insights) |
| `flutter_animate` | ^4.5.2 | Micro-animations and transitions |
| `permission_handler` | ^11.3.1 | SMS read permission for auto-parsing |

---

*Last updated: March 1, 2026*
