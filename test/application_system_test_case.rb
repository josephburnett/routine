require "test_helper"

# Capybara 3.40 resets Chrome with Storage.clearDataForOrigin(origin: "*"),
# which Chrome 158+ rejects as "not a valid URL", failing every test's teardown.
# Clear cookies another way instead. Tests that use localStorage clear it
# themselves (see RememberDeckTest).
module ChromeResetWithoutWildcardOrigin
  def execute_cdp(cmd, **params)
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetWithoutWildcardOrigin)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Set SELENIUM_REMOTE_URL to use a Chrome running elsewhere, e.g.
  #   docker run -d --network host --shm-size 2g selenium/standalone-chrome
  #   SELENIUM_REMOTE_URL=http://127.0.0.1:4444 bin/rails test:system
  remote = ENV["SELENIUM_REMOTE_URL"].presence
  driver_options = remote ? { browser: :remote, url: remote } : {}

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: driver_options do |chrome|
    # Chrome's password prompts ("Save password?", "found in a data breach")
    # steal focus after logging in, and the next click or key press is lost
    chrome.add_preference("credentials_enable_service", false)
    chrome.add_preference("profile.password_manager_enabled", false)
    chrome.add_preference("profile.password_manager_leak_detection", false)
    chrome.add_argument("--disable-features=PasswordManagerOnboarding,PasswordLeakDetection")
  end
end
