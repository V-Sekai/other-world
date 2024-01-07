/**************************************************************************/
/*  animation_tree_editor_plugin.cpp                                      */
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

#include "animation_tree_editor_plugin.h"

#include "animation_blend_space_1d_editor.h"
#include "animation_blend_space_2d_editor.h"
#include "animation_blend_tree_editor_plugin.h"
#include "animation_state_machine_editor.h"
#include "core/config/project_settings.h"
#include "core/input/input.h"
#include "core/io/resource_loader.h"
#include "core/math/delaunay_2d.h"
#include "core/os/keyboard.h"
#include "editor/editor_node.h"
#include "editor/editor_scale.h"
#include "editor/gui/editor_file_dialog.h"
#include "editor/scene_tree_dock.h"
#include "scene/animation/animation_blend_tree.h"
#include "scene/animation/animation_player.h"
#include "scene/gui/button.h"
#include "scene/gui/menu_button.h"
#include "scene/gui/panel.h"
#include "scene/gui/scroll_container.h"
#include "scene/gui/separator.h"
#include "scene/main/window.h"
#include "scene/scene_string_names.h"

void AnimationTreeEditor::edit(AnimationTree *p_tree) {
	if (is_pinned()) {
		return;
	}

	if (p_tree && !p_tree->is_connected("animation_list_changed", callable_mp(this, &AnimationTreeEditor::_animation_list_changed))) {
		p_tree->connect("animation_list_changed", callable_mp(this, &AnimationTreeEditor::_animation_list_changed), CONNECT_DEFERRED);
	}

	if (tree == p_tree) {
		return;
	}

	if (tree && tree->is_connected("animation_list_changed", callable_mp(this, &AnimationTreeEditor::_animation_list_changed))) {
		tree->disconnect("animation_list_changed", callable_mp(this, &AnimationTreeEditor::_animation_list_changed));
	}

	tree = p_tree;

	Vector<String> path;
	if (tree) {
		edit_path(path);
	}

	pin->set_disabled(tree == nullptr);
}

void AnimationTreeEditor::_node_removed(Node *p_node) {
	if (p_node == tree) {
		pin->set_pressed(false);
		_clear_editors();

		tree = nullptr;
		Vector<String> path;
		edit_path(path);

		emit_signal(SNAME("animation_tree_removed"), p_node);
	}
}

void AnimationTreeEditor::_path_button_pressed(int p_path) {
	edited_path.clear();
	for (int i = 0; i <= p_path; i++) {
		edited_path.push_back(button_path[i]);
	}
}

void AnimationTreeEditor::_animation_list_changed() {
	AnimationNodeBlendTreeEditor *bte = AnimationNodeBlendTreeEditor::get_singleton();
	if (bte) {
		bte->update_graph();
	}
}

void AnimationTreeEditor::_pin_pressed() {
	emit_signal("pin_toggled");

	SceneTreeDock::get_singleton()->get_tree_editor()->update_tree();
}

void AnimationTreeEditor::_update_path() {
	while (path_hb->get_child_count() > 1) {
		memdelete(path_hb->get_child(1));
	}

	Ref<ButtonGroup> group;
	group.instantiate();

	Button *b = memnew(Button);
	b->set_text(TTR("Root"));
	b->set_toggle_mode(true);
	b->set_button_group(group);
	b->set_pressed(true);
	b->set_focus_mode(FOCUS_NONE);
	b->connect("pressed", callable_mp(this, &AnimationTreeEditor::_path_button_pressed).bind(-1));
	path_hb->add_child(b);
	for (int i = 0; i < button_path.size(); i++) {
		b = memnew(Button);
		b->set_text(button_path[i]);
		b->set_toggle_mode(true);
		b->set_button_group(group);
		path_hb->add_child(b);
		b->set_pressed(true);
		b->set_focus_mode(FOCUS_NONE);
		b->connect("pressed", callable_mp(this, &AnimationTreeEditor::_path_button_pressed).bind(i));
	}
}

void AnimationTreeEditor::edit_path(const Vector<String> &p_path) {
	button_path.clear();

	Ref<AnimationNode> node;
	if (tree) {
		node = tree->get_root_animation_node();
	}

	if (node.is_valid()) {
		current_root = node->get_instance_id();

		for (int i = 0; i < p_path.size(); i++) {
			Ref<AnimationNode> child = node->get_child_by_name(p_path[i]);
			ERR_BREAK(child.is_null());
			node = child;
			button_path.push_back(p_path[i]);
		}

		edited_path = button_path;

		for (int i = 0; i < editors.size(); i++) {
			if (editors[i]->can_edit(node)) {
				editors[i]->edit(node);
				editors[i]->show();
			} else {
				editors[i]->edit(Ref<AnimationNode>());
				editors[i]->hide();
			}
		}
	} else {
		current_root = ObjectID();
		edited_path = button_path;
		for (int i = 0; i < editors.size(); i++) {
			editors[i]->edit(Ref<AnimationNode>());
			editors[i]->hide();
		}
	}

	_update_path();
}

void AnimationTreeEditor::_clear_editors() {
	button_path.clear();
	current_root = ObjectID();
	edited_path = button_path;
	for (int i = 0; i < editors.size(); i++) {
		editors[i]->edit(Ref<AnimationNode>());
		editors[i]->hide();
	}
	_update_path();
}

Vector<String> AnimationTreeEditor::get_edited_path() const {
	return button_path;
}

Button *AnimationTreeEditor::get_pin() {
	return pin;
}

bool AnimationTreeEditor::is_pinned() const {
	return pin->is_pressed();
}

void AnimationTreeEditor::unpin(Node *n) {
	if (n == tree) {
		pin->set_pressed(false);
		_pin_pressed();
	}
}

void AnimationTreeEditor::enter_editor(const String &p_path) {
	Vector<String> path = edited_path;
	path.push_back(p_path);
	edit_path(path);
}

void AnimationTreeEditor::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_PROCESS: {
			ObjectID root;
			if (tree && tree->get_root_animation_node().is_valid()) {
				root = tree->get_root_animation_node()->get_instance_id();
			}

			if (root != current_root) {
				edit_path(Vector<String>());
			}

			if (button_path.size() != edited_path.size()) {
				edit_path(edited_path);
			}
		} break;
		case NOTIFICATION_EXIT_TREE: {
			get_tree()->disconnect("node_removed", callable_mp(this, &AnimationTreeEditor::_node_removed));
		} break;
		case NOTIFICATION_ENTER_TREE:
			get_tree()->connect("node_removed", callable_mp(this, &AnimationTreeEditor::_node_removed));
			[[fallthrough]];
		case NOTIFICATION_TRANSLATION_CHANGED:
		case NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
		case NOTIFICATION_THEME_CHANGED: {
			pin->set_icon(get_editor_theme_icon(SNAME("Pin")));
		} break;
	}
}

void AnimationTreeEditor::_bind_methods() {
	ADD_SIGNAL(MethodInfo("animation_tree_removed", PropertyInfo(Variant::OBJECT, "animation_tree")));
	ADD_SIGNAL(MethodInfo("pin_toggled"));
}

AnimationTreeEditor *AnimationTreeEditor::singleton = nullptr;

void AnimationTreeEditor::add_plugin(AnimationTreeNodeEditorPlugin *p_editor) {
	ERR_FAIL_COND(p_editor->get_parent());
	editor_base->add_child(p_editor);
	editors.push_back(p_editor);
	p_editor->set_h_size_flags(SIZE_EXPAND_FILL);
	p_editor->set_v_size_flags(SIZE_EXPAND_FILL);
	p_editor->hide();
}

void AnimationTreeEditor::remove_plugin(AnimationTreeNodeEditorPlugin *p_editor) {
	ERR_FAIL_COND(p_editor->get_parent() != editor_base);
	editor_base->remove_child(p_editor);
	editors.erase(p_editor);
}

String AnimationTreeEditor::get_base_path() {
	String path = SceneStringNames::get_singleton()->parameters_base_path;
	for (int i = 0; i < edited_path.size(); i++) {
		path += edited_path[i] + "/";
	}
	return path;
}

bool AnimationTreeEditor::can_edit(const Ref<AnimationNode> &p_node) const {
	for (int i = 0; i < editors.size(); i++) {
		if (editors[i]->can_edit(p_node)) {
			return true;
		}
	}
	return false;
}

Vector<String> AnimationTreeEditor::get_animation_list() {
	if (!singleton->tree || !singleton->is_visible()) {
		// When tree is empty, singleton not in the main thread.
		return Vector<String>();
	}

	AnimationTree *tree = singleton->tree;
	if (!tree) {
		return Vector<String>();
	}

	List<StringName> anims;
	tree->get_animation_list(&anims);
	Vector<String> ret;
	for (const StringName &E : anims) {
		ret.push_back(E);
	}

	return ret;
}

AnimationTreeEditor::AnimationTreeEditor() {
	AnimationNodeAnimation::get_editable_animation_list = get_animation_list;

	hb = memnew(HBoxContainer);
	add_child(hb);

	path_edit = memnew(ScrollContainer);
	hb->add_child(path_edit);
	path_edit->set_vertical_scroll_mode(ScrollContainer::SCROLL_MODE_DISABLED);
	path_edit->set_h_size_flags(SizeFlags::SIZE_EXPAND_FILL);

	path_hb = memnew(HBoxContainer);
	path_edit->add_child(path_hb);
	path_hb->add_child(memnew(Label(TTR("Path:"))));

	options_hb = memnew(HBoxContainer);
	hb->add_child(options_hb);

	VSeparator *vsep = memnew(VSeparator);
	options_hb->add_child(vsep);

	pin = memnew(Button);
	pin->set_theme_type_variation("FlatButton");
	pin->set_toggle_mode(true);
	pin->set_tooltip_text(TTR("Pin AnimationTree"));
	options_hb->add_child(pin);
	pin->connect(SNAME("pressed"), callable_mp(this, &AnimationTreeEditor::_pin_pressed));

	add_child(memnew(HSeparator));

	singleton = this;
	editor_base = memnew(MarginContainer);
	editor_base->set_v_size_flags(SIZE_EXPAND_FILL);
	add_child(editor_base);

	add_plugin(memnew(AnimationNodeBlendTreeEditor));
	add_plugin(memnew(AnimationNodeBlendSpace1DEditor));
	add_plugin(memnew(AnimationNodeBlendSpace2DEditor));
	add_plugin(memnew(AnimationNodeStateMachineEditor));
}

void AnimationTreeEditorPlugin::_pin_toggled() {
	if (!anim_tree_editor->is_pinned()) {
		if (!anim_tree_editor->get_selected_node()) {
			// If we don't have another valid selected node, hide everything.
			if (anim_tree_editor->is_visible_in_tree()) {
				EditorNode::get_singleton()->hide_bottom_panel();
			}
			button->hide();
		} else {
			edit(anim_tree_editor->get_selected_node());
		}
	}
}

void AnimationTreeEditorPlugin::_animation_tree_removed(Node *p_node) {
	if (anim_tree_editor->is_visible_in_tree()) {
		EditorNode::get_singleton()->hide_bottom_panel();
	}
	button->hide();
}

void AnimationTreeEditorPlugin::edit(Object *p_object) {
	anim_tree_editor->set_selected_node(Object::cast_to<AnimationTree>(p_object));

	if (anim_tree_editor && anim_tree_editor->is_pinned()) {
		AnimationTree *last_anim_tree_instance = Object::cast_to<AnimationTree>(ObjectDB::get_instance(last_anim_tree));

		// Safety check to make sure the pinned instance is actually still valid.
		if (last_anim_tree_instance && last_anim_tree_instance->is_inside_tree()) {
			// Only raise the panel if the editor is not currently visible and the node is the one we have pinned.
			if (!anim_tree_editor->is_visible_in_tree() && p_object == anim_tree_editor->get_animation_tree()) {
				EditorNode::get_singleton()->make_bottom_panel_item_visible(anim_tree_editor);
			}
		} else {
			// The pinned object seems to have gone missing, so force an unpin.
			anim_tree_editor->get_pin()->set_pressed(false);
		}
	}

	last_anim_tree = ObjectID();
	if (p_object) {
		last_anim_tree = p_object->get_instance_id();
	}

	anim_tree_editor->edit(anim_tree_editor->get_selected_node());
}

bool AnimationTreeEditorPlugin::handles(Object *p_object) const {
	return p_object->is_class("AnimationTree");
}

void AnimationTreeEditorPlugin::make_visible(bool p_visible) {
	anim_tree_editor->set_selected_node(nullptr);

	if (p_visible) {
		button->show();

		if (anim_tree_editor && !anim_tree_editor->is_pinned()) {
			EditorNode::get_singleton()->make_bottom_panel_item_visible(anim_tree_editor);
		}

		anim_tree_editor->set_process(true);
	} else {
		if (!anim_tree_editor->is_pinned()) {
			if (anim_tree_editor->is_visible_in_tree()) {
				EditorNode::get_singleton()->hide_bottom_panel();
			}
			button->hide();
			anim_tree_editor->set_process(false);
		}
	}
}

void AnimationTreeEditorPlugin::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_ENTER_TREE: {
			anim_tree_editor->connect("animation_tree_removed", callable_mp(this, &AnimationTreeEditorPlugin::_animation_tree_removed));
			anim_tree_editor->connect("pin_toggled", callable_mp(this, &AnimationTreeEditorPlugin::_pin_toggled));
		} break;
		case NOTIFICATION_EXIT_TREE: {
			anim_tree_editor->disconnect("animation_tree_removed", callable_mp(this, &AnimationTreeEditorPlugin::_animation_tree_removed));
			anim_tree_editor->disconnect("pin_toggled", callable_mp(this, &AnimationTreeEditorPlugin::_pin_toggled));
		} break;
	}
}

AnimationTreeEditorPlugin::AnimationTreeEditorPlugin() {
	anim_tree_editor = memnew(AnimationTreeEditor);
	anim_tree_editor->set_custom_minimum_size(Size2(0, 300) * EDSCALE);

	button = EditorNode::get_singleton()->add_bottom_panel_item(TTR("AnimationTree"), anim_tree_editor);
	button->hide();
}

AnimationTreeEditorPlugin::~AnimationTreeEditorPlugin() {
}
