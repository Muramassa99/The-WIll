extends Resource
class_name ForgeViewTuningDef

@export_group("Shared")
@export var unknown_material_color: Color = Color(0.878431, 0.541176, 0.337255, 1.0)

@export_group("Plane View")
@export var plane_empty_color: Color = Color(0.109804, 0.12549, 0.156863, 1.0)
@export var plane_grid_color: Color = Color(0.282353, 0.341176, 0.439216, 0.35)
@export var plane_frame_color: Color = Color(0.803922, 0.717647, 0.498039, 1.0)
@export var plane_margin_pixels: float = 12.0
@export var plane_cell_inset_pixels: float = 0.5
@export var plane_zoom_step: float = 0.2
@export var plane_zoom_min_scale: float = 1.0
@export var plane_zoom_max_scale: float = 4.0
@export_range(0.0, 1.0, 0.01) var plane_shape_add_preview_alpha: float = 0.35
@export var plane_shape_remove_preview_color: Color = Color(0.886275, 0.313726, 0.258824, 0.35)

@export_group("Workspace Preview")
@export var workspace_camera_fov_degrees: float = 55.0
@export var workspace_camera_near: float = 0.01
@export var workspace_camera_far: float = 50.0
@export var workspace_default_yaw_degrees: float = -34.0
@export var workspace_default_pitch_degrees: float = -28.0
@export var workspace_pitch_min_degrees: float = -80.0
@export var workspace_pitch_max_degrees: float = 80.0
@export var workspace_orbit_mouse_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var workspace_pan_modifier_keycode: Key = KEY_C
@export var workspace_capture_mouse_during_drag: bool = true
@export var workspace_orbit_sensitivity: float = 0.01
@export var workspace_pan_sensitivity: float = 0.0025
@export var workspace_pan_min_distance: float = 0.25
@export var workspace_zoom_step: float = 0.25
@export var workspace_zoom_min_distance: float = 0.1
@export var workspace_zoom_max_distance: float = 12.0
@export var workspace_fit_distance_multiplier: float = 1.8
@export var workspace_fit_min_distance: float = 2.5
@export var workspace_fit_max_distance: float = 10.0
@export var workspace_ray_plane_epsilon: float = 0.00001
@export var workspace_light_follows_camera: bool = true
@export var workspace_light_follow_offset_degrees: Vector3 = Vector3.ZERO
@export var workspace_light_energy: float = 2.2
@export var workspace_light_rotation_degrees: Vector3 = Vector3(-48.0, -30.0, 0.0)
@export var workspace_grid_bounds_color: Color = Color(0.760784, 0.709804, 0.564706, 0.06)
@export var workspace_active_plane_color: Color = Color(0.85098, 0.333333, 0.247059, 0.18)
@export var workspace_voxel_inset_factor: float = 1.0
@export var workspace_voxel_roughness: float = 0.82
@export var workspace_voxel_metallic: float = 0.05
@export var workspace_plane_thickness_factor: float = 0.12
@export var workspace_stage2_shell_color: Color = Color(0.392157, 0.176471, 0.568627, 0.26)
@export var workspace_stage2_brush_color: Color = Color(0.392157, 0.176471, 0.568627, 0.16)
@export var workspace_stage2_blocked_brush_color: Color = Color(0.780392, 0.25098, 0.309804, 0.18)
@export var workspace_stage2_hover_face_color: Color = Color(0.392157, 0.176471, 0.568627, 0.2)
@export var workspace_stage2_selected_face_color: Color = Color(0.392157, 0.176471, 0.568627, 0.3)
@export var workspace_stage2_default_brush_radius_meters: float = 0.12
@export_range(0.01, 1.0, 0.01) var workspace_stage2_brush_step_ratio: float = 0.25
@export var workspace_generated_string_color: Color = Color(0.776471, 0.878431, 0.980392, 0.9)
@export var workspace_generated_string_draw_color: Color = Color(1.0, 0.729412, 0.356863, 0.5)
@export var workspace_generated_string_radius_meters: float = 0.0025

@export_group("Test Print Preview")
@export var test_print_fallback_color: Color = Color(0.819608, 0.811765, 0.772549, 1.0)
@export var test_print_material_roughness: float = 0.75
@export var test_print_material_metallic: float = 0.0

@export_group("Workbench UI")
@export var ui_inventory_owned_color: Color = Color(0.93, 0.92, 0.88, 1.0)
@export var ui_inventory_empty_color: Color = Color(0.56, 0.58, 0.62, 1.0)
@export var ui_button_active_color: Color = Color(0.94902, 0.882353, 0.678431, 1.0)
@export var ui_button_inactive_color: Color = Color(0.76, 0.76, 0.76, 1.0)
@export var ui_tab_active_color: Color = Color(0.980392, 0.760784, 0.419608, 1.0)
@export var ui_tab_inactive_color: Color = Color(0.7, 0.7, 0.7, 1.0)
