#!/usr/bin/env python3
"""
PipeWire DMA-BUF Zero-Copy Stream Perception Engine.
Routes the Wayland compositor's screen/window buffers directly into numpy arrays at 60 FPS.
"""

import sys
import time
import logging
import traceback

try:
    import numpy as np
    import pipewire_capture as pw
except ImportError as e:
    print(f"Error importing required modules: {e}")
    print("Please ensure 'numpy' and 'pipewire-capture' are installed.")
    sys.exit(1)

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)

def run_vision_pipeline():
    logging.info("Initializing PipeWire ScreenCast Portal Capture...")
    portal = pw.PortalCapture()
    
    logging.info("Requesting screen/window selection via Portal (requires confirmation)...")
    # This invokes the desktop portal ScreenCast UI
    session = portal.select_window()
    if not session:
        logging.error("Failed to establish Portal Session: User cancelled or selection failed.")
        sys.exit(1)
        
    logging.info(f"Portal Session established. Stream specs: {session.width}x{session.height}, Node ID: {session.node_id}")
    
    # Initialize CaptureStream
    # capture_interval=0.01666 -> ~60 FPS
    stream = pw.CaptureStream(
        session.fd, 
        session.node_id, 
        session.width, 
        session.height, 
        capture_interval=0.01667
    )
    
    try:
        logging.info("Starting PipeWire DMA-BUF capture stream...")
        stream.start()
        
        logging.info("Entering 60fps frame consumption loop. Press Ctrl+C to terminate.")
        frame_count = 0
        start_time = time.monotonic()
        
        while True:
            loop_start = time.monotonic()
            
            # Dequeue raw memory-mapped frame directly from GPU pipeline
            frame = stream.get_frame()
            
            if frame is not None:
                frame_count += 1
                # frame is a numpy array of shape (height, width, 4) in BGRA format
                if frame_count % 60 == 0:
                    fps = frame_count / (time.monotonic() - start_time)
                    logging.info(
                        f"Captured {frame_count} frames. Current FPS: {fps:.2f}. "
                        f"Frame Shape: {frame.shape}, Data Type: {frame.dtype}, "
                        f"Mean Pixel Val: {np.mean(frame):.2f}"
                    )
            
            # Calculate sleep to maintain target 60 FPS
            elapsed = time.monotonic() - loop_start
            sleep_time = max(0.0, 0.01667 - elapsed)
            time.sleep(sleep_time)
            
    except KeyboardInterrupt:
        logging.info("Capture loop interrupted by operator.")
    except Exception as e:
        logging.error(f"Error in vision pipeline loop: {e}")
        logging.error(traceback.format_exc())
    finally:
        logging.info("Tearing down PipeWire Capture stream...")
        stream.stop()
        logging.info("Closing Portal Session...")
        session.close()
        logging.info("Vision pipeline cleanup complete.")

if __name__ == '__main__':
    run_vision_pipeline()
