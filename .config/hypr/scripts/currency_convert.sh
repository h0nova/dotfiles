#!/usr/bin/env bash
AMOUNT="$1"
CURRENCY="$2"

case "${CURRENCY,,}" in
    '$'|'usd') CODE="USD" ;;
    '€'|'eur') CODE="EUR" ;;
    '£'|'gbp') CODE="GBP" ;;
    '¥'|'jpy') CODE="JPY" ;;
    '₽'|'rub') CODE="RUB" ;;
    'chf')     CODE="CHF" ;;
    'pln'|'zł') CODE="PLN" ;;
    *) exit 1 ;;
esac

TICKER="${CODE}UAH=X"
RATE=$(curl -s --max-time 5 \
    -H "User-Agent: Mozilla/5.0" \
    "https://query1.finance.yahoo.com/v8/finance/chart/${TICKER}?interval=1d&range=1d" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d['chart']['result'][0]['meta']['regularMarketPrice'])" 2>/dev/null)

[ -z "$RATE" ] && echo "Помилка отримання курсу" && exit 1

python3 -c "
amount = float('${AMOUNT}'.replace(',', '.'))
rate = float('${RATE}')
result = amount * rate
print(f'{result:,.2f} ₴   (1 ${CODE} = {rate:.2f} ₴)')
"
