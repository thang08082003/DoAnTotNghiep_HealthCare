"""
Flask API - Cascade Pneumonia Detection
========================================
UNet + Mask R-CNN API for mobile applications

MUST RUN WITH Python 3.9 (venv39):
    .\venv39\Scripts\Activate.ps1
    python api_maskrcnn_cascade.py

Endpoints:
    POST /detect - Detect pneumonia in uploaded image
    GET /health - Health check
"""

import os
import io
import base64
import warnings
warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import numpy as np
import cv2
from pathlib import Path
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from PIL import Image
import threading

import tensorflow as tf
tf.get_logger().setLevel('ERROR')
tf.compat.v1.disable_eager_execution()
from tensorflow.compat.v1.keras import backend as K

# Mask R-CNN
from mrcnn import model as modellib
from mrcnn.config import Config

# ============================================================================
# CONFIG
# ============================================================================

UNET_MODEL_PATH = Path("D:/monaiyolo/unet_lung_seg.hdf5")
MASKRCNN_MODEL_PATH = Path("D:/monaiyolo/mask_rcnn_pneumonia_0015.h5")
IMG_SIZE_UNET = 512
ORIG_SIZE = 1024

# ============================================================================
# MASK R-CNN CONFIG
# ============================================================================

class PneumoniaConfig(Config):
    NAME = "pneumonia"
    GPU_COUNT = 1
    IMAGES_PER_GPU = 1
    NUM_CLASSES = 2
    IMAGE_MIN_DIM = 512
    IMAGE_MAX_DIM = 512
    RPN_ANCHOR_SCALES = (32, 64, 128, 256, 512)
    DETECTION_MIN_CONFIDENCE = 0.05

class InferenceConfig(PneumoniaConfig):
    GPU_COUNT = 1
    IMAGES_PER_GPU = 1

# ============================================================================
# FLASK APP
# ============================================================================

app = Flask(__name__)
CORS(app)  # Enable CORS for mobile apps

# Global model holders
unet_holder = None
maskrcnn_holder = None
model_lock = threading.Lock()

# ============================================================================
# MODEL LOADING
# ============================================================================

def load_unet_model():
    """Load UNet segmentation model."""
    try:
        holder = {}
        g = tf.Graph()
        with g.as_default():
            sess = tf.compat.v1.Session(graph=g)
            with sess.as_default():
                m = tf.keras.models.load_model(str(UNET_MODEL_PATH), compile=False)
                K.set_session(sess)
        holder['graph'] = g
        holder['sess'] = sess
        holder['model'] = m
        return holder, None
    except Exception as e:
        return None, str(e)

def load_maskrcnn_model():
    """Load Mask R-CNN detection model."""
    try:
        holder = {}
        g = tf.Graph()
        with g.as_default():
            sess = tf.compat.v1.Session(graph=g)
            with sess.as_default():
                K.set_session(sess)
                config = InferenceConfig()
                m = modellib.MaskRCNN(mode='inference', config=config, model_dir='.')
                m.load_weights(str(MASKRCNN_MODEL_PATH), by_name=True)
        holder['graph'] = g
        holder['sess'] = sess
        holder['model'] = m
        return holder, None
    except Exception as e:
        return None, str(e)

def initialize_models():
    """Initialize both models at startup."""
    global unet_holder, maskrcnn_holder
    
    print("Loading UNet model...")
    unet_holder, unet_error = load_unet_model()
    if unet_error:
        print(f"UNet load error: {unet_error}")
    else:
        print("UNet loaded successfully")
    
    print("Loading Mask R-CNN model...")
    maskrcnn_holder, maskrcnn_error = load_maskrcnn_model()
    if maskrcnn_error:
        print(f"Mask R-CNN load error: {maskrcnn_error}")
    else:
        print("Mask R-CNN loaded successfully")

# ============================================================================
# IMAGE PROCESSING
# ============================================================================

def load_image_from_bytes(file_bytes, filename):
    """Load image from bytes."""
    try:
        if filename.lower().endswith('.dcm'):
            import pydicom
            ds = pydicom.dcmread(io.BytesIO(file_bytes))
            image = ds.pixel_array.astype(np.float32)
            image = (image - image.min()) / (image.max() - image.min() + 1e-8) * 255
            return image.astype(np.uint8)
        else:
            image = Image.open(io.BytesIO(file_bytes))
            return np.array(image.convert('L'))
    except Exception as e:
        return None

def load_image_from_base64(base64_str):
    """Load image from base64 string."""
    try:
        # Remove data URL prefix if present
        if ',' in base64_str:
            base64_str = base64_str.split(',')[1]
        
        image_bytes = base64.b64decode(base64_str)
        image = Image.open(io.BytesIO(image_bytes))
        return np.array(image.convert('L'))
    except Exception as e:
        return None

def segment_lungs(holder, image):
    """Segment lungs using UNet model."""
    sess = holder['sess']
    graph = holder['graph']
    model = holder['model']

    original_size = image.shape[:2]
    resized = cv2.resize(image, (IMG_SIZE_UNET, IMG_SIZE_UNET))
    normalized = resized.astype(np.float32) / 255.0
    input_data = normalized.reshape(1, IMG_SIZE_UNET, IMG_SIZE_UNET, 1)
    
    with graph.as_default():
        with sess.as_default():
            K.set_session(sess)
            prediction = model.predict(input_data, verbose=0)
    
    mask = prediction[0, :, :, 0]
    mask = (mask > 0.5).astype(np.uint8) * 255
    mask = cv2.resize(mask, (original_size[1], original_size[0]), interpolation=cv2.INTER_NEAREST)
    return mask

def detect_pneumonia_maskrcnn(holder, image, conf_threshold=0.5):
    """Detect pneumonia using Mask R-CNN."""
    sess = holder['sess']
    graph = holder['graph']
    model = holder['model']

    original_size = image.shape[:2]

    if len(image.shape) == 2:
        rgb = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
    else:
        rgb = image

    with graph.as_default():
        with sess.as_default():
            K.set_session(sess)
            results = model.detect([rgb], verbose=0)[0]
    
    detections = []
    for i in range(len(results['rois'])):
        if results['scores'][i] >= conf_threshold:
            y1, x1, y2, x2 = results['rois'][i]
            
            x1_orig = max(0, min(original_size[1]-1, int(x1)))
            x2_orig = max(0, min(original_size[1]-1, int(x2)))
            y1_orig = max(0, min(original_size[0]-1, int(y1)))
            y2_orig = max(0, min(original_size[0]-1, int(y2)))

            mask_resized = None
            if results['masks'].size > 0:
                mask_resized = results['masks'][:, :, i].astype(np.uint8)

            detections.append({
                'bbox': (x1_orig, y1_orig, x2_orig, y2_orig),
                'confidence': float(results['scores'][i]),
                'mask': mask_resized
            })
    
    return detections

def create_visualization(image, lung_mask, detections, show_lung_mask=True, alpha=0.4):
    """Create visualization with detections."""
    if len(image.shape) == 2:
        output = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
    else:
        output = image.copy()
    
    if show_lung_mask and lung_mask is not None:
        lung_overlay = np.zeros_like(output)
        lung_overlay[lung_mask > 127] = (0, 200, 0)
        output = cv2.addWeighted(output, 1, lung_overlay, alpha * 0.5, 0)
    
    for det in detections:
        if det.get('mask') is not None:
            mask_overlay = np.zeros_like(output)
            mask_overlay[det['mask'] > 0] = (255, 50, 50)
            output = cv2.addWeighted(output, 1, mask_overlay, alpha, 0)
        
        x1, y1, x2, y2 = det['bbox']
        cv2.rectangle(output, (x1, y1), (x2, y2), (255, 0, 0), 3)
        
        label = f"Pneumonia: {det['confidence']:.0%}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
        cv2.rectangle(output, (x1, y1 - th - 10), (x1 + tw + 10, y1), (255, 0, 0), -1)
        cv2.putText(output, label, (x1 + 5, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    
    return output

def image_to_base64(image):
    """Convert numpy image to base64 string."""
    if len(image.shape) == 3:
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    else:
        image_rgb = image
    
    pil_image = Image.fromarray(image_rgb)
    buffer = io.BytesIO()
    pil_image.save(buffer, format='PNG')
    buffer.seek(0)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'ok',
        'unet_loaded': unet_holder is not None,
        'maskrcnn_loaded': maskrcnn_holder is not None
    })

@app.route('/detect', methods=['POST'])
def detect_pneumonia():
    """
    Detect pneumonia in uploaded chest X-ray.
    
    Request (multipart/form-data):
        - image: Image file (PNG, JPG, JPEG, DCM)
        - confidence: Detection confidence threshold (0.05-1.0, default: 0.1)
        - use_segmentation: Use lung segmentation (true/false, default: true)
        - show_lung_mask: Show lung mask overlay (true/false, default: true)
        - overlay_alpha: Overlay transparency (0.1-0.7, default: 0.4)
        - return_format: Response format ('json' or 'image', default: 'json')
    
    Request (JSON with base64):
        {
            "image_base64": "base64_encoded_image",
            "confidence": 0.1,
            "use_segmentation": true,
            "show_lung_mask": true,
            "overlay_alpha": 0.4,
            "return_format": "json"
        }
    
    Response (JSON):
        {
            "success": true,
            "detections": [
                {
                    "bbox": [x1, y1, x2, y2],
                    "confidence": 0.85
                }
            ],
            "num_detections": 1,
            "result_image_base64": "base64_encoded_result_image",
            "original_image_base64": "base64_encoded_original_image",
            "lung_coverage": 75.5,
            "image_size": {"width": 1024, "height": 1024}
        }
    
    Response (Image):
        Returns the result image directly as PNG
    """
    global unet_holder, maskrcnn_holder
    
    try:
        # Check if models are loaded
        if maskrcnn_holder is None:
            return jsonify({
                'success': False,
                'error': 'Mask R-CNN model not loaded'
            }), 500
        
        # Parse request parameters
        if request.is_json:
            # JSON request with base64 image
            data = request.get_json()
            image_base64 = data.get('image_base64')
            if not image_base64:
                return jsonify({
                    'success': False,
                    'error': 'No image_base64 provided'
                }), 400
            
            image = load_image_from_base64(image_base64)
            if image is None:
                return jsonify({
                    'success': False,
                    'error': 'Failed to decode base64 image'
                }), 400
            
            confidence = float(data.get('confidence', 0.1))
            use_segmentation = data.get('use_segmentation', True)
            show_lung_mask = data.get('show_lung_mask', True)
            overlay_alpha = float(data.get('overlay_alpha', 0.4))
            return_format = data.get('return_format', 'json')
        else:
            # Multipart form-data with file upload
            if 'image' not in request.files:
                return jsonify({
                    'success': False,
                    'error': 'No image file provided'
                }), 400
            
            file = request.files['image']
            if file.filename == '':
                return jsonify({
                    'success': False,
                    'error': 'No file selected'
                }), 400
            
            file_bytes = file.read()
            image = load_image_from_bytes(file_bytes, file.filename)
            if image is None:
                return jsonify({
                    'success': False,
                    'error': 'Failed to load image'
                }), 400
            
            confidence = float(request.form.get('confidence', 0.1))
            use_segmentation = request.form.get('use_segmentation', 'true').lower() == 'true'
            show_lung_mask = request.form.get('show_lung_mask', 'true').lower() == 'true'
            overlay_alpha = float(request.form.get('overlay_alpha', 0.4))
            return_format = request.form.get('return_format', 'json')
        
        # Validate parameters
        confidence = max(0.05, min(1.0, confidence))
        overlay_alpha = max(0.1, min(0.7, overlay_alpha))
        
        # Process with thread lock to avoid TensorFlow issues
        with model_lock:
            # Lung segmentation
            if use_segmentation and unet_holder is not None:
                lung_mask = segment_lungs(unet_holder, image)
            else:
                lung_mask = np.ones_like(image) * 255
            
            # Pneumonia detection
            detections = detect_pneumonia_maskrcnn(maskrcnn_holder, image, confidence)
        
        # Create visualization
        result_image = create_visualization(image, lung_mask, detections, show_lung_mask, overlay_alpha)
        
        # Calculate lung coverage
        lung_coverage = np.sum(lung_mask > 127) / (lung_mask.shape[0] * lung_mask.shape[1]) * 100
        
        # Prepare detections for JSON (remove mask arrays)
        detections_json = []
        for det in detections:
            detections_json.append({
                'bbox': list(det['bbox']),
                'confidence': det['confidence']
            })
        
        # Return response
        if return_format == 'image':
            # Return image directly
            result_pil = Image.fromarray(cv2.cvtColor(result_image, cv2.COLOR_BGR2RGB))
            buffer = io.BytesIO()
            result_pil.save(buffer, format='PNG')
            buffer.seek(0)
            return send_file(buffer, mimetype='image/png')
        else:
            # Return JSON with base64 images
            return jsonify({
                'success': True,
                'detections': detections_json,
                'num_detections': len(detections),
                'result_image_base64': image_to_base64(result_image),
                'original_image_base64': image_to_base64(image),
                'lung_coverage': round(lung_coverage, 2),
                'image_size': {
                    'width': image.shape[1],
                    'height': image.shape[0]
                }
            })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/detect/image', methods=['POST'])
def detect_pneumonia_image_only():
    """
    Same as /detect but always returns the result image directly.
    Useful for simple mobile implementations.
    """
    # Set return_format to image
    if request.is_json:
        data = request.get_json()
        data['return_format'] = 'image'
        # Create a new request with modified data
        request._cached_json = (data, data)
    else:
        request.form = request.form.copy()
        request.form['return_format'] = 'image'
    
    return detect_pneumonia()

@app.route('/models/info', methods=['GET'])
def models_info():
    """Get information about loaded models."""
    return jsonify({
        'models': {
            'unet': {
                'loaded': unet_holder is not None,
                'path': str(UNET_MODEL_PATH),
                'purpose': 'Lung Segmentation'
            },
            'maskrcnn': {
                'loaded': maskrcnn_holder is not None,
                'path': str(MASKRCNN_MODEL_PATH),
                'purpose': 'Pneumonia Detection'
            }
        },
        'supported_formats': ['png', 'jpg', 'jpeg', 'dcm'],
        'default_settings': {
            'confidence': 0.1,
            'use_segmentation': True,
            'show_lung_mask': True,
            'overlay_alpha': 0.4
        }
    })

# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("Flask API - Cascade Pneumonia Detection")
    print("UNet + Mask R-CNN")
    print("=" * 60)
    
    # Initialize models
    initialize_models()
    
    print("\nStarting Flask server...")
    print("API Endpoints:")
    print("  - GET  /health       : Health check")
    print("  - GET  /models/info  : Model information")
    print("  - POST /detect       : Detect pneumonia (JSON or form-data)")
    print("  - POST /detect/image : Detect and return image directly")
    print("\nServer running at http://0.0.0.0:5000")
    print("=" * 60)
    
    # Run Flask app
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
