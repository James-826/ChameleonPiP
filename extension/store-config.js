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
    // Configurable sponsor & CPS affiliate cards for Chameleon Fuel Supply Station
    // Replace or append real sponsor/affiliate links anytime (zero code edits needed)
    sponsors: [
      {
        id: "sponsor-slot-1",
        badge: "官方合作品牌 · 招租中",
        name: "AI 编程助手 / 独立开发工具直投位",
        desc: "直达一线开发与高效办公用户，支持按月固定赞助或 CPS 合作推广返佣兑换 Pro 会员。",
        rewardTag: "合作联系：support@chameleonpip.site",
        url: "mailto:support@chameleonpip.site?subject=ChameleonPiP%20Sponsor%20Inquiry",
        ctaText: "商务合作",
      },
      {
        id: "sponsor-github",
        badge: "开源社区支持",
        name: "GitHub 开源仓库 · 关注与 Star 支持",
        desc: "前往 GitHub 给 ChameleonPiP 点亮 Star 或提交功能建议，关注最新版本与桌面端更新。",
        rewardTag: "开源透明 · 持续迭代",
        url: "https://github.com/James-826/ChameleonPiP",
        ctaText: "前往支持",
      },
    ],
    supportEmail: "support@chameleonpip.site",
  };
})(typeof window !== "undefined" ? window : globalThis);
