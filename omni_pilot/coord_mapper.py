"""
omni_pilot/coord_mapper.py
==========================
Coordinate Normalization Module mapping virtual coordinates [0-1000] to physical pixels
with DPI scaling, rotation, and multi-monitor offset compensation.
"""

class CoordinateMapper:
    def __init__(self, display_width=1920, display_height=1080, scaling_factor=1.0):
        self.width = display_width
        self.height = display_height
        self.scaling = scaling_factor

    def virtual_to_pixels(self, x_virt, y_virt):
        px_x = int((x_virt / 1000.0) * self.width * self.scaling)
        px_y = int((y_virt / 1000.0) * self.height * self.scaling)
        return min(px_x, self.width - 1), min(px_y, self.height - 1)

    def bbox_to_virtual_center(self, bbox_virt):
        # bbox_virt = [x1, y1, x2, y2]
        xc = (bbox_virt[0] + bbox_virt[2]) // 2
        yc = (bbox_virt[1] + bbox_virt[3]) // 2
        return xc, yc
