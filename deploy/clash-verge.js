// Install a private copy with LOCAL_SUBSCRIPTIONS replaced by this device's URLs.
// Keep the generated copy outside Git; it runs after each subscription update.
const LOCAL_SUBSCRIPTIONS = {};

function main(config, profileName) {
  const providers = config["proxy-providers"] || {};
  for (const [name, provider] of Object.entries(providers)) {
    if (!["vip1", "vip2", "vip3"].includes(name)) continue;
    const url = LOCAL_SUBSCRIPTIONS[name];
    if (typeof url !== "string" || !url.startsWith("https://")) {
      throw new Error("Missing local subscription: " + name);
    }
    provider.url = url;
  }
  return config;
}
