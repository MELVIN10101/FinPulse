# FinPulse — Backend Logic & Architecture

> A personal finance tracker built with Flutter, Firebase Auth, and on-device SQLite persistence. All financial data stays on the user's device — nothing is synced to the cloud.

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Flutter UI                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────┐  │
│  │Dashboard │ │ History  │ │ Insights │ │ Goals  │ │ More │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ └──┬───┘  │
│       │            │            │            │         │     │
│  ─────┴────────────┴────────────┴────────────┴─────────┴──── │
│                     Service Layer                            │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │  ScoreService    │  │   SMSService     │                  │
│  │  (score calc)    │  │  (SMS parsing)   │                  │
│  └────────┬─────────┘  └────────┬─────────┘                  │
│           │                     │                            │
│  ─────────┴─────────────────────┴────────────────────────────│
│                     Data Layer                               │
│  ┌──────────────────────────────────────────────────────────┐│
│  │              DatabaseHelper (Singleton)                  ││
│  │  ┌─────────────────┐     ┌──────────────────┐            ││
│  │  │  transactions   │     │     goals         │           ││
│  │  │  (SQLite table) │     │  (SQLite table)   │           ││
│  │  └─────────────────┘     └──────────────────┘            ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │              SharedPreferences                           ││
│  │  (toggle states: sms_sync, notifications, biometrics,    ││
│  │   dark_mode)                                             ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │              Firebase Auth                               ││
│  │  (Email/Password + Google Sign-In)                       ││
│  └──────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

**Key principle**: Firebase handles authentication only. All financial data (transactions, goals, scores) is stored **on-device** in SQLite via the `sqflite` package. User preferences are persisted in `SharedPreferences`.

---
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


