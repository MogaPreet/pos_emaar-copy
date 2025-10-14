# Web to Flutter Print Integration Guide

## Overview
This guide explains how the web page (https://dbaccess.thinkry.tech/) can send print commands to the Flutter POS app.

## How It Works

The Flutter app provides a JavaScript channel called `FlutterPrint` that the web page can use to send receipt data for printing.

## Web Page Implementation

### Step 1: Detect if running in Flutter WebView

```javascript
// Check if Flutter channel is available
const isFlutterApp = window.FlutterPrint !== undefined;

if (isFlutterApp) {
    console.log("Running in Flutter POS app");
} else {
    console.log("Running in regular browser");
}
```

### Step 2: Send Print Command

When the user clicks the "Print Receipt" button, send the receipt data to Flutter:

```javascript
function printReceipt() {
    const receiptData = {
        "header": {
            "company": "EMAAR ENTERTAINMENT LLC",
            "location": "At The Top",
            "trnNo": "100067521300003",
            "orderNo": "3921893",
            "venue": "Dubai Mall",
            "taxInvoiceText": "TAX INVOICE",
            "saleNo": "805",
            "date": "2025-10-14",
            "time": "08:49 AM",
            "posNo": "pos-1",
            "userId": "2"
        },
        "items": [
            {
                "qty": 1,
                "description": "WEB ATT CH (At The Top) AT THE TOP 148 Floor",
                "price": 114
            },
            {
                "qty": 1,
                "description": "Slider + 2 Pcs Chicken Wings AT THE TOP 148 Floor",
                "price": 118
            }
        ],
        "totals": {
            "discount": 0,
            "totalExclVat": 108.3,
            "vatPercent": 5,
            "vatAmount": 5.7,
            "totalInclVat": 114,
            "change": 0,
            "grandTotal": 114
        },
        "footer": {
            "thankYou": "THANK YOU FOR VISITING US",
            "termsTitle": "*** TERMS AND CONDITIONS ***",
            "termsLines": [
                "1. Tickets can be used once only and may not be replaced, refunded or exchanged for any reason whatsoever.",
                "2. Find full terms on www.atthetop.ae"
            ]
        },
        "printDateTime": new Date().toISOString()
    };

    // Send to Flutter
    if (window.FlutterPrint) {
        window.FlutterPrint.postMessage(JSON.stringify(receiptData));
        console.log("Print request sent to Flutter app");
    } else {
        console.error("Flutter channel not available");
        // Fallback: show browser print dialog or display message
        alert("Please open this page in the POS app to print");
    }
}
```

### Step 3: Update Your HTML

```html
<!DOCTYPE html>
<html>
<head>
    <title>POS Interface</title>
</head>
<body>
    <button onclick="printReceipt()">Print Receipt</button>
    <button onclick="voidTransaction()">Void Transaction</button>
    <button onclick="printTicket()">Print Ticket</button>

    <script>
        function printReceipt() {
            const receiptData = {
                // ... your receipt data here
            };
            
            if (window.FlutterPrint) {
                window.FlutterPrint.postMessage(JSON.stringify(receiptData));
            } else {
                alert("Please open this page in the POS app to print");
            }
        }

        function voidTransaction() {
            // Similar implementation for void
            const voidData = {
                type: "void",
                // ... void transaction data
            };
            
            if (window.FlutterPrint) {
                window.FlutterPrint.postMessage(JSON.stringify(voidData));
            }
        }

        function printTicket() {
            // Similar implementation for ticket
            const ticketData = {
                type: "ticket",
                // ... ticket data
            };
            
            if (window.FlutterPrint) {
                window.FlutterPrint.postMessage(JSON.stringify(ticketData));
            }
        }
    </script>
</body>
</html>
```

## Receipt Data Format

### Required Fields

#### Header (all optional but recommended)
- `company`: Company name
- `location`: Location/branch name
- `trnNo`: Tax Registration Number
- `orderNo`: Order number
- `venue`: Venue name
- `taxInvoiceText`: Tax invoice text (e.g., "TAX INVOICE")
- `saleNo`: Sale number
- `date`: Date in YYYY-MM-DD format
- `time`: Time in HH:MM AM/PM format
- `posNo`: POS terminal identifier
- `userId`: User ID

#### Items (array of objects)
Each item should have:
- `qty`: Quantity (number)
- `description`: Item description (string)
- `price`: Price (number)

#### Totals
- `discount`: Discount amount (number)
- `totalExclVat`: Total excluding VAT (number)
- `vatPercent`: VAT percentage (number)
- `vatAmount`: VAT amount (number)
- `totalInclVat`: Total including VAT (number)
- `change`: Change amount (number)
- `grandTotal`: Grand total (number)

#### Footer
- `thankYou`: Thank you message (string)
- `termsTitle`: Terms and conditions title (string)
- `termsLines`: Array of terms and conditions lines (array of strings)

### Example JSON

```json
{
    "header": {
        "company": "EMAAR ENTERTAINMENT LLC",
        "location": "At The Top",
        "trnNo": "100067521300003",
        "orderNo": "3921893",
        "venue": "Dubai Mall",
        "taxInvoiceText": "TAX INVOICE",
        "saleNo": "805",
        "date": "2025-10-14",
        "time": "08:49 AM",
        "posNo": "pos-1",
        "userId": "2"
    },
    "items": [
        {
            "qty": 1,
            "description": "WEB ATT CH (At The Top) AT THE TOP 148 Floor",
            "price": 114
        }
    ],
    "totals": {
        "discount": 0,
        "totalExclVat": 108.3,
        "vatPercent": 5,
        "vatAmount": 5.7,
        "totalInclVat": 114,
        "change": 0,
        "grandTotal": 114
    },
    "footer": {
        "thankYou": "THANK YOU FOR VISITING US",
        "termsTitle": "*** TERMS AND CONDITIONS ***",
        "termsLines": [
            "1. Tickets can be used once only and may not be replaced, refunded or exchanged for any reason whatsoever.",
            "2. Find full terms on www.atthetop.ae"
        ]
    },
    "printDateTime": "2025-10-14T06:34:08.203Z"
}
```

## Testing

### In Browser Console
When testing in the Flutter app, you can use the browser console (if WebView debugging is enabled):

```javascript
// Test print
const testReceipt = {
    header: { company: "Test Company", location: "Test Location" },
    items: [{ qty: 1, description: "Test Item", price: 10.00 }],
    totals: { grandTotal: 10.00 },
    footer: { thankYou: "Thank You!" }
};

window.FlutterPrint.postMessage(JSON.stringify(testReceipt));
```

### Expected Behavior
1. Web page calls `window.FlutterPrint.postMessage(jsonString)`
2. Flutter receives the message
3. Flutter logs: "Received print request from web: {json}"
4. Flutter parses the JSON and builds Epson commands
5. Flutter sends to printer
6. User sees snackbar: "Sending receipt to printer..." then "✓ Receipt printed successfully!"

## Error Handling

### On Web Side
```javascript
try {
    if (window.FlutterPrint) {
        window.FlutterPrint.postMessage(JSON.stringify(receiptData));
    } else {
        throw new Error("Flutter channel not available");
    }
} catch (error) {
    console.error("Print failed:", error);
    alert("Unable to print. Please try again.");
}
```

### Flutter Side
Flutter automatically handles:
- JSON parsing errors
- Missing printer connection
- Print failures
- Shows appropriate error messages to user

## Debugging

### Enable WebView Debugging
The app already has WebView debugging enabled for Android. To inspect:

1. Connect device via USB
2. Open Chrome and go to `chrome://inspect`
3. Find your WebView and click "inspect"
4. Use Console to test JavaScript commands

### Check Logs
Flutter logs will show:
- `"Page loaded: [url]"` - When page loads
- `"Received print request from web: [json]"` - When print is triggered
- `"Printing receipt from web data on [printer]"` - When printing starts
- Print success/failure messages

## Tips

1. **Always stringify JSON**: Use `JSON.stringify()` when sending data
2. **Check for Flutter channel**: Always check `if (window.FlutterPrint)` before sending
3. **Include all fields**: Even if optional, include all fields for consistent printing
4. **Use numbers for prices**: Don't send strings like "10.00", use numbers like 10.00
5. **Date format**: Use ISO 8601 format for `printDateTime`

