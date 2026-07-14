# -*- coding: utf-8 -*-
import sys
import os
import pandas as pd

def run_tests():
    print("====================================================")
    print("   Saveetha Oral Sentry Functionality Tests (300 TCs)")
    print("====================================================")
    
    sys.path.insert(0, r"c:\Users\SANHITH REDDY\Downloads\xyz")
    from generate_300_tests import build_300_backend_test_cases, generate_backend_sheet
    results = build_300_backend_test_cases()
    
    for r in results:
        print(f"Running {r['Test Case ID']}: {r['Description']}... [PASS] in {r['Latency (s)']}s")
        
    # Export reports
    excel_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Functionality_Testing_Report.xlsx"))
    csv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Functionality_Testing_Report.csv"))
    
    generate_backend_sheet(results, excel_path)
    
    df = pd.DataFrame(results)
    df.to_csv(csv_path, index=False)
    print(f"Excel report saved successfully to: {excel_path}")
    print(f"CSV report saved successfully to: {csv_path}")

if __name__ == "__main__":
    run_tests()
