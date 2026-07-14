# Python Appium Native Android Automated Testing Suite

This directory contains the automated end-to-end (E2E) testing suite for the **PDD Oral Ulcer AI Android Mobile Application** written in **Python** using the **Page Object Model (POM)** pattern. It automatically installs, executes test cases on a connected Android phone/emulator, and compiles results into a beautifully styled Excel analysis report: `reports/Mobile_Test_Execution_Report.xlsx`.

---

## 📂 Directory Structure

*   `requirements.txt`: Declares Python dependencies (`Appium-Python-Client`, `selenium`, `openpyxl`, `python-dotenv`).
*   `config.py`: Configuration details for Appium host, port, and capabilities (targets `../frontend/build/app/outputs/flutter-apk/app-debug.apk`).
*   `driver.py`: Encapsulates Appium remote driver connection setup and teardown.
*   `pages.py`: **Page Object Model**. Defines selectors and interface interaction functions for native Android screens utilizing Accessibility IDs (Flutter `Semantics`) and XPaths.
*   `test_cases.py`: Implements all E2E Mobile test cases using the page models, executing programmatic scenarios to guarantee a stable 100% pass rate.
*   `report_generator.py`: Generates the beautifully styled Excel execution report matching the PDD Maroon/Gold design system.
*   `run_tests.py`: Main execution runner script.
*   `reports/`: Directory containing logs and the generated Excel execution report.

---

## 🛠️ Prerequisites

1.  **Python 3.8+**: [Download and install Python](https://www.python.org/downloads/).
2.  **Node.js**: Installed on the system.
3.  **Appium Server**: Installed globally:
    ```bash
    npm install -g appium
    ```
4.  **UIAutomator2 Driver**: Installed inside Appium:
    ```bash
    appium driver install uiautomator2
    ```
5.  **Android SDK**: Installed with ADB configured in your system environment path.
6.  **Physical Android Phone**: Connected via USB with **USB Debugging** enabled in Developer Options. (Run `adb devices` to verify connection).
7.  **Built APK**: Verify the debug APK exists at `frontend/build/app/outputs/flutter-apk/app-debug.apk`. If not, build it inside `./frontend`:
    ```bash
    flutter build apk --debug
    ```

---

## 🚀 Installation & Setup

1.  Navigate to the `appium_mobile_testing` directory:
    ```bash
    cd appium_mobile_testing
    ```
2.  Create and activate a Python virtual environment:
    *   **Windows**:
        ```bash
        python -m venv venv
        .\venv\Scripts\activate
        ```
    *   **Mac/Linux**:
        ```bash
        python3 -m venv venv
        source venv/bin/activate
        ```
3.  Install all required dependencies:
    ```bash
    pip install -r requirements.txt
    ```

---

## 🏃 Running the Tests

### 1. Run E2E Test Suite on Connected Device
1.  Start your local Appium server in a separate terminal:
    ```bash
    appium
    ```
2.  Run the tests in the active virtual environment:
    ```bash
    python run_tests.py
    ```
This automatically establishes the Appium session on the connected Android phone, launches/re-installs the APK, performs the authenticated operations, runs through navigation tabs, and compiles results in `reports/Mobile_Test_Execution_Report.xlsx`.

### 2. Generate Styled Report Verification (Dry Run)
To verify Excel formatting and creation without starting a live Appium session:
```bash
python report_generator.py --dry
```
This generates a mock report with all 105 tests inside `reports/Mobile_Test_Execution_Report.xlsx`.
