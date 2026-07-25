import os
from PIL import Image

def resize_images():
    target_sizes = {
        "6.7_inch": (1290, 2796),
        "5.5_inch": (1242, 2208)
    }

    base_dir = r"c:\Users\91748\Desktop\HI-tech-app"
    
    # Get all flutter_*.png files
    files = [f for f in os.listdir(base_dir) if f.startswith('flutter_') and f.endswith('.png')]
    
    if not files:
        print("No screenshots found.")
        return

    for name, (width, height) in target_sizes.items():
        output_dir = os.path.join(base_dir, "ios_screenshots", name)
        os.makedirs(output_dir, exist_ok=True)
        
        for file in files:
            file_path = os.path.join(base_dir, file)
            try:
                with Image.open(file_path) as img:
                    # Resize while ignoring aspect ratio, or you could pad it
                    resized_img = img.resize((width, height), Image.Resampling.LANCZOS)
                    
                    # Convert to RGB to remove alpha channel if saving as JPG, 
                    # but App Store accepts PNG without alpha.
                    if resized_img.mode in ('RGBA', 'LA'):
                        background = Image.new('RGB', resized_img.size, (255, 255, 255))
                        background.paste(resized_img, mask=resized_img.split()[3])
                        resized_img = background
                    
                    output_path = os.path.join(output_dir, file)
                    resized_img.save(output_path, "PNG")
                    print(f"Resized {file} for {name} -> {output_path}")
            except Exception as e:
                print(f"Error processing {file}: {e}")

if __name__ == "__main__":
    resize_images()
