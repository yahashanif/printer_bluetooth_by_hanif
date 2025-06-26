final Map<String, dynamic> template = {
  "paperSize": "mm80",
  "elements": [
    {"type": "image", "key": "logo", "align": "center"},
    {
      "type": "text",
      "key": "storeName",
      "style": {"align": "center", "bold": true}
    },
    {
      "type": "text",
      "key": "storeBranch",
      "style": {"align": "center"}
    },
    {
      "type": "text",
      "template": "Receipt {receiptNumber}",
      "style": {"align": "center"}
    },
    {
      "type": "row",
      "columns": [
        {"template": "{date}", "width": 6, "align": "left", "bold": true},
        {"template": "{time}", "width": 6, "align": "right", "bold": true}
      ]
    },
    {"type": "text", "template": "Cashier: {cashier}"},
    {"type": "text", "template": "Payment: {payment}"},
    {"type": "text", "template": "Pickup: {pickup}"},
    {"type": "text", "template": "Customer: {customer}"},
    {"type": "text", "template": "Phone No: {phone}"},
    {"type": "divider"},
    {"type": "custom_items"},
    {"type": "divider"},
    {
      "type": "row",
      "columns": [
        {"template": "Voucher:", "width": 6, "align": "left"},
        {"template": "{vouchers}", "width": 6, "align": "right"}
      ]
    },
    {
      "type": "row",
      "columns": [
        {"template": "Subtotal:", "width": 6, "align": "left"},
        {"template": "{subtotal}", "width": 6, "align": "right"}
      ]
    },
    {
      "type": "row",
      "columns": [
        {"template": "Discount:", "width": 6, "align": "left"},
        {"template": "-{discount}", "width": 6, "align": "right"}
      ]
    },
    {"type": "divider"},
    {
      "type": "row",
      "columns": [
        {"template": "Grand Total:", "width": 6, "align": "left", "bold": true},
        {"template": "{grandTotal}", "width": 6, "align": "right", "bold": true}
      ]
    },
    {"type": "divider"},
    {
      "type": "text",
      "key": "thankYou",
      "style": {"align": "center", "bold": true}
    },
    {"type": "text", "template": ""},
    {"type": "barcode", "key": "qrcode", "format": "qrcode", "align": "center"},
    {
      "type": "text",
      "template": "Pin : {pin}",
      "style": {"align": "center"}
    }
  ]
};

final Map<String, dynamic> payload = {
  "logo":
      "https://equalengineers.com/wp-content/uploads/2024/04/dummy-logo-5b.png", // opsional, jika kamu punya support gambar
  "storeName": "Choayo Laundry",
  "storeBranch": "Store 1",
  "receiptNumber": "#STR01-202566",
  "date": "19/06/2025",
  "time": "20:13:18",
  "cashier": "Trn umadi Gaduh Thamrin",
  "payment": "-",
  "pickup": "walkin",
  "customer": "Prof. Bagas S.T.",
  "phone": "85155352499",
  "items": [
    {
      "name": "JAS",
      "qty": "1x @ Rp 33.300",
      "total": "Rp 33.300",
    }
  ],
  "vouchers": "-",
  "subtotal": "Rp. 33.300",
  "discount": "Rp. 0",
  "grandTotal": "Rp. 33.300",
  "thankYou": "** Thank you **",
  "pin": "504449",
  "qrcode": "https://choayo.com/invoice/STR01-202566"
};
