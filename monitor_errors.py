#!/usr/bin/env python3
import os
import time
import psutil  # Import psutil library for disk usage
import requests
from systemd import journal
import sqlite3

# SQLite configuration
SQLITE_DB_PATH = "/var/lib/qoran.top/subscriptions.db"
SQLITE_TABLE_NAME = "subscribers"
SQLITE_POLL_INTERVAL = 60

last_entry_id = None

# Telegram bot configuration
BOT_TOKEN = "7559555875:AAFfBAYJ2EGQ7m8vzXY54B9ZjfgFHt0SAFY"
CHAT_ID = "5429930665"
TELEGRAM_API = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"

MAX_TELEGRAM_MESSAGE_LENGTH = 4096

def send_telegram_message(message, retries=5, delay=2):
    """Send a message to the Telegram bot with retry logic and message splitting."""
    if len(message) > MAX_TELEGRAM_MESSAGE_LENGTH:
        split_messages = [
            message[i : i + MAX_TELEGRAM_MESSAGE_LENGTH]
            for i in range(0, len(message), MAX_TELEGRAM_MESSAGE_LENGTH)
        ]
        for msg in split_messages:
            send_telegram_message(msg, retries, delay)
        return

    payload = {
        "chat_id": CHAT_ID,
        "text": message,
        "parse_mode": "Markdown",
    }

    for attempt in range(retries):
        try:
            response = requests.post(TELEGRAM_API, data=payload)
            if response.status_code == 200:
                return  # Message sent successfully
            else:
                print(f"Failed to send message: {response.text}")
                if response.status_code == 400:  # Fatal error (e.g., bad request)
                    raise RuntimeError("Bad Request: Check message formatting or content.")
        except requests.exceptions.RequestException as e:
            print(f"Error sending Telegram message (attempt {attempt + 1}/{retries}): {e}")
            time.sleep(delay * (2 ** attempt))  # Exponential backoff

    print("Failed to send Telegram message after multiple attempts.")
    raise RuntimeError("Network issue or persistent failure.")


def monitor_disk_usage(disk_path="/", threshold=50):  # Default disk path and threshold
    """Monitor disk usage and send notification if it exceeds the threshold."""
    disk = psutil.disk_usage(disk_path)
    usage_percent = disk.used / disk.total * 100

    if usage_percent > threshold:
        message = f"**Disk Usage Alert:**\n" \
                  f"* Disk Path: {disk_path}\n" \
                  f"* Usage: {usage_percent:.1f}% (used: {disk.used // (1024**3)} GB, free: {disk.free // (1024**3)} GB)\n" \
                  f"* Threshold: {threshold}%"
        send_telegram_message(message)


def monitor_journal():
    """Monitor the system journal for errors and disk usage."""
    j = journal.Reader()
    j.seek_tail()
    j.get_previous()

    # Monitor priority levels
#    j.add_match(PRIORITY="3")  # Include err
#    j.add_match(PRIORITY="2")  # Include crit
#    j.add_match(PRIORITY="1")  # Include alert
#    j.add_match(PRIORITY="0")  # Include emerg
    #j.add_match(PRIORITY="<="3)

    while True:
        j.wait()
        for entry in j:
            if "MESSAGE" in entry:
                message = entry["MESSAGE"]
                priority = entry.get("PRIORITY", "Unknown")
                timestamp = entry.get("__REALTIME_TIMESTAMP", "Unknown")
                hostname = entry.get("_HOSTNAME", "Unknown")
                systemd_unit = entry.get("_SYSTEMD_UNIT", "Unknown")
                syslog_id = entry.get("SYSLOG_IDENTIFIER", "Unknown")

                # Format the notification message for systemd logs
                notification = (
                    f"*Log Detected:*\n"
                    f"Priority: {priority}\n"
                    f"Message: {message}\n"
                    f"Host: {hostname}\n"
                    f"Systemd Unit: {systemd_unit}\n"
                    f"Syslog Identifier: {syslog_id}\n"
                    f"Time: {timestamp}"
                )
                try:
                    send_telegram_message(notification)
                except RuntimeError as e:
                    print(f"Fatal error in notification: {e}")
                    os._exit(1)

def monitor_sqlite():
    """Monitor a SQLite database for new entries and send notifications."""
    global last_entry_id

    # Connect to the SQLite database
    conn = sqlite3.connect(SQLITE_DB_PATH)
    cursor = conn.cursor()

    # Get the last entry ID if it exists
    cursor.execute(f"SELECT MAX(rowid) FROM {SQLITE_TABLE_NAME}")
    result = cursor.fetchone()
    last_entry_id = result[0] if result[0] is not None else 0

    while True:
        # Check for new entries
        cursor.execute(f"SELECT * FROM {SQLITE_TABLE_NAME} WHERE rowid > ?", (last_entry_id,))
        new_entries = cursor.fetchall()

        if new_entries:
            for entry in new_entries:
                # Format the notification message for new database entries
                notification = (
                    f"*New Database Entry Detected:*\n"
                    f"Table: {SQLITE_TABLE_NAME}\n"
                    f"Entry: {entry}\n"
                )
                try:
                    send_telegram_message(notification)
                except RuntimeError as e:
                    print(f"Fatal error in notification: {e}")
                    os._exit(1)

            # Update the last entry ID
            last_entry_id = new_entries[-1][0]

        # Wait before polling again
        time.sleep(SQLITE_POLL_INTERVAL)


if __name__ == "__main__":
    # Start monitoring tasks
    import threading

    # Start journal monitoring in a separate thread
    journal_thread = threading.Thread(target=monitor_journal)
    journal_thread.daemon = True
    journal_thread.start()

    # Start SQLite monitoring in a separate thread
    sqlite_thread = threading.Thread(target=monitor_sqlite)
    sqlite_thread.daemon = True
    sqlite_thread.start()

    # Keep the main thread alive
    while True:
        time.sleep(1)
