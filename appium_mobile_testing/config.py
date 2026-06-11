import sys
import os
from dotenv import load_dotenv

load_dotenv()

# Appium server host and port
appium_host = os.getenv("APPIUM_HOST", "127.0.0.1")
appium_port = int(os.getenv("APPIUM_PORT", "4723"))

# Path to local built APK
# Default matches Flutter's default debug build output folder
apk_path = os.getenv("MOBILE_APK_PATH", "../frontend/build/app/outputs/flutter-apk/app-debug.apk")
abs_apk_path = os.path.abspath(apk_path)

# Appium Mobile Native Capabilities
mobile_capabilities = {
    "platformName": "Android",
    "appium:automationName": "UiAutomator2",
    "appium:deviceName": "Android Device",
    "appium:app": abs_apk_path,
    "appium:appPackage": "com.saveetha.oralulcerai",
    "appium:appActivity": "com.saveetha.oralulcerai.MainActivity",
    "appium:noReset": True,
    "appium:newCommandTimeout": 300,
}
