# 随心记 App 图标 · Icon Composer 分层交付（3a 声波＋心跳）

三个 1024×1024 图层（自下而上导入，系统自动套用圆角遮罩，勿自行裁切）：

| 图层 | 文件 | Icon Composer 设置 |
|---|---|---|
| L1 背景 | Layer-1-Background.svg | 底层，不开玻璃；渐变 #FFA075→#FF7A47 |
| L2 声波五条 | Layer-2-Waveform.svg | Liquid Glass 开；Specular 开，Refraction 中 |
| L3 心跳线 | Layer-3-Heartbeat.svg | Liquid Glass 开；置于最上层，Elevation 略高于 L2 |

## 步骤
1. Icon Composer 新建 iOS 图标项目（1024pt）。
2. 依次拖入 L1 → L2 → L3，确认图层顺序。
3. 选中 L2、L3：开启 Liquid Glass，按上表调 Specular / Refraction / Elevation。
4. 右侧预览切换 Default / Dark / Clear / Tinted 四种外观检查：
   - Dark：背景自动压暗，玻璃字形保持暖橙高光；
   - Clear / Tinted：仅保留字形层，确认心跳线与声波在单色下仍清晰。
5. 导出 .icon 文件，拖入 Xcode 工程的 AppIcon（iOS 26+ 格式）。

注：iOS 27 的图标高光不再随陀螺仪移动、整体更收敛（上下边缘静态高光），Icon Composer 预览所见即所得。
