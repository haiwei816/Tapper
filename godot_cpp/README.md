# Cyber Tapper - Godot 4.x C++ (GDExtension) 移植版

本目录包含 Cyber Tapper 游戏从 UrhoX Lua 移植到 Godot 4.x C++ (GDExtension) 的完整源代码。

原始 Lua 代码保留在 `scripts/` 目录中不受影响。

## 文件结构

```
godot_cpp/
├── SConstruct                  # SCons 构建脚本
├── cyber_tapper.gdextension    # GDExtension 描述文件
├── README.md                   # 本文件
└── src/
    ├── config.h                # 游戏常量 (← Config.lua)
    ├── types.h                 # 数据结构定义
    ├── game_state.h            # 游戏状态管理 (← State.lua)
    ├── draw_lib.h              # 绘图工具库 (← DrawLib.lua)
    ├── game_logic.h            # 游戏逻辑头文件
    ├── game_logic.cpp          # 核心游戏逻辑 (← GameLogic.lua)
    ├── input_handler.h         # 输入处理头文件
    ├── input_handler.cpp       # 键盘/鼠标/触屏输入 (← Input.lua)
    ├── renderer.h              # 渲染器头文件
    ├── renderer.cpp            # 全部渲染逻辑 (← Renderer.lua)
    ├── cyber_tapper.h          # 主游戏节点头文件
    ├── cyber_tapper.cpp        # 入口/生命周期/音频 (← main.lua)
    ├── register_types.h        # GDExtension 注册
    └── register_types.cpp      # GDExtension 注册实现
```

## Lua → C++ 模块映射

| Lua 文件 | C++ 文件 | 说明 |
|----------|----------|------|
| `CyberTapper/Config.lua` | `config.h` | 常量、颜色、饮料类型 |
| `CyberTapper/State.lua` | `game_state.h` + `types.h` | 全局状态、布局计算 |
| `CyberTapper/DrawLib.lua` | `draw_lib.h` | NanoVG → Godot CanvasItem 绘图 |
| `CyberTapper/GameLogic.lua` | `game_logic.h/cpp` | 实体更新、碰撞、计分 |
| `CyberTapper/Input.lua` | `input_handler.h/cpp` | 输入事件处理 |
| `CyberTapper/Renderer.lua` | `renderer.h/cpp` | 全部渲染代码 |
| `main.lua` | `cyber_tapper.h/cpp` | 主节点、音频、生命周期 |

## API 映射

| UrhoX / NanoVG | Godot 4.x C++ |
|----------------|----------------|
| `nvgBeginFrame/EndFrame` | `_draw()` 生命周期 |
| `nvgRect/Fill` | `draw_rect()` |
| `nvgRoundedRect` | `DrawLib::round_rect()` (多边形近似) |
| `nvgCircle` | `draw_circle()` |
| `nvgLinearGradient` | `DrawLib::gradient_rect()` (顶点颜色) |
| `nvgText` | `draw_string()` |
| `nvgStroke` | `draw_line()` / `draw_polyline()` |
| `nvgTranslate/Scale` | `draw_set_transform()` |
| `nvgArc` | `draw_arc()` |
| `SubscribeToEvent("Update")` | `_process(double)` |
| `SubscribeToEvent("KeyDown")` | `_input(Ref<InputEvent>)` |
| `SoundSource:Play()` | `AudioStreamPlayer` |
| `cache:GetResource()` | `ResourceLoader::load()` |
| Lua `math.random()` | `std::mt19937` |

## 索引约定

| 概念 | Lua | C++ |
|------|-----|-----|
| 数组/通道索引 | 从 1 开始 | 从 0 开始 |
| 饮料类型 | 1-6 | 0-5 |
| 通道编号 | 1-4 | 0-3 |
| 关卡编号 | 1-6 | 1-6 (不变) |

## 构建步骤

### 前置条件

- Godot 4.2+ 编辑器
- SCons 构建工具
- C++17 编译器 (GCC 9+, Clang 10+, MSVC 2019+)

### 编译

```bash
# 1. 克隆 godot-cpp 到本目录
cd godot_cpp
git clone https://github.com/godotengine/godot-cpp.git --branch godot-4.2-stable

# 2. 编译 godot-cpp 绑定
cd godot-cpp
scons platform=linux target=template_debug -j$(nproc)
cd ..

# 3. 编译 Cyber Tapper 扩展
scons platform=linux target=template_debug -j$(nproc)
```

### 在 Godot 中使用

1. 将编译好的 `.so`/`.dll`/`.framework` 放入 Godot 项目的 `bin/` 目录
2. 将 `cyber_tapper.gdextension` 放在项目根目录
3. 准备资源文件:
   - `res://fonts/MiSans-Regular.ttf` (字体)
   - `res://audio/music_bgm.ogg` (背景音乐)
   - `res://audio/sfx/serve_throw.ogg`
   - `res://audio/sfx/glass_break.ogg`
   - `res://audio/sfx/angry_customer.ogg`
   - `res://audio/sfx/drink_sip.ogg`
   - `res://audio/sfx/game_over.ogg`
   - `res://audio/sfx/game_win.ogg`
4. 在场景中添加 `CyberTapper` 节点 (继承自 Node2D)
5. 运行即可

## 注意事项

- 此移植保持了与原始 Lua 代码相同的游戏逻辑和视觉效果
- 排行榜/云存档功能需要对接具体平台 SDK，当前为占位实现
- Godot 的 CanvasItem 绘图 API 与 NanoVG 在细节上有差异:
  - 圆角矩形使用多边形近似
  - 渐变使用顶点颜色插值
  - 裁剪区域 (scissor) 未完全对应
- 所有中文文本使用 UTF-8 编码
