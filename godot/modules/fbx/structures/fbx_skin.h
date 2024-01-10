/**************************************************************************/
/*  fbx_skin.h                                                            */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#ifndef FBX_SKIN_H
#define FBX_SKIN_H

#include "../fbx_defines.h"

#include "core/io/resource.h"
#include "core/variant/dictionary.h"
#include "scene/resources/skin.h"

template <typename T>
class TypedArray;

class FBXSkin : public Resource {
	GDCLASS(FBXSkin, Resource);
	friend class FBXDocument;
	friend class SkinTool;
	friend class FBXNode;

private:
	// The "skeleton" property defined in the gltf spec. -1 = Scene Root
	FBXNodeIndex skin_root = -1;

	Vector<FBXNodeIndex> joints_original;
	Vector<Transform3D> inverse_binds;

	// Note: joints + non_joints should form a complete subtree, or subtrees
	// with a common parent

	// All nodes that are skins that are caught in-between the original joints
	// (inclusive of joints_original)
	Vector<FBXNodeIndex> joints;

	// All Nodes that are caught in-between skin joint nodes, and are not
	// defined as joints by any skin
	Vector<FBXNodeIndex> non_joints;

	// The roots of the skin. In the case of multiple roots, their parent *must*
	// be the same (the roots must be siblings)
	Vector<FBXNodeIndex> roots;

	// The GLTF Skeleton this Skin points to (after we determine skeletons)
	FBXSkeletonIndex skeleton = -1;

	// A mapping from the joint indices (in the order of joints_original) to the
	// Godot Skeleton's bone_indices
	HashMap<int, int> joint_i_to_bone_i;
	HashMap<int, StringName> joint_i_to_name;

	// The Actual Skin that will be created as a mapping between the IBM's of
	// this skin to the generated skeleton for the mesh instances.
	Ref<Skin> godot_skin;

protected:
	static void _bind_methods();

public:
	FBXNodeIndex get_skin_root();
	void set_skin_root(FBXNodeIndex p_skin_root);

	Vector<FBXNodeIndex> get_joints_original();
	void set_joints_original(Vector<FBXNodeIndex> p_joints_original);

	TypedArray<Transform3D> get_inverse_binds();
	void set_inverse_binds(TypedArray<Transform3D> p_inverse_binds);

	Vector<FBXNodeIndex> get_joints();
	void set_joints(Vector<FBXNodeIndex> p_joints);

	Vector<FBXNodeIndex> get_non_joints();
	void set_non_joints(Vector<FBXNodeIndex> p_non_joints);

	Vector<FBXNodeIndex> get_roots();
	void set_roots(Vector<FBXNodeIndex> p_roots);

	int get_skeleton();
	void set_skeleton(int p_skeleton);

	Dictionary get_joint_i_to_bone_i();
	void set_joint_i_to_bone_i(Dictionary p_joint_i_to_bone_i);

	Dictionary get_joint_i_to_name();
	void set_joint_i_to_name(Dictionary p_joint_i_to_name);

	Ref<Skin> get_godot_skin();
	void set_godot_skin(Ref<Skin> p_godot_skin);

	Dictionary to_dictionary() {
		Dictionary dict;
		dict["skin_root"] = skin_root;

		Array joints_original_array;
		for (int i = 0; i < joints_original.size(); ++i) {
			joints_original_array.push_back(joints_original[i]);
		}
		dict["joints_original"] = joints_original_array;

		Array inverse_binds_array;
		for (int i = 0; i < inverse_binds.size(); ++i) {
			inverse_binds_array.push_back(inverse_binds[i]);
		}
		dict["inverse_binds"] = inverse_binds_array;

		Array joints_array;
		for (int i = 0; i < joints.size(); ++i) {
			joints_array.push_back(joints[i]);
		}
		dict["joints"] = joints_array;

		Array non_joints_array;
		for (int i = 0; i < non_joints.size(); ++i) {
			non_joints_array.push_back(non_joints[i]);
		}
		dict["non_joints"] = non_joints_array;

		Array roots_array;
		for (int i = 0; i < roots.size(); ++i) {
			roots_array.push_back(roots[i]);
		}
		dict["roots"] = roots_array;

		dict["skeleton"] = skeleton;

		Dictionary joint_i_to_bone_i_dict;
		for (HashMap<int, int>::Iterator E = joint_i_to_bone_i.begin(); E; ++E) {
			joint_i_to_bone_i_dict[E->key] = E->value;
		}
		dict["joint_i_to_bone_i"] = joint_i_to_bone_i_dict;

		Dictionary joint_i_to_name_dict;
		for (HashMap<int, StringName>::Iterator E = joint_i_to_name.begin(); E; ++E) {
			joint_i_to_name_dict[E->key] = E->value;
		}
		dict["joint_i_to_name"] = joint_i_to_name_dict;

		dict["godot_skin"] = godot_skin;
		return dict;
	}

	Error from_dictionary(const Dictionary &dict) {
		ERR_FAIL_COND_V(!dict.has("skin_root"), ERR_INVALID_DATA);
		skin_root = dict["skin_root"];

		ERR_FAIL_COND_V(!dict.has("joints_original"), ERR_INVALID_DATA);
		Array joints_original_array = dict["joints_original"];
		joints_original.clear();
		for (int i = 0; i < joints_original_array.size(); ++i) {
			joints_original.push_back(joints_original_array[i]);
		}

		ERR_FAIL_COND_V(!dict.has("inverse_binds"), ERR_INVALID_DATA);
		Array inverse_binds_array = dict["inverse_binds"];
		inverse_binds.clear();
		for (int i = 0; i < inverse_binds_array.size(); ++i) {
			ERR_FAIL_COND_V(inverse_binds_array[i].get_type() != Variant::TRANSFORM3D, ERR_INVALID_DATA);
			inverse_binds.push_back(inverse_binds_array[i]);
		}

		ERR_FAIL_COND_V(!dict.has("joints"), ERR_INVALID_DATA);
		Array joints_array = dict["joints"];
		joints.clear();
		for (int i = 0; i < joints_array.size(); ++i) {
			joints.push_back(joints_array[i]);
		}

		ERR_FAIL_COND_V(!dict.has("non_joints"), ERR_INVALID_DATA);
		Array non_joints_array = dict["non_joints"];
		non_joints.clear();
		for (int i = 0; i < non_joints_array.size(); ++i) {
			non_joints.push_back(non_joints_array[i]);
		}

		ERR_FAIL_COND_V(!dict.has("roots"), ERR_INVALID_DATA);
		Array roots_array = dict["roots"];
		roots.clear();
		for (int i = 0; i < roots_array.size(); ++i) {
			roots.push_back(roots_array[i]);
		}

		ERR_FAIL_COND_V(!dict.has("skeleton"), ERR_INVALID_DATA);
		skeleton = dict["skeleton"];

		ERR_FAIL_COND_V(!dict.has("joint_i_to_bone_i"), ERR_INVALID_DATA);
		Dictionary joint_i_to_bone_i_dict = dict["joint_i_to_bone_i"];
		joint_i_to_bone_i.clear();
		for (int i = 0; i < joint_i_to_bone_i_dict.keys().size(); ++i) {
			int key = joint_i_to_bone_i_dict.keys()[i];
			int value = joint_i_to_bone_i_dict[key];
			joint_i_to_bone_i[key] = value;
		}

		ERR_FAIL_COND_V(!dict.has("joint_i_to_name"), ERR_INVALID_DATA);
		Dictionary joint_i_to_name_dict = dict["joint_i_to_name"];
		joint_i_to_name.clear();
		for (int i = 0; i < joint_i_to_name_dict.keys().size(); ++i) {
			int key = joint_i_to_name_dict.keys()[i];
			StringName value = joint_i_to_name_dict[key];
			joint_i_to_name[key] = value;
		}

		if (dict.has("godot_skin")) {
			godot_skin = dict["godot_skin"];
		}

		return OK;
	}
};

#endif // FBX_SKIN_H
