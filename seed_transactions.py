import sqlite3
from datetime import datetime, timedelta
import random

db_path = '/home/redwing/ssd/Projects/FinPulse/.dart_tool/sqflite_common_ffi/databases/finpulse.db'

def insert_fake_transactions():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    merchants = ["Amazon", "Flipkart", "Nike Store", "Zara", "H&M", "Local Boutique", "Shopping Mall", "Apple Store", "Decathlon", "Lifestyle"]
    today = datetime(2026, 4, 1) # User's "today"
    
    for i in range(10):
        # Morning time: 08:00 to 11:59
        hour = random.randint(8, 11)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        timestamp = today.replace(hour=hour, minute=minute, second=second).isoformat()
        
        amount = -round(random.uniform(500.0, 5000.0), 2)
        merchant = random.choice(merchants)
        category = "Shopping"
        tx_type = "expense"
        note = f"Fake shopping spend {i+1}"
        
        cursor.execute('''
            INSERT INTO transactions (amount, merchant, category, type, timestamp, note)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (amount, merchant, category, tx_type, timestamp, note))
    
    conn.commit()
    conn.close()
    print("Successfully inserted 10 fake transactions.")

if __name__ == "__main__":
    insert_fake_transactions()
