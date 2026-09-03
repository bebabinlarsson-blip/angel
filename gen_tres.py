import uuid
import os

def gen_uid():
    return "uid://" + uuid.uuid4().hex[:12]

def create_spriteframes(name, texture_path, frame_w, frame_h, animations, fps=30):
    # animations is a dict: {"anim_name": {"row": 0, "count": 4, "loop": True}, ...}
    lines = []
    lines.append(f'[gd_resource type="SpriteFrames" load_steps=999 format=3]')
    lines.append('')
    lines.append(f'[ext_resource type="Texture2D" path="{texture_path}" id="1_tex"]')
    lines.append('')
    
    sub_resources = []
    anim_frames = {}
    
    res_id = 2
    for anim_name, data in animations.items():
        row = data["row"]
        count = data["count"]
        anim_frames[anim_name] = []
        for col in range(count):
            x = col * frame_w
            y = row * frame_h
            sub_id = f"AtlasTexture_{res_id}"
            res_id += 1
            
            sub_resources.append(f'[sub_resource type="AtlasTexture" id="{sub_id}"]')
            sub_resources.append(f'atlas = ExtResource("1_tex")')
            sub_resources.append(f'region = Rect2({x}, {y}, {frame_w}, {frame_h})')
            sub_resources.append('')
            
            anim_frames[anim_name].append(sub_id)
            
    lines.extend(sub_resources)
    lines.append('[resource]')
    lines.append('animations = [')
    
    first_anim = True
    for anim_name, data in animations.items():
        if not first_anim:
            lines[-1] += ','
        first_anim = False
        
        lines.append('{')
        lines.append(f'"frames": [')
        
        frames = anim_frames[anim_name]
        for i, sub_id in enumerate(frames):
            comma = "," if i < len(frames) - 1 else ""
            lines.append('{\n"duration": 1.0,\n"texture": SubResource("' + sub_id + '")\n}' + comma)
            
        loop_str = "true" if data.get("loop", True) else "false"
        speed = fps
        
        lines.append(f'],')
        lines.append(f'"loop": {loop_str},')
        lines.append(f'"name": &"{anim_name}",')
        lines.append(f'"speed": {speed}.0')
        lines.append('}')
        
    lines.append(']')
    
    return "\n".join(lines)

def main():
    player_anims = {
        "idle": {"row": 0, "count": 4, "loop": True},
        "walk": {"row": 1, "count": 8, "loop": True},
        "attack": {"row": 2, "count": 6, "loop": False},
        "dash": {"row": 3, "count": 4, "loop": False},
        "hurt": {"row": 4, "count": 4, "loop": False},
    }
    with open("assets/sprites/player_frames.tres", "w") as f:
        f.write(create_spriteframes("player", "res://assets/sprites/player.png", 64, 64, player_anims))
        
    slime_anims = {
        "idle": {"row": 0, "count": 4, "loop": True},
        "move": {"row": 1, "count": 6, "loop": True},
        "hurt": {"row": 2, "count": 2, "loop": False},
    }
    with open("assets/sprites/slime_frames.tres", "w") as f:
        f.write(create_spriteframes("slime", "res://assets/sprites/slime.png", 32, 32, slime_anims))
        
    npc_anims = {
        "idle": {"row": 0, "count": 4, "loop": True},
    }
    with open("assets/sprites/npc_frames.tres", "w") as f:
        f.write(create_spriteframes("npc", "res://assets/sprites/npc.png", 32, 32, npc_anims))

if __name__ == "__main__":
    main()
