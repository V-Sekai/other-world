#pragma once

#include "core/io/resource.h"
#include "core/object/ref_counted.h"
#include "core/templates/hash_map.h"
#include "core/templates/hash_set.h"
#include "core/templates/rb_set.h"

#include "core/math/disjoint_set.h"

#include "core/variant/dictionary.h"
#include "core/variant/typed_array.h"
#include "modules/fbx/fbx_defines.h"
#include "scene/main/node.h"
#include "scene/resources/skin.h"

using SkinNodeIndex = int;
using SkinSkeletonIndex = int;

class SkinTool : public Resource {
	GDCLASS(SkinTool, Resource);

	static String _sanitize_bone_name(const String &p_name);
	static String _gen_unique_bone_name(HashSet<String> unique_names, const String &p_name);
	static SkinNodeIndex _find_highest_node(Vector<Ref<FBXNode>> &r_nodes, const Vector<SkinNodeIndex> &p_subset);
	static bool _capture_nodes_in_skin(const Vector<Ref<FBXNode>> &nodes, Ref<FBXSkin> p_skin, const SkinNodeIndex p_node_index);
	static void _capture_nodes_for_multirooted_skin(Vector<Ref<FBXNode>> &r_nodes, Ref<FBXSkin> p_skin);
	static Error _parse_skins(Ref<FBXState> p_state);
	static void _recurse_children(
			Vector<Ref<FBXNode>> &nodes,
			const SkinNodeIndex p_node_index,
			RBSet<SkinNodeIndex> &p_all_skin_nodes,
			HashSet<SkinNodeIndex> &p_child_visited_set);
	static Error _reparent_non_joint_skeleton_subtrees(
			Vector<Ref<FBXNode>> &nodes,
			Ref<FBXSkeleton> p_skeleton,
			const Vector<SkinNodeIndex> &p_non_joints);
	static Error _determine_skeleton_roots(
			Vector<Ref<FBXNode>> &nodes,
			Vector<Ref<FBXSkeleton>> &skeletons,
			const SkinSkeletonIndex p_skel_i);
	static Error _map_skin_joints_indices_to_skeleton_bone_indices(
			Vector<Ref<FBXSkin>> &skins,
			Vector<Ref<FBXSkeleton>> &skeletons,
			Vector<Ref<FBXNode>> &nodes);
	static bool _skins_are_same(const Ref<Skin> p_skin_a, const Ref<Skin> p_skin_b);
	static void _remove_duplicate_skins(Vector<Ref<FBXSkin>> &r_skins);

public:
	static Error _expand_skin(Vector<Ref<FBXNode>> &r_nodes, Ref<FBXSkin> p_skin);
	static Error _verify_skin(Vector<Ref<FBXNode>> &r_nodes, Ref<FBXSkin> p_skin);
	static Error asset_parse_skins(
			const Vector<SkinNodeIndex> &input_skin_indices,
			const TypedArray<Dictionary> &input_skins,
			const TypedArray<Dictionary> &input_nodes,
			Vector<SkinNodeIndex> &output_skin_indices,
			TypedArray<Dictionary> &output_skins,
			HashMap<FBXNodeIndex, bool> &joint_mapping);
	static Error _determine_skeletons(
			Vector<Ref<FBXSkin>> &skins,
			Vector<Ref<FBXNode>> &nodes,
			Vector<Ref<FBXSkeleton>> &skeletons);

	static Error _create_skeletons(
			HashSet<String> &unique_names,
			Vector<Ref<FBXSkin>> &skins,
			Vector<Ref<FBXNode>> &nodes,
			HashMap<ObjectID, FBXSkeletonIndex> &skeleton3d_to_fbx_skeleton,
			Vector<Ref<FBXSkeleton>> &skeletons,
			HashMap<FBXNodeIndex, Node *> &scene_nodes);
	static Error _create_skins(Vector<Ref<FBXSkin>> &skins, Vector<Ref<FBXNode>> &nodes, bool use_named_skin_binds, HashSet<String> &unique_names);
};