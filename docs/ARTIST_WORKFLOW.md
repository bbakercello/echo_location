# Artist Workflow - How to Create Assets for EchoLocation

## How Artists Work with Godot

### Overview
Artists create 3D models, textures, and other assets in external tools (like Blender, Maya, etc.), then import them into Godot. Godot doesn't create the art - it uses art created elsewhere.

---

## The Workflow

### 1. **Artist Creates Assets** (Outside Godot)
- **3D Models**: Created in Blender, Maya, 3ds Max, etc.
- **Textures**: Created in Photoshop, Substance Painter, etc.
- **Export Format**: Usually `.glb` or `.gltf` (modern standard) or `.obj` (older but still works)

### 2. **Import into Godot**
- Place files in `assets/models/` folder
- Godot automatically detects and imports them
- You'll see `.import` files created (these are Godot's import settings)

### 3. **Use in Scenes**
- Drag the imported model from FileSystem into your scene
- Or instance it via code
- Adjust materials, position, scale as needed

---

## File Structure

```
assets/
├── models/          # 3D models (.glb, .gltf, .obj)
│   ├── tree.glb
│   ├── rock.glb
│   └── structure.glb
├── textures/        # Texture images (.png, .jpg)
│   ├── tree_bark.png
│   └── ground_dirt.png
└── sprites/         # 2D sprites if needed
```

---

## Common 3D Model Formats

### **GLB/GLTF** (Recommended)
- Modern, efficient format
- Includes textures, materials, animations
- Single file (GLB) or multiple files (GLTF)
- Best for Godot

### **OBJ**
- Older format, still widely used
- Simple geometry only
- Materials/textures separate
- Works fine but less features

### **FBX**
- Industry standard
- Supports animations
- Can be larger files
- Works well with Godot

---

## What Artists Need to Know

### For 3D Models:
1. **Scale**: Make sure models are the right size (Godot uses meters)
   - A character should be ~1.5-2 meters tall
   - A tree might be 5-10 meters
   - Test in Godot to verify scale

2. **Origin Point**: Models should be at (0,0,0) in their software
   - Makes placement easier in Godot

3. **Materials**: 
   - Can create materials in Blender/Maya
   - Or create materials in Godot after import
   - Textures should be separate image files

4. **Optimization**:
   - Keep polygon count reasonable
   - Use textures efficiently
   - Consider LOD (Level of Detail) for distant objects

### For Textures:
- **Resolution**: 512x512, 1024x1024, 2048x2048 (powers of 2)
- **Format**: PNG (with transparency) or JPG (no transparency)
- **Naming**: Clear names like `tree_bark_diffuse.png`, `rock_normal.png`

---

## Example: Adding a New Model

1. **Artist creates model** in Blender
   - Models a tree, exports as `tree.glb`
   
2. **Place in project**:
   - Copy `tree.glb` to `assets/models/`
   
3. **Godot imports it**:
   - Automatically creates `tree.glb.import` file
   - Model appears in FileSystem panel
   
4. **Use in scene**:
   - Open TestArea.tscn
   - Drag `tree.glb` from FileSystem into scene
   - Position it where you want
   - Done!

---

## Materials in Godot

### Two Approaches:

**Option 1: Materials from Blender/Maya**
- Artist creates materials in their software
- Exports with model
- Materials come through automatically (if format supports it)

**Option 2: Materials in Godot**
- Import model without materials
- Create materials in Godot
- Assign textures manually
- More control, but more work

---

## Tips for Artists

1. **Test Early**: Export a test model and check it in Godot
2. **Naming**: Use clear, descriptive names (`red_cube.glb` not `model1.glb`)
3. **Organization**: Group related assets in folders
4. **Documentation**: Note any special requirements (scale, orientation, etc.)
5. **Iterate**: Easy to update - just re-export and Godot will re-import

---

## Current Test Objects

Right now, we're using **primitive shapes** (boxes, spheres) with **simple materials** created directly in Godot. These are placeholders.

**Next step**: Replace these with actual 3D models created by an artist!

---

## Quick Reference

- **Models go in**: `assets/models/`
- **Textures go in**: `assets/textures/`
- **Godot auto-imports**: Just place files and they're ready
- **Best format**: GLB/GLTF
- **Scale matters**: Test in Godot to verify

