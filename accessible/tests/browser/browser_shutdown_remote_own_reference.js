/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

"use strict";

add_task(async function() {
  // Making sure that the e10s is enabled on Windows for testing.
  await setE10sPrefs();

  await BrowserTestUtils.withNewTab({
    gBrowser,
    url: `data:text/html,
      <html>
        <head>
          <meta charset="utf-8"/>
          <title>Accessibility Test</title>
        </head>
        <body></body>
      </html>`
  }, async function(browser) {
    info("Creating a service in parent and waiting for service to be created " +
      "in content");
    // Create a11y service in the main process. This will trigger creating of
    // the a11y service in parent as well.
    let parentA11yInit = initPromise();
    let contentA11yInit = initPromise(browser);
    let contentConsumersChanged =
      ContentTask.spawn(browser, {}, a11yConsumersChangedPromise);
    let accService = Cc["@mozilla.org/accessibilityService;1"].getService(
      Ci.nsIAccessibilityService);
    ok(accService, "Service initialized in parent");
    await Promise.all([parentA11yInit, contentA11yInit]);
    await contentConsumersChanged.then(data => Assert.deepEqual(data, {
      XPCOM: false, MainProcess: true, PlatformAPI: false
    }, "Accessibility service consumers in content are correct."));

    info("Adding additional reference to accessibility service in content " +
      "process");
    contentConsumersChanged =
      ContentTask.spawn(browser, {}, a11yConsumersChangedPromise);
    // Add a new reference to the a11y service inside the content process.
    loadFrameScripts(browser, `let accService = Components.classes[
      '@mozilla.org/accessibilityService;1'].getService(
        Components.interfaces.nsIAccessibilityService);`);
    await contentConsumersChanged.then(data => Assert.deepEqual(data, {
      XPCOM: true, MainProcess: true, PlatformAPI: false
    }, "Accessibility service consumers in content are correct."));

    info("Shutting down a service in parent and making sure the one in " +
      "content stays alive");
    let contentCanShutdown = false;
    let parentA11yShutdown = shutdownPromise();
    contentConsumersChanged =
      ContentTask.spawn(browser, {}, a11yConsumersChangedPromise);
    // This promise will resolve only if contentCanShutdown flag is set to true.
    // If 'a11y-init-or-shutdown' event with '0' flag (in content) comes before
    // it can be shut down, the promise will reject.
    let contentA11yShutdown = new Promise((resolve, reject) =>
      shutdownPromise(browser).then(flag => contentCanShutdown ?
        resolve() : reject("Accessible service was shut down incorrectly")));
    // Remove a11y service reference in the main process and force garbage
    // collection. This should not trigger shutdown in content since a11y
    // service is used by XPCOM.
    accService = null;
    ok(!accService, "Service is removed in parent");
    // Force garbage collection that should not trigger shutdown because there
    // is a reference in a content process.
    forceGC();
    loadFrameScripts(browser, `Components.utils.forceGC();`);
    await parentA11yShutdown;
    await contentConsumersChanged.then(data => Assert.deepEqual(data, {
      XPCOM: true, MainProcess: false, PlatformAPI: false
    }, "Accessibility service consumers in content are correct."));

    // Have some breathing room between a11y service shutdowns.
    await new Promise(resolve => executeSoon(resolve));

    info("Removing a service in content");
    // Now allow a11y service to shutdown in content.
    contentCanShutdown = true;
    contentConsumersChanged =
      ContentTask.spawn(browser, {}, a11yConsumersChangedPromise);
    // Remove last reference to a11y service in content and force garbage
    // collection that should trigger shutdown.
    loadFrameScripts(browser, `accService = null; Components.utils.forceGC();`);
    await contentA11yShutdown;
    await contentConsumersChanged.then(data => Assert.deepEqual(data, {
      XPCOM: false, MainProcess: false, PlatformAPI: false
    }, "Accessibility service consumers in content are correct."));

    // Unsetting e10s related preferences.
    await unsetE10sPrefs();
  });
});
