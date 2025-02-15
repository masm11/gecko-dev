const LOCALE_PREF = "general.useragent.locale";

XPCOMUtils.defineLazyServiceGetter(this, "aboutNewTabService",
                                   "@mozilla.org/browser/aboutnewtab-service;1",
                                   "nsIAboutNewTabService");

const DEFAULT_URL = "resource://activity-stream/prerendered/en-US/activity-stream-prerendered.html";
async function getUrlForLocale(locale) {
  await SpecialPowers.pushPrefEnv({set: [[LOCALE_PREF, locale]]});
  return aboutNewTabService.defaultURL;
}

/**
 * Test that an unknown locale defaults to en-US
 */
add_task(async function test_unknown_locale() {
  const url = await getUrlForLocale("foo-BAR");
  Assert.equal(url, DEFAULT_URL);
});

/**
 * Test that we at least have en-US
 */
add_task(async function test_default_locale() {
  const url = await getUrlForLocale("en-US");
  Assert.equal(url, DEFAULT_URL);
});

/**
 * Test that we use a shared language before en-US
 */
add_task(async function test_default_locale() {
  const url = await getUrlForLocale("de-UNKNOWN");
  Assert.equal(url, DEFAULT_URL.replace("en-US", "de"));
});

/**
 * Tests that all activity stream packaged locales can be referenced / accessed
 */
add_task(async function test_all_packaged_locales() {
  const listing = await (await fetch("resource://activity-stream/prerendered/")).text();
  for (const line of listing.split("\n").slice(2)) {
    const [file, , , type] = line.split(" ").slice(1);
    if (type === "DIRECTORY") {
      const locale = file.replace("/", "");
      if (locale !== "static") {
        const url = await getUrlForLocale(locale);
        Assert[locale === "en-US" ? "equal" : "notEqual"](url, DEFAULT_URL, `can reference "${locale}" files`);
      }
    }
  }
});
