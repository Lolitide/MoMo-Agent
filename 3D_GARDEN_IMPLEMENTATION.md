# 3D 记忆花园 - 实现说明

## ✨ 已完成功能

### 1. 纯代码 3D 渲染（无需 Blender）
- **Canvas 2D 绘制伪 3D 效果**：通过透视投影算法实现真实的 3D 空间感
- **实时渲染管线**：60fps 流畅动画循环
- **深度排序**：节点按 Z 轴距离排序，远处先画

### 2. 视觉效果
- **渐变球体**：模拟光照的径向渐变（高光 + 主色 + 暗部）
- **粒子背景**：60 个流动光点营造星空氛围
- **选中高亮**：青绿光环 + 光晕扩散
- **连接线**：贝塞尔曲线绘制记忆关联（m4-m8, m2-m1）

### 3. 交互体验
- **手势旋转**：拖动改变相机视角（绕 X/Y 轴旋转）
- **点击检测**：精确识别球体点击（考虑透视缩放）
- **平滑过渡**：所有动画使用缓动曲线

### 4. 集成方式
- **第四种视图模式**：在花园页面菜单中新增"3D 花园"选项
- **无缝切换**：与现有花园/大纲/树模式共存
- **数据共享**：使用相同的 Memory 数据源

## 🎯 技术实现

### 3D 投影算法
```typescript
// 1. 绕 Y 轴旋转（左右转）
tx = x * cos(rotY) - z * sin(rotY)
tz = x * sin(rotY) + z * cos(rotY)

// 2. 绕 X 轴旋转（上下转）
ty2 = ty * cos(rotX) - tz * sin(rotX)
tz2 = ty * sin(rotX) + tz * cos(rotX)

// 3. 透视投影
scale = fov / (fov + tz2)
screenX = centerX + tx * scale * 200
screenY = centerY + ty2 * scale * 200
```

### 节点布局策略
- **圆形分布**：节点围绕中心呈圆形排列（角度 = idx / total * 2π）
- **类型分层**：不同记忆类型分布在不同 Y 高度
  - 生活 (LIFE): y = -0.6
  - 学习 (STUDY): y = -0.3
  - 兴趣 (INTEREST): y = 0
  - 目标 (GOAL): y = 0.3
  - 重要 (IMPORTANT): y = 0.6

### 性能优化
- **requestAnimationFrame**：浏览器同步刷新，避免掉帧
- **深度测试**：点击时只检测可见节点
- **渐进渲染**：粒子和节点分批绘制

## 📁 文件清单

1. **Garden3DView.ets** - 3D 视图组件（可复用）
2. **Models.ets** - 添加 `GardenMode.GARDEN_3D`
3. **ModeMenu.ets** - 菜单添加第 4 个选项
4. **A_Garden.ets** - 集成 3D 视图分支

## 🚀 运行方式

1. 构建项目
2. 打开应用 → 记忆花园 Tab
3. 点击右上角菜单 → 选择"3D 花园"
4. 拖动旋转查看，点击节点打开详情

## 🎨 视觉参数调整

### 背景色（深空渐变）
```typescript
// Garden3DView.ets 第 191 行
bgGradient.addColorStop(0, '#0A0D12');   // 顶部深蓝黑
bgGradient.addColorStop(0.5, '#161D2B'); // 中部紫灰
bgGradient.addColorStop(1, '#1E2636');   // 底部灰蓝
```

### 粒子数量与速度
```typescript
// 第 86 行
for (let i = 0; i < 60; i++) {  // 改为 80 可增加粒子密度
  vx: (Math.random() - 0.5) * 0.002,  // 增大数值加快流动
}
```

### 节点大小
```typescript
// 第 245 行
const baseRadius = 30 + node.memory.importance * 5;
// 改为：const baseRadius = 40 + node.memory.importance * 8;
```

### 旋转灵敏度
```typescript
// 第 293 行
this.rotationY = this.panStartRotY + event.offsetX * 0.01;
// 改为 0.02 可增加灵敏度
```

## 🔮 进阶扩展方向

### 1. 真实 3D 模型导入（需外部工具）
如果你有 Blender：
1. 运行 `design/3d-models/generate_memory_garden.py`
2. 导出 GLB 文件
3. 使用 HarmonyOS 的 Component3D 加载（需要额外配置）

### 2. 着色器特效
- 节点表面法线贴图（更真实的光照）
- 景深模糊（远处节点模糊）
- 辉光后处理（发光节点泛光）

### 3. 物理引擎
- 节点碰撞检测
- 重力效果
- 弹性连接线

### 4. 高级交互
- 双指捏合缩放
- 节点拖动重排
- 添加新节点时的生长动画

## ⚠️ 注意事项

1. **Canvas 性能**：节点超过 50 个时考虑降低粒子数量
2. **内存管理**：切换视图时会自动清理动画循环
3. **触摸精度**：小屏设备上节点可能难以点击（已按透视缩放调整）

## 🎉 效果预览

运行后你会看到：
- ✨ 60 个青绿色光点在深空中缓慢流动
- 🔮 8 个彩色记忆球体在 3D 空间中排列
- 🔗 m4-m8、m2-m1 之间有淡绿色弧线连接
- 👆 拖动时整个场景随视角旋转
- 💫 选中节点时出现青绿光环与光晕

**对比 2D 花园的优势**：
- 空间层次更丰富（前后深度）
- 交互更直观（真实旋转）
- 视觉更震撼（粒子 + 光效）
