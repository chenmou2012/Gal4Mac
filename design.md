# Gal4Mac — Design System & Specification Document (DESIGN.md)

> **系统名称**：Gal4Mac Liquid Glass Design System  
> **设计语言**：iOS / macOS Liquid Glass (液态玻璃) & Apple Human Interface Guidelines (HIG)  
> **适用终端**：macOS 原生桌面应用（Apple Silicon 优化，支持深色沉浸模式）  
> **核心基调**：深邃、通透、高质感、现代工程严谨性与视觉小说浪漫美学交融  

---

## 1. 设计理念与愿景 (Design Philosophy)

Gal4Mac 是专为 macOS 打造的高性能 Windows Galgame 游戏库与 Wine/GPTK 运行管理系统。为了打破传统 Wine 启动器“生硬、简陋、参数复杂”的极客工具刻板印象，本设计系统结合了 **Apple 原生桌面设计规范 (HIG)** 与 **Liquid Glass（液态玻璃）材质美学**：

1. **Liquid Glass 物理通透感**：
   - 采用多层景深模糊（`backdrop-blur-2xl` / `backdrop-blur-md`），使背景与上层窗口产生自然的流动反射光感。
   - 遵循真实光学物理定律：每个悬浮面板与卡片均包含 **1px Specular Highlight（顶部镜面反光亮边）** 与极其内敛的柔和环境投影，呈现犹如精心打磨的高级水晶面板。

2. **Apple HIG 原生操纵感**：
   - 保留标准的 macOS 左上角红黄绿交通灯控制胶囊、SF Pro 字体比例排版体系与标准 Segmented Control（分段选择器）。
   - 交互动效克制精准，遵循 `active:scale-[0.98]` 的触感微反馈，层级分离清晰。

3. **专业且人性化的工程体验**：
   - 既满足高级玩家对独立 Prefix 容器、DXVK/D3DMetal 架构切换、CJK 字体编码映射的极客掌控感；
   - 又通过直观的向导（如分卷归档缺失拦截、本地快照强制防护、游玩时长看板）保护普通玩家的存档与数据安全。

---

## 2. 色彩系统 (Color Tokens)

设计系统以苹果标志性的 **System Blue (`#0A84FF`)** 作为主色调与高亮引导，深色基底采用富有层级深度（OLED 级深黑至深蓝灰）的 Surface 梯度。

### 2.1 基础色板 (Base Palette)

| 语义 Token | Hex 值 | 用途说明 |
| :--- | :--- | :--- |
| `primary` | `#0A84FF` | 核心 CTA（如“一键启动”）、主要激活态、强操作焦点 |
| `primary-hover` | `#0071E3` | 主按钮悬浮态、高光强调 |
| `primary-container` | `rgba(10, 132, 255, 0.15)` | 次级高亮容器底色、选中标签背景 |
| `on-primary` | `#FFFFFF` | 主按钮内部文字与图标色 |
| `surface-container-lowest` | `#0D0E13` | 窗口底层基准背景、极致深暗底色 |
| `surface-container-low` | `#131319` | 侧边栏底色、背景卡片容器 |
| `surface-container` | `#1B1B22` | 标准功能卡片底色（毛玻璃基底） |
| `surface-container-high` | `#24242E` | 悬浮卡片、二级设置块背景 |
| `surface-container-highest`| `#2F2F3B` | 控件选中态、输入框、下拉菜单背景 |
| `on-surface` | `#F5F5F7` | 主要标题、高对比度主体文字 |
| `on-surface-variant` | `#A1A1AA` | 副标题、属性标签、次要说明文字 |
| `outline` | `rgba(255, 255, 255, 0.12)` | 卡片默认分割边框、微弱轮廓线 |
| `outline-variant` | `rgba(255, 255, 255, 0.06)` | 细微网格分割线、内嵌结构边框 |

### 2.2 状态与语义反馈色 (Semantic Feedback)

| 语义 Token | Hex 值 | 场景应用 |
| :--- | :--- | :--- |
| `status-success` | `#30D158` | 校验通过、运行良好、分卷齐全、Steam 云端已连接 |
| `status-warning` | `#FF9F0A` | 架构转译提示、待配置补丁、覆盖风险警示 |
| `status-error` | `#FF453A` | 缺少分卷归档（阻断导入）、运行时崩溃、文件冲突 |
| `status-info` | `#64D2FF` | 启发式推断、系统提示说明、架构映射标签 |

---

## 3. 材质、光影与圆角系统 (Material & Elevation)

### 3.1 液态玻璃材质参数 (Liquid Glass Shader & Backdrops)

```css
/* 标准液态玻璃容器卡片 */
.liquid-glass-card {
  background: rgba(27, 27, 34, 0.65);
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.08);
  box-shadow: 
    0 1px 0 0 rgba(255, 255, 255, 0.12) inset, /* 顶部高光反射 (Specular Highlight) */
    0 8px 32px 0 rgba(0, 0, 0, 0.36);           /* 柔和景深微阴影 */
}

/* 侧边导航栏材质 */
.liquid-glass-sidebar {
  background: rgba(13, 14, 19, 0.75);
  backdrop-filter: blur(30px);
  -webkit-backdrop-filter: blur(30px);
  border-right: 1px solid rgba(255, 255, 255, 0.06);
}
```

### 3.2 圆角阶梯 (Corner Radius)

- **`sm` (4px)**：状态胶囊、微型引擎 Tag、小徽章。
- **`md` (8px)**：通用按钮、下拉输入框、分段选择项。
- **`lg` (12px)**：功能小卡片、日志控制台视口、向导步骤单元。
- **`xl` (16px)**：游戏封面海报卡片、主要图表容器、大型弹窗内胆。
- **`2xl` (20px+)**：原生 macOS 模态窗口外框、主要 Hero 推荐看板。

---

## 4. 排版与字体系统 (Typography Hierarchy)

基于 Apple HIG 字体标准，采用 `Plus Jakarta Sans` 与 `SF Pro Display/Text` 风格，中日文字体完美映射系统首选字体（苹方 `PingFang SC` 与冬青黑体 `Hiragino Sans`）。

| 级别 | 大小 (Size) | 字重 (Weight) | 行高 (Line-Height) | 典型应用 |
| :--- | :--- | :--- | :--- | :--- |
| **Hero Title** | 28px / 32px | Bold (700) | 1.2 | 详情页大标题、精选游戏名（如 Aokana） |
| **Headline** | 20px / 22px | SemiBold (600) | 1.3 | 模块主标题（如“近30日游玩时长趋势”） |
| **Title Medium**| 15px / 16px | Medium (500) | 1.4 | 卡片标题、游戏名称、导航分类头 |
| **Body Standard**| 13px / 14px | Regular (400) | 1.5 | 正文描述、配置条目说明、参数注释 |
| **Label / Mono**| 11px / 12px | Medium / Regular | 1.4 | 路径 (`~/Library/...`)、日志、MD5码、Engine Badge |

---

## 5. 组件规范与交互模式 (Components Pattern)

### 5.1 侧边全局导航 (SideNavBar)
- **品牌头部**：发光蓝宝石质感 App Icon + “Gal4Mac” 文字 + “macOS Galgame Runtime Engine” 状态说明。
- **快捷启动槽 (Quick Launch)**：高权重悬浮小部件，展示最近玩过的作品与一键直达入口。
- **导航列表**：
  - 核心工作区：游戏库（`Library`）、扫描与导入（`Scan Import`）、Steam 云同步（`Steam Cloud`）、统计与日志（`Stats & Logs`）、系统设置（`Settings`）。
  - 底部状态区：显示 Wine 引擎核心版本（如 `Mythic Wine 9.4 Native`），以及诊断（`Diagnostics`）与帮助（`Help`）。

### 5.2 核心操作卡片与按钮 (Action Buttons)
- **Primary CTA (`#0A84FF`)**：
  - “一键启动 (Play)”：带有发光渐变与立体触感的药丸形主按钮，右侧配合下拉箭头支持“选择配置启动”。
  - “开始解包并加入游戏库 (Import)”：向导末尾的主行动按钮。
- **Glass Secondary Button**：
  - 玻璃磨砂质感次级按钮（`bg-surface-container-high/60 border-white/10`），用于“Finder 目录”、“浏览存档”、“Steam 元数据”。
- **Segmented Control (分段控制器)**：
  - 用于“全部游戏 / 已验证兼容 / Siglus / KiriKiri / Unity”等过滤筛选，滑动平滑过渡。

### 5.3 引擎与状态徽章 (Engine & Status Badges)
- **已验证兼容徽章**：`bg-emerald-500/15 text-emerald-400 border-emerald-500/30`，附带盾牌勾选图标。
- **引擎标签**：
  - `SiglusEngine 32-bit`（Key 作品主力，青色调）
  - `Unity 32/64-bit`（紫色调）
  - `KiriKiri 2 / Z`（橙色调）
- **缺卷拦截警告卡片**：
  - 红色警示虚线轮廓，明确标明丢失的分卷（如 `Missing volume: part3.rar`），禁止脏数据写入。

---

## 6. 核心屏幕界面设计规范清单 (Screen Manifest)

系统中已完整落地并渲染的 5 大核心界面：

1. **游戏库大厅 (Library Overview)** — `{{DATA:SCREEN:SCREEN_7}}`
   - 顶部精选 Hero Banner（当前推荐启动游戏、游玩时长、分辨率与音频状态）。
   - 筛选过滤栏与排序控件。
   - 游戏封面海报网格与底部的拖拽游戏包快速导入区域。
2. **游戏详情与运行时设置 (Game Detail & Wine Configuration)** — `{{DATA:SCREEN:SCREEN_6}}`
   - 针对《CLANNAD》等游戏的独立沙盒 Wine Prefix 管理。
   - DXVK / D3DMetal 双图形后端切换滑块。
   - 中日文 CJK 字体映射规则表（解决 Windows 弹窗乱码）、实时控制台日志与 Sysdiagnose 导出。
3. **导入与分卷校验向导 (Import Wizard & Multi-volume Check)** — `{{DATA:SCREEN:SCREEN_5}}`
   - 标准 macOS 模态向导，4 步进度流。
   - 分卷归档完整性检验系统（演示正常分卷 vs 缺失分卷的阻断状态）。
   - 启发式引擎推断置信度展示与用户自定义 UI Alias 别名输入。
4. **存档管理与 Steam 云同步 (Save Manager & Steam Cloud Bridge)** — `{{DATA:SCREEN:SCREEN_4}}`
   - Steam 官方沙盒 WebKit 云端通道安全声明。
   - 本地 APFS 快照防护面板（覆盖前强制自动备份）。
   - 云端文件 vs 本地 Bottle 文件逐项 MD5 / 修改日期 Diff 比对检视表。
5. **统计看板 (Stats & Playtime Analytics)** — `{{DATA:SCREEN:SCREEN_2}}`
   - 核心时长指标卡（总累计时长、活跃游戏数、最长会话、时长王座）。
   - 30 日时长趋势与夜间高频时段分布。
   - 各游戏时长排行条形占比与游戏引擎分布环图。
   - 本地数据离线隐私保护承诺。

---

## 7. 响应式与窗口无障碍规范 (Accessibility & Geometry)

- **基准分辨率**：标准 Desktop 视口 `1440 × 900` 及以上，原生适配 MacBook Pro Retina HiDPI 缩放（200% 整数缩放）。
- **可折叠布局**：左侧边栏支持标准态（`w-64`）与紧凑极简图标态折叠，保持快捷可用性。
- **隐私合规**：所有数据均严格限制于 `~/Library/Application Support/Gal4Mac/` 目录下，界面全流程贯彻“无云端数据上传，本地优先”的设计承诺。
