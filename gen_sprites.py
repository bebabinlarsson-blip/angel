import os
from PIL import Image, ImageDraw

def generate_player():
    img = Image.new('RGBA', (512, 320), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Player base color: blue body, pink head
    for row in range(5):
        frames = [4, 8, 6, 4, 4][row]
        for col in range(frames):
            x = col * 64
            y = row * 64
            # Draw a simple character
            draw.rectangle([x+16, y+32, x+48, y+60], fill=(50, 100, 200, 255)) # body
            draw.rectangle([x+20, y+16, x+44, y+32], fill=(255, 150, 150, 255)) # head
            
            # Action specifics
            if row == 0: # Idle: bouncing head
                offset = (col % 2) * 2
                draw.rectangle([x+16, y+32, x+48, y+60], fill=(50, 100, 200, 255))
                draw.rectangle([x+20, y+16+offset, x+44, y+32+offset], fill=(255, 150, 150, 255))
            elif row == 1: # Walk: moving legs
                offset = (col % 4) * 2
                draw.rectangle([x+20, y+64-offset, x+30, y+64], fill=(40, 80, 160, 255))
                draw.rectangle([x+34, y+60, x+44, y+64+offset], fill=(40, 80, 160, 255))
            elif row == 2: # Attack: sword
                draw.rectangle([x+48, y+32, x+48 + col*4, y+36], fill=(200, 200, 200, 255))
            elif row == 3: # Dash: tilted
                draw.rectangle([x+10, y+32, x+42, y+60], fill=(50, 100, 200, 255))
            elif row == 4: # Hurt: red overlay
                draw.rectangle([x+16, y+32, x+48, y+60], fill=(255, 50, 50, 255))
                draw.rectangle([x+20, y+16, x+44, y+32], fill=(255, 100, 100, 255))

    img.save('assets/sprites/player.png')

def generate_slime():
    img = Image.new('RGBA', (192, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for row in range(3):
        frames = [4, 6, 2][row]
        for col in range(frames):
            x = col * 32
            y = row * 32
            
            if row == 0: # Idle
                height = 20 - (col % 2) * 2
                draw.ellipse([x+4, y+32-height, x+28, y+32], fill=(50, 200, 50, 255))
            elif row == 1: # Jump
                y_off = 10 if col % 2 == 1 else 0
                draw.ellipse([x+4, y+32-20-y_off, x+28, y+32-y_off], fill=(50, 200, 50, 255))
            elif row == 2: # Hurt
                draw.ellipse([x+4, y+12, x+28, y+32], fill=(200, 50, 50, 255))

    img.save('assets/sprites/slime.png')

def generate_npc():
    img = Image.new('RGBA', (128, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for col in range(4):
        x = col * 32
        y = 0
        offset = (col % 2) * 2
        draw.rectangle([x+8, y+16, x+24, y+30], fill=(150, 100, 50, 255)) # body
        draw.rectangle([x+10, y+8+offset, x+22, y+16+offset], fill=(255, 200, 150, 255)) # head
    img.save('assets/sprites/npc.png')

os.makedirs('assets/sprites', exist_ok=True)
generate_player()
generate_slime()
generate_npc()
print("Sprites generated.")
