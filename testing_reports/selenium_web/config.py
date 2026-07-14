import sys
import os
from dotenv import load_dotenv

load_dotenv()

# Check if desktop mode is selected via command line args
is_desktop = "--desktop" in sys.argv

# Configuration settings
target_url = os.getenv("TEST_WEB_URL", "http://localhost:8080/")
appium_host = os.getenv("APPIUM_HOST", "127.0.0.1")
appium_port = int(os.getenv("APPIUM_PORT", "4723"))

# Appium Mobile Capabilities
mobile_capabilities = {
    "platformName": "Android",
    "appium:automationName": "UiAutomator2",
    "appium:deviceName": "Android Emulator",
    "appium:browserName": "Chrome",
    "appium:noReset": True,
}
