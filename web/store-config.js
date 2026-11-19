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
    version: "v5.2.0",
    siteUrl: "https://chameleonpip.site",
    githubRepoUrl: "https://github.com/James-826/ChameleonPiP",
    downloads: {
      macAppZip: "https://github.com/James-826/ChameleonPiP/releases/download/v5.2.0/ChameleonPiP-macOS-App-v5.2.zip",
      chromeExtZip: "https://github.com/James-826/ChameleonPiP/releases/download/v5.2.0/ChameleonPiP-Chrome-Extension-v5.2.zip",
      chromeWebStore: "", // Fill after Chrome Web Store approval
      edgeAddons: "",     // Fill after Microsoft Edge Add-ons approval
    },
    // Fill with your Mianbaoduo (mbd.pub) / Afdian / Lemon Squeezy checkout links
    checkoutUrls: {
      monthly: "",
      yearly: "",
      lifetime: "",
    },
    supportEmail: "support@chameleonpip.site",
  };
})(typeof window !== "undefined" ? window : globalThis);
