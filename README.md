# FinPulse: Behavioral Expense Analytics

FinPulse is an intelligent personal finance tracker that goes beyond simple budgeting. By leveraging **Behavioral Economics** and **Cognitive Psychology**, it analyzes your spending patterns to help you understand *why* you spend, not just *how much*.

## 🧠 Behavioral Analytics Framework

FinPulse uses deterministic models to identify spending habits that reflect cognitive biases.

### 1. Impulse Score (0-100)
The Impulse Score is a measure of financial discipline, calculated using the **Behavioral Impulsivity Index (BII)**. A higher score indicates lower impulsivity.

**BII Components:**
- **Discretionary Spending Ratio (40%)**: The proportion of spending in high-impulse categories (Shopping, Entertainment, Dining) relative to total expenses.
- **Temporal Risk Factor (20%)**: Analysis of spending during high-risk windows (Late Night 10 PM - 2 AM, and Early Morning routine spikes).
- **Volatility Index (20%)**: Measures the irregularity and variance of daily spending compared to the monthly average.
- **Income Displacement (20%)**: A sigmoid-weighted penalty for high expense-to-income ratios.

### 2. Saving Mindset
Based on your current savings rate (`(Income - Expense) / Income`), FinPulse classifies your financial health:
- **🌱 Growth**: Savings Rate > 20%. Focused on wealth accumulation and long-term goals.
- **⚖️ Steady**: Savings Rate 5-20%. Maintaining equilibrium, but with potential for optimization.
- **⚠️ At Risk**: Savings Rate < 5%. Immediate action needed to avoid financial stress.

### 3. Psychology-Based Drivers
The app identifies specific "Key Drivers" that trigger common spending biases:
- **☕ Morning Rituals**: Food/Grocery spending before 12 PM. Often reflects routine-based impulse buys (e.g., daily expensive lattes).
- **🌙 Late Night Activity**: Spending between 10 PM – 1 AM. High risk for decision fatigue and impulse shopping.
- **📉 Auto-Save Efficiency**: Tracks the gap between earned income and recorded expenses to find hidden "leakage."

## 🏷️ Standardized Categories

FinPulse automatically categorizes transactions using a central mapping engine (`lib/core/constants/categories_data.dart`).

- **🍔 Food**: Zomato, Swiggy, Starbucks, McDonald's, Restaurants, Coffee.
- **🛍️ Shopping**: Amazon, Flipkart, Myntra, Nykaa, Lifestyle, Zara.
- **🛒 Groceries**: BigBasket, Blinkit, Zepto, Swiggy Instamart, DMart.
- **🚗 Transportation**: Uber, Ola, Rapido, Fuel (Petrol/Diesel), Metro, IRCTC.
- **⚡ Bills**: Airtel, Jio, Electricity, Broadband, Mobile, Recharges.
- **🎭 Entertainment**: Netflix, Prime Video, Hotstar, Cinema, Spotify, BookMyShow.
- **🩺 Health**: Apollo Pharmacy, Netmeds, Doctors, Clinics, Gyms.
- **💰 Income**: Salary, Credits, Refunds, Interest.

## 🛠️ Key Assumptions & Privacy

- **SMS-Only Core**: Transactions are primarily detected via SMS keywords (`DEBITED`, `DEBIT`, `UPI`, `SPENT`). FinPulse prioritizes privacy by processing all SMS data locally.
- **Local SQLite**: Your financial history never leaves your device. FinPulse uses an encrypted-compliant local database.
- **Merchant Mapping**: Merchants are extracted using pattern matching (e.g., "TO <NAME>", "VPA <NAME>") and then mapped against a brand database.

## 🏛️ Cognitive Biases Tracked
- **Loss Aversion**: The tendency to prefer avoiding losses over acquiring equivalent gains.
- **Anchor Effect**: Subconscious reliance on the first piece of information offered (e.g., an "original" high price).
- **Lifestyle Creep**: The subtle expansion of spending as income grows.
- **Choice Overload**: Decision fatigue leading to "fast" but poor financial choices.

---
*Built with ❤️ using Flutter and SQLite.*
