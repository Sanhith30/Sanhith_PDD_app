# Python Appium/Selenium Automated Testing Suite

This directory contains the automated end-to-end (E2E) testing suite for the **PDD Web Application** translated and structured in **Python** using the **Page Object Model (POM)** pattern. It automatically compiles results into a styled Excel analysis report: `reports/Web_Test_Execution_Report.xlsx`.

---

## 📂 Directory Structure

*   `requirements.txt`: Declares Python dependencies (`Appium-Python-Client`, `selenium`, `openpyxl`, `python-dotenv`).
*   `config.py`: Configuration details for URLs, ports, and emulator capabilities. Dynamically checks for `--desktop` flag.
*   `driver.py`: Encapsulates Selenium and Appium driver connection initialization and teardown.
*   `pages.py`: **Page Object Model**. Defines selectors and interface interaction functions for pages (Login, Forgot Password, Intake, Settings, Profile).
*   `test_cases.py`: Implements all 105 E2E Web test cases using the page models.
*   `report_generator.py`: Generates the beautifully styled Excel execution report matching the PDD Maroon/Gold design system.
*   `run_tests.py`: Main execution runner script.
*   `reports/`: Directory containing logs, screenshots, and execution reports.

---

## 🛠️ Prerequisites

1.  **Python 3.8+**: [Download and install Python](https://www.python.org/downloads/).
2.  **Google Chrome**: Installed on the system.
3.  *(For Mobile Appium Runs)*:
    *   Appium Server globally installed: `npm install -g appium`
    *   Appium UIAutomator2 driver: `appium driver install uiautomator2`
    *   Android Emulator or USB-connected device.

---

## 🚀 Installation & Setup

1.  Navigate to the `appium_testing` directory:
    ```bash
    cd appium_testing
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

### 1. Run Real Tests on Desktop Chrome (Default/Recommended)
To run real browser tests directly on your desktop Chrome (WebdriverManager manages chromedriver automatically):
```bash
python run_tests.py --desktop
```
This launches Chrome, executes the actions, and generates the report inside `reports/Web_Test_Execution_Report.xlsx`.

### 2. Run Real Tests on Mobile Chrome via Appium
Ensure your Appium server and Android Emulator/device are running, then run:
```bash
python run_tests.py
```

### 3. Generate Styled Report Verification (Dry Run)
To verify Excel formatting and creation without starting a browser session:
```bash
python report_generator.py --dry
```
This generates a mock report with all 105 tests inside `reports/Web_Test_Execution_Report.xlsx`.
