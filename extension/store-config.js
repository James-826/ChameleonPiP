/**
 * ChameleonPiP Commercial Store & Checkout Configuration
 *
 * Replace the placeholder URLs below once you create your Mianbaoduo / Afdian /
 * Lemon Squeezy product links and attach your custom domain.
 */
(function (global) {
  "use strict";

  global.CHAMELEON_STORE_CONFIG = {
    brandName: "ChameleonPiP",
    brandNameZh: "变色龙画中画",
    version: "v5.5.0",
    siteUrl: "https://chameleonpip.site",
    githubRepoUrl: "https://github.com/James-826/ChameleonPiP",
    downloads: {
      macAppZip: "https://chameleonpip.site/downloads/ChameleonPiP-macOS-App-v5.5.zip?v=5.5.3",
      chromeExtZip: "https://chameleonpip.site/downloads/ChameleonPiP-Chrome-Extension-v5.5.zip?v=5.5.3",
      chromeWebStore: "", // Fill after Chrome Web Store approval
      edgeAddons: "",     // Fill after Microsoft Edge Add-ons approval
    },
    // Drop your WeChat / Alipay appreciation code image into web/ (e.g. "qr-wechat.png", "qr-alipay.png")
    // and fill the paths below — they will appear automatically on the website & desktop supporter modal!
    tipQrCodes: {
      wechat: "",
      alipay: "",
      note: "全部功能免费开放，如果这个小工具刚好帮到了你，欢迎随心请杯咖啡。",
    },
    // Optional Mianbaoduo / Afdian / BuyMeACoffee links (can leave empty if using direct QR codes above)
    checkoutUrls: {
      coffee: "",
    },
    // Keep sponsorship clean: only voluntary coffee appreciation
    sponsors: [],
    supportEmail: "support@chameleonpip.site",
  };
})(typeof window !== "undefined" ? window : globalThis);
