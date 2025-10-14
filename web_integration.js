/**
 * Flutter POS Integration Script
 * Add this script to your web page to enable printing through the Flutter POS app
 */

// Function to print receipt - call this when "Print Receipt" button is clicked
function printReceipt(receiptData) {
    console.log("printReceipt called", receiptData);
    
    // Check if running in Flutter app
    if (window.FlutterPrint) {
        try {
            // Send receipt data to Flutter
            window.FlutterPrint.postMessage(JSON.stringify(receiptData));
            console.log("Receipt sent to Flutter app for printing");
            return true;
        } catch (error) {
            console.error("Failed to send receipt to Flutter:", error);
            alert("Print failed. Please try again.");
            return false;
        }
    } else {
        console.warn("Not running in Flutter app - print not available");
        alert("Please open this page in the POS app to print");
        return false;
    }
}

// Example: How to use when Print Receipt button is clicked
// Assuming your existing code already has the receipt data
function handlePrintReceiptClick() {
    // Your existing receipt data structure
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
    
    // Send to Flutter for printing
    printReceipt(receiptData);
}

// Check if running in Flutter app when page loads
window.addEventListener('DOMContentLoaded', function() {
    if (window.FlutterPrint) {
        console.log("✅ Running in Flutter POS app - Print functionality available");
        // Optionally show a badge or indicator
        document.body.classList.add('flutter-app');
    } else {
        console.log("ℹ️ Running in regular browser - Print functionality not available");
    }
});

// Alternative: If you want to hook into existing button
// Replace 'your-print-button-id' with your actual button ID
/*
document.getElementById('your-print-button-id').addEventListener('click', function() {
    // Get your receipt data (you probably already have this logic)
    const receiptData = getReceiptData(); // Your existing function
    
    // Send to Flutter
    printReceipt(receiptData);
});
*/

