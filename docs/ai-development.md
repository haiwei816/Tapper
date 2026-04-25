# AI 辅助开发说明

## 大模型型号

本项目使用以下 AI 大模型进行代码开发：

| 项目 | 信息 |
|------|------|
| **模型名称** | Claude Opus 4 |
| **模型 ID** | `claude-opus-4-6` |
| **开发商** | Anthropic |
| **知识截止日** | 2025 年 1 月 |
| **开发环境** | TapTap 星火编辑器 (SCE / UrhoX) |
| **调用方式** | Claude Code CLI (交互式对话开发) |

> Claude Opus 4 是 Anthropic 推出的旗舰级代码生成模型，具备长上下文理解、多轮对话迭代、复杂代码重构等能力。

## 开发引擎

| 项目 | 信息 |
|------|------|
| **引擎** | UrhoX — TapTap 星火编辑器 (SCE) 团队开发的 AI-coding-friendly 游戏引擎 |
| **脚本语言** | Lua 5.4 |
| **渲染框架** | NanoVG (2D 矢量图形) |
| **物理引擎** | Box2D (2D 物理) |
| **目标平台** | TapTap 小游戏 (移动端 + PC) |

## AI 开发 Skills (技能)

在开发过程中，Claude Code 使用了以下内置 Skills 和 MCP 工具：

### 内置 Skills

| Skill | 用途 | 本项目使用场景 |
|-------|------|---------------|
| **materials** | PBR 材质系统，35+ 预制材质 | 赛博朋克风格视觉设计参考 |
| **nvg-resolution-mode** | NanoVG 分辨率模式选择指南 | 适配不同 DPI 屏幕的 nvgBeginFrame 配置 |
| **memory-system** | AI 跨会话持久记忆 | 多轮对话中保持项目上下文连贯 |
| **pixel-art-generator** | 像素风格资源生成 | 可用于生成游戏像素图标 |
| **skill-creator** | 创建自定义 Skill | 扩展 AI 能力 |

### MCP 工具链

| 工具 | 功能 | 本项目使用场景 |
|------|------|---------------|
| **build** | 项目构建与验证 | 每次代码修改后自动构建、LSP 语法检查 |
| **generate_image** | AI 图片生成 | 生成游戏图标 |
| **text_to_music** | AI 音乐生成 | 生成背景音乐 |
| **text_to_sound_effect** | AI 音效生成 | 生成游戏音效（调酒、碎杯、顾客不满等） |
| **generate_game_material** | 游戏发布素材生成 | 图标、截图、宣传图 |
| **search_3d_resource** | 3D 模型资源搜索 | 可用于 3D 资源查找 |
| **lua_lsp_client** | Lua LSP 语言服务 | 代码类型检查、符号查找、诊断 |
| **publish_to_taptap** | TapTap 发布 | 一键发布到 TapTap 平台 |
| **generate_test_qrcode** | 测试二维码生成 | 手机扫码测试 |

## AI 开发能力详述

### 1. 游戏架构设计

- **模块化拆分**：将 2380 行单文件拆分为 7 个职责清晰的模块
- **依赖管理**：共享 G 表 + 函数槽注入模式，消除循环依赖
- **状态管理**：集中式可变状态管理 (State.lua 的 G 表)

### 2. NanoVG 矢量渲染

- 使用 NanoVG C API 实现全部游戏画面渲染
- 赛博朋克视觉风格：霓虹灯效果、渐变、发光描边
- 角色精灵绘制：酒保、顾客、饮品的程序化绘制
- HUD / 菜单 / 排行榜 UI 全部基于 NanoVG
- 分辨率适配：通过 `nvg-resolution-mode` skill 正确处理多 DPI 屏幕

### 3. 游戏逻辑实现

- 4 车道 Tapper 风格酒保游戏玩法
- 6 种饮品类型 + 6 个关卡递进难度
- Boss 机制 (第 6 关)
- 粒子特效系统、浮动文字反馈
- 碰撞检测与实体生命周期管理

### 4. 输入系统

- 键盘操作 (方向键 + 数字键)
- 鼠标点击与拖拽
- 触屏手势 (移动端适配)
- 音量滑块交互控制

### 5. 音频系统

- BGM 背景音乐播放与音量控制
- 多种音效 (调酒、碎杯、顾客不满等)
- 主音量 / 分音量独立控制
- 音频资源通过 `text_to_music` 和 `text_to_sound_effect` AI 生成

### 6. 云服务集成

- clientCloud API 集成：云端积分存储
- 排行榜系统：上传高分 + 拉取排行数据
- 用户昵称获取 (GetUserNickname)

### 7. Bug 修复与调试

- 多饮品顾客喝酒动画期间的碰撞检测修复
- 重复扣血 bug 修复 (wrongHitThisFrame 守卫)
- 耐心值重置逻辑修正
- 通过 `lua_lsp_client` 进行代码诊断

### 8. 代码重构

- 单文件 → 多模块架构迁移
- 全局变量 → 模块化引用转换 (~60 个变量)
- 常量提取 → Config 模块集中管理

### 9. 资源生成 (AI Generated Assets)

| 资源类型 | 生成工具 | 文件 |
|---------|---------|------|
| 游戏图标 | `generate_image` | `assets/image/cyberpunk_bar_icon_*.png` |
| 背景音乐 | `text_to_music` | `assets/audio/music_*.ogg` |
| 游戏音效 | `text_to_sound_effect` | `assets/audio/sfx/*.ogg` |

## 项目模块结构

```
scripts/
├── main.lua                 (~240 行) 入口协调器
└── CyberTapper/
    ├── Config.lua            (~65 行)  游戏常量配置
    ├── State.lua            (~160 行)  共享状态 G 表
    ├── DrawLib.lua           (~230 行)  NanoVG 绘图工具库
    ├── GameLogic.lua         (~340 行)  游戏逻辑与实体管理
    ├── Input.lua             (~270 行)  输入处理
    └── Renderer.lua          (~640 行)  全部渲染函数
```

## 依赖关系图

```
Config ──┐
         ├──► State (G) ──┬──► GameLogic ──┬──► Input
         │                │                │
DrawLib ─┘                └──► Renderer ◄──┘
                                   │
                              main.lua (入口，注入函数槽)
```

- **无循环依赖**
- **函数槽模式**：`G.PlaySfx`、`G.UploadHighScore` 等在 State.lua 中初始化为空函数，由 main.lua 注入实际实现

## 开发时间线

| 阶段 | 工作内容 |
|------|---------|
| 第 1 轮 | 项目初始化，完整游戏实现 (单文件 2380 行) |
| 第 2 轮 | AI 资源生成 (图标、音乐、音效) |
| 第 3 轮 | Bug 修复 (碰撞检测、扣血逻辑) |
| 第 4 轮 | 代码重构 (7 模块架构) |
| 第 5 轮 | 文档编写，上传 GitHub |
