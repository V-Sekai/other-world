# ------------------------------------------------------------------------------------------
#  Copyright (c) Natsuneko. All rights reserved.
#  Licensed under the MIT License. See LICENSE in the project root for license information.
# ------------------------------------------------------------------------------------------

import bpy

from bpy.props import BoolProperty, EnumProperty, FloatProperty, IntProperty, StringProperty
from bpy.types import PropertyGroup


class DragAndDropSupportProperties(PropertyGroup):

    def axis(self, _):
        return [
            ("X", "X", "X"),
            ("Y", "Y", "Y"),
            ("Z", "Z", "Z"),
            ("-X", "-X", "-X"),
            ("-Y", "-Y", "-Y"),
            ("-Z", "-Z", "-Z")
        ]

    # alembic_import
    alembic_scale:                      FloatProperty(default=1.0,      name="Scale")
    set_frame_range:                    BoolProperty (default=True,     name="Set frame range")
    validate_meshes:                    BoolProperty (default=False,    name="Validate meshes")
    always_add_cache_render:            BoolProperty (default=False,    name="Always add cache render")
    is_sequence:                        BoolProperty (default=False,    name="Is Sequence")
    as_background_job:                  BoolProperty (default=False,    name="As background job")

    # bvh import
    def bvh_targets(self, _):
        return [
            ("ARMATURE", "Armature", "Armature"),
            ("OBJECT", "Object", "Object")
        ]

    def bvh_rotate_mode(self, _):
        return [
            ("QUATERNION", "Quaternion", "Quaternion"),
            ("NATIVE", "Native", "Native"),
            ("XYZ", "XYZ", "XYZ"),
            ("XZY", "XZY", "XZY"),
            ("YXZ", "YXZ", "YXZ"),
            ("YZX", "YZX", "YZY"),
            ("ZXY", "ZXY", "ZXY"),
            ("ZYX", "ZYX", "ZYX")
        ]

    bvh_global_scale:                   FloatProperty(default=1.0,      name="Global scale")
    frame_start:                        IntProperty  (default=1,        name="Start frame")
    use_fps_scale:                      BoolProperty (default=False,    name="Use Scale FPS")
    update_scene_fps:                   BoolProperty (default=False,    name="Update Scene FPS")
    update_scene_duration:              BoolProperty (default=False,    name="Update Scene Duration")
    use_cyclic:                         BoolProperty (default=False,    name="Loop")
    target:                             EnumProperty (default=0,        name="Target",                items=bvh_targets)
    rotate_mode:                        EnumProperty (default=1,        name="Rotation conversion",   items=bvh_rotate_mode)
    bvh_axis_forward:                   EnumProperty (default=5,        name="Axis Forward",          items=axis)
    bvh_axis_up:                        EnumProperty (default=1,        name="Axis Up",               items=axis)

    # fbx
    def ui_tabs(self, _):
        return [
            ("MAIN", "Main", "Main"),
            ("ARMATURE", "Armature", "Armature")
        ]

    fbx_global_scale:                   FloatProperty(default=1.0,      name="Global Scale",          min=0.0001, max=1000)
    decal_offset:                       FloatProperty(default=0.0,      name="Decal Offset",          min=0.0,    max=1.0)
    anim_offset:                        FloatProperty(default=1.0,      name="Animation Offset")
    use_manual_orientation:             BoolProperty (default=False,    name="Manual Orientation")
    bake_space_transform:               BoolProperty (default=False,    name="Apply Transform")
    use_custom_normals:                 BoolProperty (default=True,     name="Custom Normals")
    fbx_use_image_search:               BoolProperty (default=True,     name="Image Search")
    use_alpha_decals:                   BoolProperty (default=False,    name="Alpha Decals")
    use_anim:                           BoolProperty (default=True,     name="Import Animation")
    use_subsurf:                        BoolProperty (default=False,    name="Import Subdivision Data")
    use_custom_props:                   BoolProperty (default=True,     name="Import Custom Properties")
    use_custom_props_enum_as_string:    BoolProperty (default=True,     name="Import Enums as Strings")
    ignore_leaf_bones:                  BoolProperty (default=False,    name="Ignore Leaf Bones")
    force_connect_children:             BoolProperty (default=False,    name="Force connection of children bones")
    automatic_bone_orientation:         BoolProperty (default=False,    name="Automatic Bone Orientation")
    use_prepost_rot:                    BoolProperty (default=True,     name="Use pre/post rotation")
    ui_tab:                             EnumProperty (default=0,        name="UI Tab",                items=ui_tabs)
    primary_bone_axis:                  EnumProperty (default=1,        name="Primary Bone Axis",     items=axis)
    secondary_bone_axis:                EnumProperty (default=0,        name="Secondary Bone Axis",   items=axis)
    fbx_axis_forward:                   EnumProperty (default=5,        name="Axis Forward",          items=axis)
    fbx_axis_up:                        EnumProperty (default=1,        name="Axis Up",               items=axis)

    # collada
    import_units:                       BoolProperty (default=False,    name="Import Units")
    fix_orientation:                    BoolProperty (default=False,    name="Fix Leaf Bones")
    find_chains:                        BoolProperty (default=False,    name="Find Bone Chains")
    auto_connect:                       BoolProperty (default=False,    name="Auto Connect")
    keep_bind_info:                     BoolProperty (default=False,    name="Keep Bind Info")
    min_chain_length:                   IntProperty  (default=0,        name="Minimum Chain Length")

    # glTF
    def import_shadings(self, _):
        return [
            ("NORMALS", "Normals", "Normals"),
            ("FLAT", "Flat", "Flat"),
            ("SMOOTH", "Smooth", "Smooth")
        ]

    def bone_heuristics(self, _):
        return [
            ("BLENDER", "Blender", "Blender"),
            ("TEMPERANCE", "Temperance", "Temperance"),
            ("FORTUNE", "Fortune", "Fortune")
        ]

    loglevel:                           IntProperty  (default=0,        name="Log Level")
    import_pack_images:                 BoolProperty (default=True,     name="Import Pack Images")
    merge_vertices:                     BoolProperty (default=False,    name="Merge Vertices")
    guess_original_bind_pose:           BoolProperty (default=True,     name="Guess Original Bind Poses")
    import_shading:                     EnumProperty (default=0,        name="Import Shading",  items=import_shadings)
    bone_heuristic:                     EnumProperty (default=1,        name="Bone Dir",        items=bone_heuristics)

    # obj
    def split_modes(self, _):
        return [
            ("ON", "Split", "Split"),
            ("OFF", "Keep", "Keep")
        ]

    global_clamp_size:                  FloatProperty(default=0.0,      name="Clamp Size",      min=0.0, max=1000.0)
    use_edges:                          BoolProperty (default=True,     name="Import Lines")
    use_smooth_groups:                  BoolProperty (default=True,     name="Import Smooth Groups")
    use_split_objects:                  BoolProperty (default=True,     name="Import Object")
    use_split_groups:                   BoolProperty (default=False,    name="Import Groups")
    use_groups_as_vgroups:              BoolProperty (default=False,    name="Import Poly Groups")
    obj_use_image_search:               BoolProperty (default=True,     name="Image Search")
    split_mode:                         EnumProperty (default=0,        name="Split",           items=split_modes)
    obj_axis_forward:                   EnumProperty (default=5,        name="Forward Axis",    items=axis)
    obj_axis_up:                        EnumProperty (default=1,        name="Up Axis",         items=axis)

    # ply
    hide_props_region:                  BoolProperty (default=True,     name="Hide Operator Properties")

    # stl
    stl_global_scale:                   FloatProperty(default=1.0,      name="Global Scale")
    use_scene_unit:                     BoolProperty (default=False,    name="Import Scene Unit")
    use_facet_normal:                   BoolProperty (default=False,    name="Import Facet Normals")
    stl_axis_forward:                   EnumProperty (default=1,        name="Forward Axis",    items=axis)
    stl_axis_up:                        EnumProperty (default=2,        name="Up Axis",         items=axis)

    # svg has no parameters

    # usd
    usd_scale:                          FloatProperty(default=1.0,      name="Scale",           min=0.0001, max=1000)
    light_intensity_scale:              FloatProperty(default=1.0,      name="Light Intensity")
    usd_set_frame_range:                BoolProperty (default=True,     name="Set Frame Range")
    import_cameras:                     BoolProperty (default=True,     name="Import Cameras")
    import_curves:                      BoolProperty (default=True,     name="Import Curves")
    import_lights:                      BoolProperty (default=True,     name="Import Lights")
    import_materials:                   BoolProperty (default=True,     name="Import Materials")
    import_meshes:                      BoolProperty (default=True,     name="Import Meshes")
    import_volumes:                     BoolProperty (default=True,     name="Import Volumes")
    import_subdiv:                      BoolProperty (default=True,     name="Import Subdivision Scheme")
    import_instance_proxies:            BoolProperty (default=True,     name="Import Instance Proxies")
    import_visible_only:                BoolProperty (default=True,     name="Import Visible Primitives Only")
    create_collection:                  BoolProperty (default=True,     name="Create Collection")
    read_mesh_uvs:                      BoolProperty (default=True,     name="Import UV Coordinates")
    read_mesh_colors:                   BoolProperty (default=True,     name="Import Color Attributes")
    import_guide:                       BoolProperty (default=False,    name="Import Guide Geometry")
    import_proxy:                       BoolProperty (default=True,     name="Import Proxy Geometry")
    import_render:                      BoolProperty (default=True,     name="Import Final Render Geometry")
    import_usd_preview:                 BoolProperty (default=False,    name="Import Final Render Geometry")
    set_material_blend:                 BoolProperty (default=True,     name="Set Material Blend")

    # x3d
    x3d_axis_forward:                   EnumProperty(default=1,         name="Forward Axis",    items=axis,)
    x3d_axis_up:                        EnumProperty(default=2,         name="Up Axis",         items=axis,)
