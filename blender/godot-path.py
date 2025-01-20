import bpy
import csv
import os
import mathutils
import copy
import collections
import json
from bpy.app.handlers import persistent

bl_info = {
    "name": "Godot Path Exporter",
    "author": "Lewis Cianci",
    "version": (1, 0),
    "blender": (2, 80, 0),
    "location": "View3D > Add Mesh",
    "description": "Exports paths for godot",
    "category": "3D View",
}

def register():
    print('registering')
    # if not export_curve_data_to_csv in bpy.app.handlers.load_post:
    bpy.app.handlers.save_pre.append(search_for_curves)
 
def unregister():
    # if export_curve_data_to_csv in bpy.app.handlers.load_post:
    bpy.app.handlers.save_pre.remove(search_for_curves)

@persistent
def write_curve_data_to_array(curve, curvesArray):
    
    axis_correct = mathutils.Matrix((
    (1, 0, 0),  # X in blender is  X in Godot
    (0, 0, -1),  # Y in blender is -Z in Godot
    (0, 1, 0),  # Z in blender is  Y in Godot
    )).normalized()
    
    print('exporting ' + curve.name)
    for spline in curve.data.splines:
#        points = []
        pointLocations = []
        print(spline.type)
        if spline.type == 'BEZIER':
            pointIndex = 0
            src_points = spline.bezier_points
            if spline.use_cyclic_u:
                # Godot fakes a closed path by adding the start point at the end
                # https://github.com/godotengine/godot-proposals/issues/527
                src_points = [*src_points, src_points[0]]
            for point in src_points:
                # blender handles are absolute
                # godot handles are relative to the control point
#                points.extend((point.handle_left - point.co) @ axis_correct)
#                points.extend((point.handle_right - point.co) @ axis_correct)
#                points.extend(point.co @ axis_correct)
#                tilts.append(point.tilt)
                 pointLocation = {
                    'leftHandle': list((point.handle_left - point.co) @ axis_correct),
                    'rightHandle': list((point.handle_right - point.co) @ axis_correct),
                    'position': list(point.co @ axis_correct),
                    'tilt': point.tilt
                 }
                 pointLocations.append(pointLocation)
                 print(pointLocation)
#            print(points)

            # data = {}
            curveData = {}

            curveData["name"] = curve.name
            curveData["points"] = pointLocations
            translatedPosition = curve.matrix_world.to_translation()
            curveData["location"]= {"x": translatedPosition.x, "y": translatedPosition.y, "z": translatedPosition.z}
            curveData["scale"] = {"x": curve.scale.x, "y": curve.scale.y, "z": curve.scale.z}
            curveData["rotation"] = {"x": curve.rotation_euler.x, "y": curve.rotation_euler.z, "z": curve.rotation_euler.y}
            curvesArray.append(curveData)
                
@persistent
def recursively_search_curves(obj, curvesArray):
    print(obj.name)
    print(obj.type)
    if obj.data is not None and obj.type is not None:
        
        if obj.type == 'CURVE':
            write_curve_data_to_array(obj, curvesArray)
        for child in obj.children:
            recursively_search_curves(child, curvesArray)

@persistent
def search_for_curves(dummy):
    print('file is being savdded!!');
    blend_file_path = bpy.data.filepath
    blend_base_name = os.path.splitext(os.path.basename(blend_file_path))[0]
    output_dir = os.path.join(os.path.dirname(blend_file_path), blend_base_name)
    output_file = os.path.join(output_dir, blend_base_name + 'curves.json')
    curves = []
    for collection in bpy.data.collections:
        print(collection.name)
        for obj in collection.all_objects:
            recursively_search_curves(obj, curves)
    # print(bpy.context.scene.objects)
    # recursively_search_curves(bpy.context.scene.objects, curves)
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w+', encoding='utf-8') as f:
        json.dump(curves, f, ensure_ascii=False, indent=4)

if __name__ == "__main__":
    register()