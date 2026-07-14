from selenium import webdriver as selenium_webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from appium import webdriver as appium_webdriver
from appium.options.common import AppiumOptions
import config

def get_driver():
    """
    Initializes and returns the appropriate WebDriver (Selenium for Desktop Chrome, Appium for Mobile Chrome)
    """
    if config.is_desktop:
        print("Initializing Selenium WebDriver (Desktop Chrome)...")
        chrome_options = selenium_webdriver.ChromeOptions()
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-gpu')
        # Download and setup Chrome driver service using webdriver-manager
        service = Service(ChromeDriverManager().install())
        driver = selenium_webdriver.Chrome(service=service, options=chrome_options)
        # Configure window size
        driver.maximize_window()
        return driver
    else:
        print(f"Connecting to Appium Server at http://{config.appium_host}:{config.appium_port}...")
        options = AppiumOptions()
        options.load_capabilities(config.mobile_capabilities)
        appium_server_url = f"http://{config.appium_host}:{config.appium_port}"
        # Appium webdriver remote initialization
        driver = appium_webdriver.Remote(appium_server_url, options=options)
        return driver

def close_driver(driver):
    """
    Safely tears down the driver session
    """
    if driver:
        print("\nClosing automation driver session...")
        driver.quit()
