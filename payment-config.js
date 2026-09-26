/* Public INTELLENZA payment display configuration.
 * The UPI ID and payee are intentionally public so students can pay.
 * Official bank/payment QR image confirmed by the project owner.
 */
window.INTELLENZA_PAYMENT_CONFIG = Object.freeze({
  upiId: "guna15364-4@oksbi",
  payeeName: "Guna Sekar",
  qrImagePath: "/IMG-20260926-WA0001.jpg",
  currency: "INR",
  instructions: [
    "Pay the exact amount shown for your selected pass.",
    "Confirm the beneficiary name is Guna Sekar before authorizing payment.",
    "Enter the UPI transaction reference/UTR from your payment app.",
    "Your registration remains pending until the organizing team verifies the bank transaction."
  ],
  screenshotBucket: "intellenza-payment-proofs",
  maxScreenshotBytes: 5 * 1024 * 1024,
  allowedScreenshotTypes: ["image/jpeg", "image/png", "image/webp", "application/pdf"]
});
