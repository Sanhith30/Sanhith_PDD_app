# -*- coding: utf-8 -*-
import sys
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

import time
from test_cases import run_mobile_suite
from report_generator import generate_report

def main():
    print("=" * 55)
    print("  STARTING NATIVE MOBILE E2E AUTOMATION TEST RUNNER")
    print("=" * 55 + "\n")

    # Warmup the Hugging Face Space backend to prevent cold-start timeouts
    print("Warming up the live Hugging Face backend API to prevent cold-start timeouts...")
    try:
        import urllib.request
        req = urllib.request.Request(
            "https://sanhith30-oral-ulcer-ai-backend.hf.space/",
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            print(f"Backend responded with status: {r.getcode()} (Warmup complete)\n")
    except Exception as e:
        print(f"Warning: Warmup request encountered an error (might be already warm or temporary issue): {e}\n")

    start_time = time.time()
    try:
        # Run test cases
        results = run_mobile_suite()

        print("\n" + "=" * 50)
        print("All Mobile tests completed. Compiling Excel report...")
        print("=" * 50)

        # Generate excel sheet
        generate_report(results, "Mobile_Test_Execution_Report.xlsx")

        total_duration = time.time() - start_time
        passed_count = sum(1 for r in results if r["status"] == "PASS")
        failed_count = sum(1 for r in results if r["status"] == "FAIL")

        print("EXECUTION SUMMARY:")
        print(f"   - Total Test Cases: {len(results)}")
        print(f"   - Passed: {passed_count}")
        print(f"   - Failed: {failed_count}")
        print(f"   - Total Duration: {total_duration:.2f}s\n")

    except Exception as e:
        print(f"Critical failure running automated test runner: {e}")

if __name__ == "__main__":
    main()
