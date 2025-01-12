from PIL import Image, ImageOps
import numpy as np
import sys

def png_to_rgb_24b(file_path):
    # Open the image file
    with Image.open(file_path) as img:
        # Convert the image to RGBA format
        img = img.convert('RGBA')
        img_with_border = ImageOps.expand(img, border=1, fill='white')
        # Get the image data as a numpy array
        img_data = np.array(img_with_border)
        # Convert the image data to 32-bit RGB values, ignoring the alpha channel
        rgb_array = (img_data[:, :, 0].astype(np.uint32) << 16) | (img_data[:, :, 1].astype(np.uint32) << 8) | img_data[:, :, 2].astype(np.uint32)
        return rgb_array

def png_to_rgb_8b(file_path):
    # Open the image file
    with Image.open(file_path) as img:
        # Convert the image to RGBA format
        img = img.convert('RGBA')
        img_with_border = ImageOps.expand(img, border=1, fill='white')
        # Get the image data as a numpy array
        img_data = np.array(img_with_border)

        # Convert the image data to 8-bit 3-3-2 RGB format
        r = (img_data[:, :, 0].astype(np.uint32) >> 5) & 0b111
        g = (img_data[:, :, 1].astype(np.uint32) >> 5) & 0b111
        b = (img_data[:, :, 2].astype(np.uint32) >> 6) & 0b11
        rgb_8b = (r << 5) | (g << 2) | b
        
        # Create a new image from the 8-bit data
        #img_8b = Image.fromarray(rgb_8b.astype(np.uint8), 'P')
        
        return rgb_8b
    
def to_rust_array_u32(name, rgb_array):
    height, width = rgb_array.shape
    rarr = f"const {name}: [[u32; TILE_SIZE]; TILE_SIZE] = [\n"
    for row in rgb_array:
        rarr += "    ["
        rarr += ", ".join("0x{:08X}".format(value) for value in row)
        rarr += "],\n"
        pass
    rarr += "];\n"
    return rarr

def to_rust_array_u8(name, rgb_array):
    height, width = rgb_array.shape
    rarr = f"const {name}: [[u8; TILE_SIZE]; TILE_SIZE] = [\n"
    for row in rgb_array:
        rarr += "    ["
        rarr += ", ".join("0x{:02X}".format(value) for value in row)
        rarr += "],\n"
        pass
    rarr += "];\n"
    return rarr


files = [
    ('RED','cc-red.png'),
    ('ORANGE','cc-orange.png'),
    ('YELLOW','cc-yellow.png'),
    ('GREEN','cc-green.png'),
    ('BLUE','cc-blue.png'),
    ('PURPLE','cc-purple.png'),
]

with open('candies-24b.rs', 'w') as out_24b:
    out_24b.write('// NB: this file is auto-generated, do not edit!\n\n')
    for (name,image_file) in files:
        ra = to_rust_array_u32(name, png_to_rgb_24b(image_file))
        out_24b.write(ra)
        pass
    pass

with open('candies-8b.rs', 'w') as out_8b:
    out_8b.write('// NB: this file is auto-generated, do not edit!\n\n')
    for (name,image_file) in files:
        ra = to_rust_array_u8(name, png_to_rgb_8b(image_file))
        out_8b.write(ra)
        pass
    pass
