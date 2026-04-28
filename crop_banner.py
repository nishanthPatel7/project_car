from PIL import Image

# Open the generated image
img = Image.open("/Users/for10/.gemini/antigravity/brain/7ffbc531-eeb0-4ecf-8713-8cd185ebb4a7/autonex_feature_graphic_1777329962803.png")

# Calculate coordinates to crop the center 1024x500
width, height = img.size
new_width = 1024
new_height = 500

left = (width - new_width) / 2
top = (height - new_height) / 2
right = (width + new_width) / 2
bottom = (height + new_height) / 2

# Crop and save to Desktop
img_cropped = img.crop((left, top, right, bottom))
img_cropped.convert('RGB').save("/Users/for10/Desktop/AutoNex_FeatureGraphic.jpg", "JPEG", quality=95)
print("Saved to Desktop!")
