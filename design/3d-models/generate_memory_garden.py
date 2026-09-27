#!/usr/bin/env python3
"""
记忆花园 3D 场景生成脚本 - Blender Python
使用方法：
1. 打开 Blender（推荐 3.6+）
2. 脚本编辑器中粘贴此脚本
3. 运行脚本（Alt+P）
4. 导出为 GLB：File > Export > glTF 2.0 (.glb)
"""

import bpy
import math
import random

# 清空场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ============================================================================
# 1. 创建地面（草地平面，带起伏）
# ============================================================================
def create_ground():
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "Ground"

    # 细分地面以制作起伏
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=20)
    bpy.ops.object.mode_set(mode='OBJECT')

    # 添加位移修改器制作起伏
    for v in ground.data.vertices:
        noise = random.uniform(-0.08, 0.12)
        v.co.z += noise

    # 材质：草地绿
    mat = bpy.data.materials.new(name="GroundMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()

    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (0.55, 0.75, 0.45, 1.0)  # #8CBF73
    bsdf.inputs['Roughness'].default_value = 0.9

    output = nodes.new(type='ShaderNodeOutputMaterial')
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    ground.data.materials.append(mat)
    return ground

# ============================================================================
# 2. 创建记忆节点球体（发光球）
# ============================================================================
def create_memory_sphere(location, radius, color, importance):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius,
        location=location,
        segments=32,
        ring_count=16
    )
    sphere = bpy.context.active_object
    sphere.name = f"MemorySphere_{location[0]}_{location[1]}"

    # 材质：半透明发光
    mat = bpy.data.materials.new(name=f"Memory_{color}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()

    # Emission节点（发光）
    emission = nodes.new(type='ShaderNodeEmission')
    emission.inputs['Color'].default_value = (*color, 1.0)
    emission.inputs['Strength'].default_value = 1.5 + importance * 0.5

    # Transparent BSDF（半透明）
    transparent = nodes.new(type='ShaderNodeBsdfTransparent')

    # Glass BSDF（玻璃质感）
    glass = nodes.new(type='ShaderNodeBsdfGlass')
    glass.inputs['Color'].default_value = (*color, 1.0)
    glass.inputs['Roughness'].default_value = 0.1
    glass.inputs['IOR'].default_value = 1.45

    # Mix Shader
    mix1 = nodes.new(type='ShaderNodeMixShader')
    mix1.inputs['Fac'].default_value = 0.3

    mix2 = nodes.new(type='ShaderNodeMixShader')
    mix2.inputs['Fac'].default_value = 0.6

    output = nodes.new(type='ShaderNodeOutputMaterial')

    # 连接节点
    mat.node_tree.links.new(transparent.outputs['BSDF'], mix1.inputs[1])
    mat.node_tree.links.new(glass.outputs['BSDF'], mix1.inputs[2])
    mat.node_tree.links.new(mix1.outputs['Shader'], mix2.inputs[1])
    mat.node_tree.links.new(emission.outputs['Emission'], mix2.inputs[2])
    mat.node_tree.links.new(mix2.outputs['Shader'], output.inputs['Surface'])

    sphere.data.materials.append(mat)

    # 添加重要性指示环
    if importance >= 3:
        bpy.ops.mesh.primitive_torus_add(
            location=location,
            major_radius=radius * 1.3,
            minor_radius=0.03
        )
        ring = bpy.context.active_object
        ring.rotation_euler = (math.pi / 2, 0, 0)

        ring_mat = bpy.data.materials.new(name="ImportanceRing")
        ring_mat.use_nodes = True
        ring_nodes = ring_mat.node_tree.nodes
        ring_nodes.clear()

        ring_emission = ring_nodes.new(type='ShaderNodeEmission')
        ring_emission.inputs['Color'].default_value = (*color, 1.0)
        ring_emission.inputs['Strength'].default_value = 2.0

        ring_output = ring_nodes.new(type='ShaderNodeOutputMaterial')
        ring_mat.node_tree.links.new(ring_emission.outputs['Emission'], ring_output.inputs['Surface'])

        ring.data.materials.append(ring_mat)

    return sphere

# ============================================================================
# 3. 创建记忆类型图标（简化3D形状）
# ============================================================================
def create_icon_shape(location, shape_type):
    if shape_type == "life":  # 叶子
        bpy.ops.mesh.primitive_cone_add(
            radius1=0.15,
            radius2=0,
            depth=0.5,
            location=(location[0], location[1], location[2] + 0.1)
        )
    elif shape_type == "study":  # 书
        bpy.ops.mesh.primitive_cube_add(
            size=0.3,
            location=(location[0], location[1], location[2] + 0.1)
        )
    elif shape_type == "interest":  # 花
        for i in range(5):
            angle = i * (2 * math.pi / 5)
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.1,
                location=(
                    location[0] + 0.15 * math.cos(angle),
                    location[1] + 0.15 * math.sin(angle),
                    location[2] + 0.1
                )
            )
    elif shape_type == "goal":  # 星星
        bpy.ops.mesh.primitive_ico_sphere_add(
            radius=0.2,
            location=(location[0], location[1], location[2] + 0.1)
        )
    else:  # important - 皇冠
        bpy.ops.mesh.primitive_cone_add(
            radius1=0.2,
            radius2=0.1,
            depth=0.3,
            location=(location[0], location[1], location[2] + 0.15)
        )

# ============================================================================
# 4. 创建连接线（记忆关联）
# ============================================================================
def create_connection_line(start, end, color):
    # 创建曲线
    curve_data = bpy.data.curves.new(name="ConnectionLine", type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_depth = 0.02
    curve_data.resolution_u = 12

    # 创建样条线
    polyline = curve_data.splines.new('BEZIER')
    polyline.bezier_points.add(1)

    # 设置起点和终点
    polyline.bezier_points[0].co = start
    polyline.bezier_points[1].co = end

    # 设置中点（形成弧线）
    mid_x = (start[0] + end[0]) / 2
    mid_y = (start[1] + end[1]) / 2
    mid_z = max(start[2], end[2]) + 0.5

    polyline.bezier_points[0].handle_right = (
        start[0] + (mid_x - start[0]) * 0.3,
        start[1] + (mid_y - start[1]) * 0.3,
        start[2] + 0.2
    )
    polyline.bezier_points[1].handle_left = (
        end[0] - (end[0] - mid_x) * 0.3,
        end[1] - (end[1] - mid_y) * 0.3,
        end[2] + 0.2
    )

    # 创建对象
    curve_obj = bpy.data.objects.new("Connection", curve_data)
    bpy.context.collection.objects.link(curve_obj)

    # 材质：发光线
    mat = bpy.data.materials.new(name="ConnectionMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()

    emission = nodes.new(type='ShaderNodeEmission')
    emission.inputs['Color'].default_value = (*color, 1.0)
    emission.inputs['Strength'].default_value = 1.0

    output = nodes.new(type='ShaderNodeOutputMaterial')
    mat.node_tree.links.new(emission.outputs['Emission'], output.inputs['Surface'])

    curve_obj.data.materials.append(mat)
    return curve_obj

# ============================================================================
# 5. 创建环境光与相机
# ============================================================================
def setup_lighting():
    # 主光源（太阳光）
    bpy.ops.object.light_add(type='SUN', location=(5, 5, 10))
    sun = bpy.context.active_object
    sun.data.energy = 1.5
    sun.data.color = (1.0, 0.98, 0.95)
    sun.rotation_euler = (math.radians(45), 0, math.radians(45))

    # 环境光
    world = bpy.context.scene.world
    world.use_nodes = True
    bg_node = world.node_tree.nodes['Background']
    bg_node.inputs['Color'].default_value = (0.65, 0.8, 0.95, 1.0)  # 天空蓝
    bg_node.inputs['Strength'].default_value = 0.3

def setup_camera():
    bpy.ops.object.camera_add(location=(0, -12, 8))
    camera = bpy.context.active_object
    camera.rotation_euler = (math.radians(55), 0, 0)
    bpy.context.scene.camera = camera
    camera.data.lens = 35

# ============================================================================
# 6. 生成完整场景
# ============================================================================
def generate_scene():
    print("🌱 生成地面...")
    create_ground()

    print("✨ 创建记忆节点...")
    # 8个记忆节点（对应Mock数据）
    memories = [
        # (x, y, z, radius, color_rgb, importance, type)
        (-3, 4, 0.5, 0.4, (0.56, 0.95, 0.63), 3, "life"),      # m1 晨间散步
        (2, 3, 0.5, 0.45, (0.43, 0.79, 0.88), 4, "study"),     # m2 HDS规范
        (5, 4, 0.5, 0.35, (0.96, 0.70, 0.42), 2, "interest"),  # m3 设计书
        (-2, 1, 0.5, 0.5, (0.72, 0.58, 0.96), 5, "important"), # m4 花园第一株花
        (3, 1, 0.5, 0.4, (1.0, 0.85, 0.48), 3, "goal"),        # m5 年末目标
        (-5, 2, 0.5, 0.3, (0.56, 0.95, 0.63), 2, "life"),      # m6 咖啡店
        (1, -2, 0.5, 0.35, (0.96, 0.70, 0.42), 2, "interest"), # m7 音乐合集
        (5, 0, 0.5, 0.55, (1.0, 0.58, 0.58), 5, "important")  # m8 遇见默默
    ]

    spheres = []
    for mem in memories:
        x, y, z, radius, color, importance, mem_type = mem
        sphere = create_memory_sphere((x, y, z), radius, color, importance)
        spheres.append((sphere, (x, y, z)))
        create_icon_shape((x, y, z), mem_type)

    print("🔗 创建连接线...")
    # 添加关联线（m4关联m8，m2关联部分记忆）
    create_connection_line((spheres[3][1]), (spheres[7][1]), (0.72, 0.58, 0.96))  # m4-m8
    create_connection_line((spheres[1][1]), (spheres[0][1]), (0.43, 0.79, 0.88))  # m2-m1

    print("💡 设置光照...")
    setup_lighting()

    print("📷 设置相机...")
    setup_camera()

    print("✅ 场景生成完成！")
    print("\n📤 导出步骤：")
    print("1. File > Export > glTF 2.0 (.glb)")
    print("2. 文件名：memory_garden.glb")
    print("3. 勾选：+Y Up, Apply Modifiers, Compression")
    print("4. 保存到：design/3d-models/")

# 运行生成
generate_scene()
