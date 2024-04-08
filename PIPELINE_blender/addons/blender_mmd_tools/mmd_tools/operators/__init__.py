# -*- coding: utf-8 -*-

if "bpy" in locals():
    if bpy.app.version < (2, 71, 0):
        import imp as importlib
    else:
        import importlib
    importlib.reload(addon_updater)
    importlib.reload(animation)
    importlib.reload(camera)
    importlib.reload(display_item)
    importlib.reload(fileio)
    importlib.reload(lamp)
    importlib.reload(material)
    importlib.reload(misc)
    importlib.reload(model)
    importlib.reload(model_edit)
    importlib.reload(morph)
    importlib.reload(rigid_body)
    importlib.reload(view)
    importlib.reload(sdef)
    importlib.reload(translations)
else:
    import bpy
    from . import (
        addon_updater,
        animation,
        camera,
        display_item,
        fileio,
        lamp,
        material,
        misc,
        model,
        model_edit,
        morph,
        rigid_body,
        view,
        sdef,
        translations,
        )
