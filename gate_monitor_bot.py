
import asyncio
import time
import requests
from typing import List, Dict
from tenacity import retry, wait_fixed, stop_after_attempt

# === CONFIG ===
PERCENT_THRESHOLD = 30
CHECK_INTERVAL_SECONDS = 60
TELEGRAM_BOT_TOKEN = "7729091391:AAGdwQ5sG9NpQqXeFPuqz4vygAfW9EKoeqk"
TELEGRAM_CHAT_ID = "1929039590"
GATE_API_TICKERS_URL = "https://api.gate.io/api/v4/spot/tickers"
TELEGRAM_API_URL = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"

# === RETRY CONFIG ===
retry_config = dict(wait=wait_fixed(3), stop=stop_after_attempt(5))

# === STATE ===
alerted_symbols = set()

# === RETRY-ENABLED FUNCTIONS ===
@retry(**retry_config)
def fetch_gate_tickers() -> List[Dict]:
    response = requests.get(GATE_API_TICKERS_URL)
    response.raise_for_status()
    return response.json()

@retry(**retry_config)
def send_telegram_alert(message: str):
    requests.post(TELEGRAM_API_URL, data={
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message
    })

# === MOCKED Coin Metadata ===
def get_mock_coin_metadata(symbol: str) -> Dict:
    symbol = symbol.upper()
    return {
        "name": f"{symbol} Project",
        "market_cap": "3.4B USD",
        "supply": "21,000,000",
        "twitter": f"https://twitter.com/{symbol.lower()}official",
        "description": f"{symbol} is a leading crypto project focused on DeFi and scalability. "
                       f"It enables fast, low-cost transactions and provides robust smart contract functionality."
    }

# === CORE MONITORING ===
def filter_significant_changes(tickers: List[Dict]) -> List[Dict]:
    significant = []
    for t in tickers:
        try:
            percent_change = float(t.get("change_percentage", "0").replace('%', ''))
            symbol = t["currency_pair"]
            if abs(percent_change) >= PERCENT_THRESHOLD and symbol not in alerted_symbols:
                significant.append({
                    "symbol": symbol,
                    "percent_change": percent_change,
                    "last": t["last"],
                    "high": t["high_24h"],
                    "low": t["low_24h"],
                    "volume": t["base_volume"]
                })
                alerted_symbols.add(symbol)
        except Exception:
            continue
    return significant

def send_alerts_with_metadata(coins: List[Dict]):
    for coin in coins:
        base_symbol = coin['symbol'].split("_")[0]
        change = coin['percent_change']
        direction = "🚀 上涨" if change > 0 else "📉 下跌"
        metadata = get_mock_coin_metadata(base_symbol)
        msg = (
            f"{direction} | {coin['symbol']} ({metadata['name']})\n"
            f"涨跌幅: {change:.2f}%\n"
            f"最新价: {coin['last']}\n"
            f"市值: {metadata['market_cap']} | 流通量: {metadata['supply']}\n"
            f"📄 简介: {metadata['description']}\n"
            f"🔗 X链接: {metadata['twitter']}\n"
            f"#GateIO #Crypto"
        )
        try:
            send_telegram_alert(msg)
        except Exception as e:
            print(f"[ERROR] Telegram send failed: {e}")

async def monitor_loop():
    while True:
        print(f"[{time.strftime('%X')}] Fetching tickers...")
        try:
            tickers = fetch_gate_tickers()
            significant = filter_significant_changes(tickers)
            if significant:
                print(f"[INFO] Found {len(significant)} significant moves.")
                send_alerts_with_metadata(significant)
            else:
                print("[INFO] No significant price changes.")
        except Exception as e:
            print(f"[ERROR] Monitoring failed: {e}")
        await asyncio.sleep(CHECK_INTERVAL_SECONDS)

if __name__ == "__main__":
    try:
        asyncio.run(monitor_loop())
    except KeyboardInterrupt:
        print("Monitoring stopped.")
