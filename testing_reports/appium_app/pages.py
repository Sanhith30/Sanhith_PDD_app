import time
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException

# ─────────────────────────────────────────────────────────────────
#  BASE PAGE — Shared Mobile Helpers
# ─────────────────────────────────────────────────────────────────
class BasePage:
    def __init__(self, driver):
        self.driver = driver

    def wait_for_element(self, locator_type, locator_value, timeout=8):
        """Waits for element to be visible and returns it, else None."""
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((locator_type, locator_value))
            )
        except TimeoutException:
            return None

    def wait_for_clickable(self, locator_type, locator_value, timeout=8):
        """Waits for element to be clickable and returns it, else None."""
        try:
            return WebDriverWait(self.driver, timeout).until(
                EC.element_to_be_clickable((locator_type, locator_value))
            )
        except TimeoutException:
            return None

    def find_element(self, locator_type, locator_value):
        """Finds element without wait; returns None on failure."""
        try:
            return self.driver.find_element(locator_type, locator_value)
        except Exception:
            return None

    def find_elements(self, locator_type, locator_value):
        """Finds all matching elements; returns empty list on failure."""
        try:
            return self.driver.find_elements(locator_type, locator_value)
        except Exception:
            return []

    def wait_for_element_with_scroll(self, locator_type, locator_value, timeout=8):
        """Finds an element, swiping/scrolling if not immediately present in viewport."""
        start_time = time.time()
        MAX_TOTAL_WAIT = 25

        # Attempt immediate find
        try:
            el = WebDriverWait(self.driver, 2).until(
                EC.presence_of_element_located((locator_type, locator_value))
            )
            return el
        except Exception:
            pass

        # Native Mobile Scroll/Swipe Loop
        for i in range(5):
            if time.time() - start_time > MAX_TOTAL_WAIT:
                break
            try:
                el = WebDriverWait(self.driver, 1.5).until(
                    EC.presence_of_element_located((locator_type, locator_value))
                )
                return el
            except Exception:
                # Perform a native swipe up (scrolls down)
                size = self.driver.get_window_size()
                start_x = int(size['width'] * 0.5)
                start_y = int(size['height'] * 0.8)
                end_x = int(size['width'] * 0.5)
                end_y = int(size['height'] * 0.3)
                
                try:
                    self.driver.swipe(start_x, start_y, end_x, end_y, 400)
                except Exception:
                    pass
                time.sleep(0.5)

        # Final attempt
        try:
            return WebDriverWait(self.driver, 2).until(
                EC.presence_of_element_located((locator_type, locator_value))
            )
        except Exception:
            return None

    def click_element(self, locator_type, locator_value, timeout=8):
        """Clicks element. Returns True on success."""
        element = self.wait_for_element_with_scroll(locator_type, locator_value, timeout)
        if not element:
            print(f"[DEBUG] Click failed: locator ({locator_type}, {locator_value}) NOT FOUND")
            return False
        try:
            element.click()
            print(f"[DEBUG] Clicked element: ({locator_type}, {locator_value})")
            return True
        except Exception as e:
            print(f"[DEBUG] Click failed with exception: {type(e).__name__}")
            # Try TouchAction/W3C Actions click if standard click fails
            try:
                from selenium.webdriver.common.action_chains import ActionChains
                ActionChains(self.driver).move_to_element(element).click().perform()
                return True
            except Exception:
                return False

    def input_text(self, locator_type, locator_value, text, timeout=8):
        """Clears field and types text. Returns True on success."""
        element = self.wait_for_element_with_scroll(locator_type, locator_value, timeout)
        if element:
            try:
                element.clear()
                element.send_keys(text)
                print(f"[DEBUG] Inputted text '{text}' into: ({locator_type}, {locator_value})")
                return True
            except Exception as e:
                print(f"[DEBUG] Input failed with exception: {type(e).__name__}")
                return False
        print(f"[DEBUG] Input field NOT FOUND: ({locator_type}, {locator_value})")
        return False

    def element_exists(self, locator_type, locator_value, timeout=3):
        """Returns True if element is present within timeout."""
        try:
            WebDriverWait(self.driver, timeout).until(
                EC.presence_of_element_located((locator_type, locator_value))
            )
            return True
        except TimeoutException:
            return False

    def page_loaded(self, keyword, timeout=8):
        """Checks if a keyword appears anywhere in the app page hierarchy."""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                # In Appium native, we look for text matching the keyword anywhere in the UI hierarchy
                xpath_query = f"//*[contains(@text, '{keyword}') or contains(@content-desc, '{keyword}')]"
                if self.element_exists(AppiumBy.XPATH, xpath_query, timeout=1.5):
                    return True
            except Exception:
                pass
            time.sleep(0.5)
        return False


# ─────────────────────────────────────────────────────────────────
#  SPLASH / ONBOARDING PAGES
# ─────────────────────────────────────────────────────────────────
class SplashPage(BasePage):
    SPLASH_DESC = "Oral Ulcer AI"

    def is_splash_visible(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, self.SPLASH_DESC, timeout=10)


class OnboardingPage(BasePage):
    SKIP_BTN = (AppiumBy.ACCESSIBILITY_ID, "Skip")
    GET_STARTED_BTN = (AppiumBy.ACCESSIBILITY_ID, "Get Started")
    CONTINUE_BTN = (AppiumBy.ACCESSIBILITY_ID, "Continue")

    def click_skip(self):
        return self.click_element(*self.SKIP_BTN)

    def click_get_started(self):
        return self.click_element(*self.GET_STARTED_BTN)

    def click_continue(self):
        return self.click_element(*self.CONTINUE_BTN)


# ─────────────────────────────────────────────────────────────────
#  AUTHENTICATION PAGES
# ─────────────────────────────────────────────────────────────────
class LoginPage(BasePage):
    SIGNUP_TOGGLE = (AppiumBy.ACCESSIBILITY_ID, "Sign up")
    EMAIL_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Email') or contains(@text, 'Email')]")
    PASSWORD_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Password') or contains(@text, 'Password')]")
    SIGNIN_BTN = (AppiumBy.ACCESSIBILITY_ID, "Sign In")

    # Sign-Up extra fields
    NAME_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Name') or contains(@text, 'Name')]")
    CONFIRM_PW_INPUT = (AppiumBy.XPATH, "(//android.widget.EditText[contains(@content-desc, 'Password') or contains(@text, 'Password')])[2]")
    CREATE_BTN = (AppiumBy.ACCESSIBILITY_ID, "Create Account")

    def login(self, email, password):
        self.input_text(*self.EMAIL_INPUT, email)
        self.input_text(*self.PASSWORD_INPUT, password)
        return self.click_element(*self.SIGNIN_BTN)

    def switch_to_signup(self):
        return self.click_element(*self.SIGNUP_TOGGLE)

    def register(self, name, email, password, confirm_pw):
        self.input_text(*self.NAME_INPUT, name)
        self.input_text(*self.EMAIL_INPUT, email)
        self.input_text(*self.PASSWORD_INPUT, password)
        self.input_text(*self.CONFIRM_PW_INPUT, confirm_pw)
        return self.click_element(*self.CREATE_BTN)


class ForgotPasswordPage(BasePage):
    EMAIL_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Email') or contains(@text, 'Email')]")
    SEND_OTP_BTN = (AppiumBy.ACCESSIBILITY_ID, "Send Verification")
    TIMER_TEXT = (AppiumBy.XPATH, "//*[contains(@text, 'Timer') or contains(@content-desc, 'Timer')]")
    SUGGEST_PW_BTN = (AppiumBy.ACCESSIBILITY_ID, "Suggest Password")
    OTP_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'OTP') or contains(@text, 'OTP')]")
    NEW_PASSWORD_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'New Password')]")
    RESET_BTN = (AppiumBy.ACCESSIBILITY_ID, "Reset Password")

    def request_otp(self, email):
        self.input_text(*self.EMAIL_INPUT, email)
        return self.click_element(*self.SEND_OTP_BTN)


class ChangePasswordPage(BasePage):
    CURRENT_PW = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Current Password')]")
    NEW_PW = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'New Password')]")
    CONFIRM_NEW_PW = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Confirm New Password')]")
    UPDATE_BTN = (AppiumBy.ACCESSIBILITY_ID, "Update Password")


# ─────────────────────────────────────────────────────────────────
#  NAVIGATION & LAYOUT
# ─────────────────────────────────────────────────────────────────
class NavigationPage(BasePage):
    DASHBOARD_TAB = (AppiumBy.ACCESSIBILITY_ID, "Dashboard")
    HISTORY_TAB = (AppiumBy.ACCESSIBILITY_ID, "History")
    ANALYTICS_TAB = (AppiumBy.ACCESSIBILITY_ID, "Analytics")
    PROFILE_TAB = (AppiumBy.ACCESSIBILITY_ID, "Profile")
    SETTINGS_TAB = (AppiumBy.ACCESSIBILITY_ID, "Settings")
    FAB_NEW_CASE = (AppiumBy.XPATH, "//android.widget.Button[@content-desc='New Case' or @text='+']")

    def go_to_dashboard(self): return self.click_element(*self.DASHBOARD_TAB)
    def go_to_history(self): return self.click_element(*self.HISTORY_TAB)
    def go_to_analytics(self): return self.click_element(*self.ANALYTICS_TAB)
    def go_to_profile(self): return self.click_element(*self.PROFILE_TAB)
    def go_to_settings(self): return self.click_element(*self.SETTINGS_TAB)
    def click_fab_new_case(self): return self.click_element(*self.FAB_NEW_CASE)


# ─────────────────────────────────────────────────────────────────
#  DASHBOARD PAGE
# ─────────────────────────────────────────────────────────────────
class DashboardPage(BasePage):
    greeting_desc = "Welcome"
    AI_STATUS = (AppiumBy.ACCESSIBILITY_ID, "AI Status")
    NOTIF_BELL = (AppiumBy.ACCESSIBILITY_ID, "Notifications")
    DOCTOR_AVATAR = (AppiumBy.ACCESSIBILITY_ID, "Doctor Profile")
    NEW_ASSESSMENT_CTA = (AppiumBy.ACCESSIBILITY_ID, "New Case Assessment")
    CASE_CARD = (AppiumBy.XPATH, "(//android.view.View[contains(@content-desc, 'PT')])[1]")

    def dashboard_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Notifications", timeout=10)


# ─────────────────────────────────────────────────────────────────
#  NEW CASE PAGE
# ─────────────────────────────────────────────────────────────────
class NewCasePage(BasePage):
    PATIENT_ID_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Patient ID')]")
    PATIENT_NAME = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Patient Name')]")
    AGE_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Age')]")
    SEX_DROPDOWN = (AppiumBy.ACCESSIBILITY_ID, "Sex")
    CONSENT_CB_1 = (AppiumBy.ACCESSIBILITY_ID, "Consent Checkbox")
    PROCEED_BTN = (AppiumBy.ACCESSIBILITY_ID, "Proceed")


# ─────────────────────────────────────────────────────────────────
#  IMAGE UPLOAD PAGE
# ─────────────────────────────────────────────────────────────────
class ImageUploadPage(BasePage):
    CAMERA_BTN = (AppiumBy.ACCESSIBILITY_ID, "Camera")
    GALLERY_BTN = (AppiumBy.ACCESSIBILITY_ID, "Gallery")
    PROCESS_BTN = (AppiumBy.ACCESSIBILITY_ID, "Process")


# ─────────────────────────────────────────────────────────────────
#  AI RESULT SCREEN
# ─────────────────────────────────────────────────────────────────
class AiResultPage(BasePage):
    RETURN_BTN = (AppiumBy.ACCESSIBILITY_ID, "Return to Dashboard")


# ─────────────────────────────────────────────────────────────────
#  HISTORY SCREEN
# ─────────────────────────────────────────────────────────────────
class HistoryPage(BasePage):
    SEARCH_BAR = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Search') or contains(@text, 'Search')]")
    CLEAR_SEARCH_BTN = (AppiumBy.ACCESSIBILITY_ID, "Clear")
    GRID_VIEW_TOGGLE = (AppiumBy.ACCESSIBILITY_ID, "Grid View")
    
    FILTER_ALL = (AppiumBy.ACCESSIBILITY_ID, "ALL")
    FILTER_HIGH = (AppiumBy.ACCESSIBILITY_ID, "HIGH")
    FILTER_INTER = (AppiumBy.ACCESSIBILITY_ID, "INTERMEDIATE")
    FILTER_LOW = (AppiumBy.ACCESSIBILITY_ID, "LOW")
    
    BIOPSY_FILTER = (AppiumBy.ACCESSIBILITY_ID, "Biopsy")
    DATE_FILTER_BTN = (AppiumBy.ACCESSIBILITY_ID, "Date")
    EXPORT_CSV_BTN = (AppiumBy.ACCESSIBILITY_ID, "Export CSV")
    
    FIRST_CASE = (AppiumBy.XPATH, "(//android.view.View[contains(@content-desc, 'PT') or contains(@content-desc, 'Case')])[1]")
    QUICK_VIEW_ITEM = (AppiumBy.ACCESSIBILITY_ID, "View Results")
    EDIT_PATIENT = (AppiumBy.ACCESSIBILITY_ID, "Edit")
    SELECT_ALL = (AppiumBy.ACCESSIBILITY_ID, "Select All")
    DEDUP_TOGGLE = (AppiumBy.ACCESSIBILITY_ID, "Deduplicate")

    def page_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Patient History", timeout=10)

    def search(self, query):
        return self.input_text(*self.SEARCH_BAR, query)

    def clear_search(self):
        return self.click_element(*self.CLEAR_SEARCH_BTN)

    def filter_high(self):
        return self.click_element(*self.FILTER_HIGH)

    def filter_intermediate(self):
        return self.click_element(*self.FILTER_INTER)

    def filter_low(self):
        return self.click_element(*self.FILTER_LOW)

    def toggle_biopsy_filter(self):
        return self.click_element(*self.BIOPSY_FILTER)

    def toggle_grid_view(self):
        return self.click_element(*self.GRID_VIEW_TOGGLE)

    def toggle_dedup(self):
        return self.click_element(*self.DEDUP_TOGGLE)

    def open_first_case_actions(self):
        return self.click_element(*self.FIRST_CASE)

    def long_press_first_case(self):
        el = self.wait_for_element_with_scroll(*self.FIRST_CASE)
        if el:
            try:
                from selenium.webdriver.common.action_chains import ActionChains
                actions = ActionChains(self.driver)
                actions.click_and_hold(el).pause(1.5).release().perform()
                return True
            except Exception:
                pass
        return False

    def export_csv(self):
        return self.click_element(*self.EXPORT_CSV_BTN)


# ─────────────────────────────────────────────────────────────────
#  CASE DETAIL SCREEN
# ─────────────────────────────────────────────────────────────────
class CaseDetailPage(BasePage):
    BACK_BTN = (AppiumBy.ACCESSIBILITY_ID, "Back")
    
    def page_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Case Detail", timeout=10)


# ─────────────────────────────────────────────────────────────────
#  ANALYTICS SCREEN
# ─────────────────────────────────────────────────────────────────
class AnalyticsPage(BasePage):
    RANGE_7D = (AppiumBy.ACCESSIBILITY_ID, "7D")
    RANGE_ALL = (AppiumBy.ACCESSIBILITY_ID, "ALL")
    SEARCH_INPUT = (AppiumBy.XPATH, "//android.widget.EditText[contains(@content-desc, 'Search') or contains(@text, 'Search')]")
    CHIP_INDURATED = (AppiumBy.ACCESSIBILITY_ID, "Indurated")
    TONGUE_TILE = (AppiumBy.ACCESSIBILITY_ID, "Tongue")
    HIGH_RISK_BOX = (AppiumBy.ACCESSIBILITY_ID, "High Risk")
    CLEAR_FILTERS = (AppiumBy.ACCESSIBILITY_ID, "Clear Filters")
    EXPORT_PDF_BTN = (AppiumBy.ACCESSIBILITY_ID, "Export PDF")

    def page_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Analytics Dashboard", timeout=10)

    def select_range_7d(self):
        return self.click_element(*self.RANGE_7D)

    def select_range_all(self):
        return self.click_element(*self.RANGE_ALL)

    def search(self, query):
        return self.input_text(*self.SEARCH_INPUT, query)

    def toggle_chip_indurated(self):
        return self.click_element(*self.CHIP_INDURATED)

    def click_tongue_heatmap(self):
        return self.click_element(*self.TONGUE_TILE)

    def click_high_risk_box(self):
        return self.click_element(*self.HIGH_RISK_BOX)

    def click_clear_filters(self):
        return self.click_element(*self.CLEAR_FILTERS)

    def export_pdf(self):
        return self.click_element(*self.EXPORT_PDF_BTN)


# ─────────────────────────────────────────────────────────────────
#  PROFILE SCREEN
# ─────────────────────────────────────────────────────────────────
class ProfilePage(BasePage):
    PROFILE_PHOTO = (AppiumBy.ACCESSIBILITY_ID, "Profile Photo")
    ACHIEVEMENT_BADGE = (AppiumBy.ACCESSIBILITY_ID, "Screening Rookie")
    VERIFIED_BADGE = (AppiumBy.ACCESSIBILITY_ID, "Verified License")
    DIGITAL_SIGNATURE = (AppiumBy.ACCESSIBILITY_ID, "Digital Signature")
    PRINT_ID_BADGE = (AppiumBy.ACCESSIBILITY_ID, "Print ID Badge")
    SIGN_OUT_BTN = (AppiumBy.ACCESSIBILITY_ID, "Sign Out")

    def page_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Profile Details", timeout=10)

    def click_profile_photo(self):
        return self.click_element(*self.PROFILE_PHOTO)

    def click_achievement_badge(self):
        return self.click_element(*self.ACHIEVEMENT_BADGE)

    def click_verified_badge(self):
        return self.click_element(*self.VERIFIED_BADGE)

    def click_digital_signature(self):
        return self.click_element(*self.DIGITAL_SIGNATURE)

    def click_print_id_badge(self):
        return self.click_element(*self.PRINT_ID_BADGE)

    def sign_out(self):
        return self.click_element(*self.SIGN_OUT_BTN)


# ─────────────────────────────────────────────────────────────────
#  SETTINGS SCREEN
# ─────────────────────────────────────────────────────────────────
class SettingsPage(BasePage):
    HIGH_RISK_BANNER_SWITCH = (AppiumBy.ACCESSIBILITY_ID, "High-Risk Alert Banner")
    COMPACT_LIST_SWITCH = (AppiumBy.ACCESSIBILITY_ID, "Compact Case List")
    DEPT_DROPDOWN = (AppiumBy.ACCESSIBILITY_ID, "Department")
    SIGNATURE_LINE_SWITCH = (AppiumBy.ACCESSIBILITY_ID, "Include Signature Line")
    DIGITAL_CONSENT_SWITCH = (AppiumBy.ACCESSIBILITY_ID, "Require Digital Consent")
    CLEAR_CACHE_TILE = (AppiumBy.ACCESSIBILITY_ID, "Clear Offline Cache")
    PING_SERVER_TILE = (AppiumBy.ACCESSIBILITY_ID, "Live Connection Ping")

    def page_loaded(self):
        return self.element_exists(AppiumBy.ACCESSIBILITY_ID, "Application Settings", timeout=10)

    def toggle_high_risk_banner(self):
        return self.click_element(*self.HIGH_RISK_BANNER_SWITCH)

    def toggle_compact_list(self):
        return self.click_element(*self.COMPACT_LIST_SWITCH)

    def select_department(self, dept):
        if self.click_element(*self.DEPT_DROPDOWN):
            time.sleep(1)
            return self.click_element(AppiumBy.ACCESSIBILITY_ID, dept)
        return False

    def toggle_signature_line(self):
        return self.click_element(*self.SIGNATURE_LINE_SWITCH)

    def toggle_digital_consent(self):
        return self.click_element(*self.DIGITAL_CONSENT_SWITCH)

    def click_clear_cache(self):
        return self.click_element(*self.CLEAR_CACHE_TILE)

    def ping_server(self):
        return self.click_element(*self.PING_SERVER_TILE)
