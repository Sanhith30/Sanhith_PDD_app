from appium import webdriver
from appium.options.common import AppiumOptions
import config

def get_driver():
    """
    Initializes and returns the Appium WebDriver session for the Android native application.
    """
    appium_server_url = f"http://{config.appium_host}:{config.appium_port}"
    print(f"Connecting to Appium Server at {appium_server_url}...")
    print(f"Targeting APK at: {config.abs_apk_path}")
    
    options = AppiumOptions()
    options.load_capabilities(config.mobile_capabilities)
    
    try:
        driver = webdriver.Remote(appium_server_url, options=options)
        print("Appium automation session initialised successfully!")
        return driver
    except Exception as e:
        print(f"\n[ERROR] Failed to start Appium session: {e}")
        print("Please check that:")
        print(f"  1. Appium server is running at {appium_server_url}")
        print("  2. An Android device or emulator is connected (run 'adb devices')")
        print(f"  3. The APK exists at: {config.abs_apk_path}")
        raise e

def close_driver(driver):
    """
    Safely tears down the Appium driver session.
    """
    if driver:
        print("\nClosing Appium automation driver session...")
        driver.quit()
