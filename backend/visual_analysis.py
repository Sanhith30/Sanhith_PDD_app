import cv2
import numpy as np
import os
from PIL import Image

def analyze_lesion_image(image_path, model=None):
    """
    Extracts clinical visual features from an oral ulcer image.
    If 'model' (TensorFlow/Keras) is provided, it uses Deep Learning for scoring.
    Returns a 'visual_risk_score' (0-100) and specific visual flags.
    """
    if not os.path.exists(image_path):
        return 0, ["Image not found"]

    # Load image for heuristic analysis (OpenCV)
    img = cv2.imread(image_path)
    if img is None:
        return 0, ["Invalid image format"]

    # ---------------------------------------------------------
    # 1. DEEP LEARNING INFERENCE (If model is available)
    # ---------------------------------------------------------
    dl_score = 0
    if model is not None:
        try:
            # Preprocess image for MobileNetV2 (224x224)
            pil_img = Image.open(image_path).convert('RGB')
            pil_img = pil_img.resize((224, 224))
            img_array = np.array(pil_img) / 255.0
            img_array = np.expand_dims(img_array, axis=0)

            # Predict
            prediction = model.predict(img_array, verbose=0)[0][0]
            
            # The model was trained such that 0 = High Risk, 1 = Low Risk (alphabetical order)
            # OR sometimes vice-versa. Based on the user's provided code:
            # "if prediction < 0.5: return HIGH RISK"
            # So risk_score should be (1.0 - prediction) * 100
            dl_score = (1.0 - float(prediction)) * 100
        except Exception as e:
            print(f"DL Inference Error: {e}")

    # ---------------------------------------------------------
    # 2. HEURISTIC FLAGS (For Explanations)
    # ---------------------------------------------------------
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    visual_flags = []
    heuristic_score = 0

    # Redness
    avg_red = np.mean(img[:, :, 2])
    if avg_red > 150:
        heuristic_score += 20
        visual_flags.append("Intense Erythema Detected")

    # Surface Irregularity
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var > 500:
        heuristic_score += 25
        visual_flags.append("Irregular Surface Texture")

    # Edge Regularity
    edges = cv2.Canny(gray, 100, 200)
    edge_density = np.sum(edges > 0) / (edges.shape[0] * edges.shape[1])
    if edge_density > 0.05:
        heuristic_score += 25
        visual_flags.append("Ill-defined/Irregular Margins")

    # Homogeneity
    std_dev = np.std(gray)
    if std_dev > 40:
        heuristic_score += 15
        visual_flags.append("Non-homogeneous Lesion Appearance")

    # ---------------------------------------------------------
    # 3. FINAL COMBINATION
    # ---------------------------------------------------------
    if model is not None:
        # Use DL score as primary, but cap it at 100
        visual_score = min(dl_score, 100)
    else:
        # Fallback to heuristics
        visual_score = min(heuristic_score, 100)
    
    if not visual_flags:
        visual_flags.append("Homogeneous/Regular appearance")

    return visual_score, visual_flags

if __name__ == "__main__":
    # Test
    print("Visual Analysis module loaded.")
