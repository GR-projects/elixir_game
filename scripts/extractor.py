from PIL import Image
import os

def extract_spritesheet(image_path, output_folder, sprite_size=32):
    # Open the image
    img = Image.open(image_path)
    width, height = img.size

    # Ensure the output directory exists
    os.makedirs(output_folder, exist_ok=True)

    # Calculate the number of sprites in rows and columns
    cols = width // sprite_size
    rows = height // sprite_size

    # Extract each sprite
    for row in range(rows):
        for col in range(cols):
            left = col * sprite_size
            upper = row * sprite_size
            right = left + sprite_size
            lower = upper + sprite_size

            # Crop the sprite
            sprite = img.crop((left, upper, right, lower))

            # Save the sprite
            sprite.save(os.path.join(output_folder, f"sprite_{row}_{col}.png"))

    print(f"Extracted {rows * cols} sprites to {output_folder}")

# Example usage
extract_spritesheet("icons.png", "output_sprites")

