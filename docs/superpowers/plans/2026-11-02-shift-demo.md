Z# Shift Demo 实施计划

**目标：** 做出一个能玩的最小闭环——按住鼠标低头玩手机推进进度，老师转头看你时必须提前松手，被抓则失败，进度满则过关。

**架构：** 5 个独立场景。单例 `GameState` 只存**游戏阶段**和**信号**，不存任何连续数值。每个系统自己管自己的数值（玩家管暴露度和进度，老师管注意值），跨系统只在需要时用 `@export` 拖引用或发信号。**只有 `GameState` 能宣布阶段变化**，且重复宣布无效。

**技术栈：** Godot 4.7.2（Forward+，Jolt，D3D12），纯 GDScript，无外部美术资源。

**项目根：** `res://` = `D:\GodotProjects\un_player\un-player`

## 全局约束

- 所有几何体用 `BoxMesh` / `QuadMesh` / `CapsuleMesh` + 纯色 `StandardMaterial3D`，不导入任何模型贴图。
- **参数分两类放置：** 规则数值放 `config/tuning.tres`；某个节点自己的表现参数（过渡时长、俯角、视野角、走速）放它自己场景的 `@export`。
- **节点引用：** 场景内部随便用 `$Body`；跨场景一律 `@export` 在编辑器里拖，**禁止** `get_node("../../Player")` 或 group 字符串查找。
- 状态机用 `enum` + `match`，不用 AnimationTree、不用 Tween 节点。
- **阶段唯一入口：** 谁都可以发现自己输了，但只能调 `GameState.set_phase()` 宣布；它内部判断重复宣布并直接返回。
- 每个场景必须能单独 F6 运行不报错（引用为空时按空处理）。
- 每个任务结束时工程必须能按 F5 跑起来。

## 目录结构

```
res://
├── config/tuning.tres
├── game/
│   ├── main.tscn      main.gd
│   ├── player.tscn    player_phone.gd
│   ├── teacher.tscn   teacher.gd
│   └── hud.tscn       hud.gd
├── ui/phone_ui.tscn   phone_ui.gd
└── scripts/
    ├── tuning.gd      class_name Tuning extends Resource
    └── game_state.gd  (Autoload: GameState)
```

## 单例里有什么（只有这些）

`game_state.gd`

| 成员 | 类型 | 说明 |
|---|---|---|
| `phase` | `Phase` 枚举 | `PLAYING` / `PAUSED` / `WON` / `CAUGHT` |
| `set_phase(p)` | 方法 | **唯一改 phase 的入口**，同值直接返回 |
| `is_playing()` | 方法 | `phase == PLAYING` |
| `reset()` | 方法 | 回到 `PLAYING` |
| `phase_changed(new)` | 信号 | 阶段变化时发一次 |
| `caught` | 信号 | 进入 `CAUGHT` 时发 |
| `won` | 信号 | 进入 `WON` 时发 |

**单例里不放：** `attention`、`progress`、`exposure`、`typing`、`watched`、任何 `float` 数值。

## 数值归属

| 数值 | 住在哪 | 谁能改 |
|---|---|---|
| `exposure`、`typing`、`progress` | `player.tscn` 根脚本的公开变量 | 玩家自己 |
| `attention` | `teacher.tscn` 根脚本的公开变量 | 老师自己 |
| `type_rate` `attack_rate` `decay_rate` `catch_threshold` | `config/tuning.tres` | 你，检查器里改 |

## 通信契约

| 文件 | 自己存 | 读别人 | 发出的信号 | 监听 |
|---|---|---|---|---|
| `game_state.gd` | `phase` | — | `phase_changed` `caught` `won` | — |
| `main.gd` | — | 无 | — | 把两个系统的信号路由给 GameState |
| `player.tscn` | `exposure` `typing` `progress` | `GameState.is_playing()` | `finished` | `GameState.phase_changed` |
| `teacher.tscn` | `attention` | `player.exposure`、`GameState.is_playing()` | `caught_player` | `GameState.phase_changed` |
| `hud.tscn` | — | `player.progress`、`teacher.attention` | — | `GameState.caught` `won` |
| `phone_ui.tscn` | — | `player.progress` | — | — |

跨场景 `@export` 引用一共 4 根：

1. `teacher.player` ← Player
2. `hud.player` ← Player
3. `hud.teacher` ← Teacher
4. `main.player` / `main.teacher` ← 两个实例（用于信号路由）

## 参数表

**`config/tuning.tres`**

| 字段 | 默认 | 含义 |
|---|---|---|
| `type_rate` | 0.28 | 打字进度增速（约 3.6 秒一条） |
| `attack_rate` | 1.2 | 被注视时注意值增速 |
| `decay_rate` | 0.8 | 安全时注意值衰减 |
| `catch_threshold` | 1.0 | 注意值到此被抓 |

**`player.tscn` 的 `@export`**

| 字段 | 默认 | 含义 |
|---|---|---|
| `transition_time` | 0.35 | 抬起/放下手机的过渡时长（秒） |
| `exposure_hidden` | 0.0 | 收手时暴露度 |
| `exposure_phone` | 1.0 | 举着手机时暴露度 |
| `exposure_transition` | 0.6 | 过渡中的暴露度（主题所在） |
| `cam_pitch_hidden` | -5.0 | 抬头时的相机俯角 |
| `cam_pitch_phone` | -35.0 | 低头时的相机俯角 |
| `rig_pos_hidden` | (0, -0.55, -0.4) | 手机在画面外时的局部位置 |
| `rig_pos_phone` | (0, -0.20, -0.35) | 手机举到眼前时的局部位置 |

**`teacher.tscn` 的 `@export`**

| 字段 | 默认 | 含义 |
|---|---|---|
| `walk_time` | 3.0 | 每段移动耗时（秒） |
| `idle_time` | 2.0 | 每个巡逻点停留时长（秒） |
| `fov_half_angle` | 30.0 | 半视角（度） |
| `sight_range` | 8.0 | 可视距离（米） |

## 场景结构

**main.tscn**（已建：Floor / Backwall / Blackboard / Desk / 4 条 DeskLeg）
```
Main (Node3D)              main.gd
├── World (Node3D)         ← 灰盒教室，已存在
├── Player  (实例 player.tscn)     position (0, 1.2, 0)
├── Teacher (实例 teacher.tscn)    position (0, 0, -4)
└── HUD     (实例 hud.tscn)
```

**player.tscn**
```
Player (Node3D)            player_phone.gd
└── Camera3D               current = true, near = 0.01
    └── PhoneRig (Node3D)
        ├── PhoneBody     MeshInstance3D  BoxMesh 0.075 × 0.15 × 0.008
        └── PhoneScreen   MeshInstance3D  QuadMesh 0.068 × 0.13
```

**teacher.tscn**
```
Teacher (Node3D)           teacher.gd
├── Body (MeshInstance3D)  CapsuleMesh r=0.25 h=1.7, position (0, 0.85, 0)
└── Patrol (Node3D)
    ├── P1 (Marker3D)      (-2.0, 0, -3.5)
    ├── P2 (Marker3D)      ( 2.0, 0, -3.5)
    └── P3 (Marker3D)      ( 0.0, 0, -2.5)
```

**hud.tscn**
```
HUD (CanvasLayer)          hud.gd
├── AttentionBar (ProgressBar)  max_value 1
├── ProgressBar  (ProgressBar)  max_value 1
├── Hint         (Label)
└── PhoneUI      (实例 phone_ui.tscn)   ← T9 整体搬到 SubViewport
```

---

### 任务 1：灰盒教室（进行中）

**文件：** `game/main.tscn`

- [x] 步骤 1：建 `Main` + `World`，地板、后墙、黑板、桌子、4 条桌腿
- [ ] 步骤 2：加临时 `Camera3D`，`position (0, 1.2, 0)`，`rotation_degrees.x = -5`，勾 `current`
- [ ] 步骤 3：给每个 Mesh 上纯色材质（地板灰、墙米白、黑板深绿、桌子棕）
- [ ] 步骤 4：设 Main Scene 为 `res://game/main.tscn`，按 F5

**验收：** 画面里同时有桌面、黑板、两侧地面。全黑说明相机没设 current。

---

### 任务 2：Tuning 资源 + GameState

**文件：** 新建 `scripts/tuning.gd`、`config/tuning.tres`、`scripts/game_state.gd`

- [ ] 步骤 1：写 `tuning.gd`（`class_name Tuning`、`extends Resource`、4 个 `@export var`，默认值照参数表）
- [ ] 步骤 2：检查器 新建 Resource → `Tuning` → 保存为 `res://config/tuning.tres`
- [ ] 步骤 3：写 `game_state.gd`：`enum Phase`、`var phase`、`signal` 三个、`set_phase()`、`is_playing()`、`reset()`；**不要写任何数值变量**
- [ ] 步骤 4：`set_phase()` 里 `if p == phase: return`，然后按新值发 `caught` / `won`，最后发 `phase_changed`
- [ ] 步骤 5：Autoload 加 `scripts/game_state.gd`，名字 `GameState`
- [ ] 步骤 6：Input Map 建 action `type_message`，绑鼠标左键

**验收：** 检查器能打开并修改 `tuning.tres` 的 4 个字段。F5 不报错。

---

### 任务 3：player.tscn

**文件：** 新建 `game/player.tscn`、`game/player_phone.gd`

**Interfaces：**
- 公开变量：`exposure: float`、`typing: bool`、`progress: float`
- 信号：`signal finished`（progress 到 1.0 时发一次）

- [ ] 步骤 1：建 `player.tscn`（结构见上），挂脚本
- [ ] 步骤 2：8 个表现参数写成 `@export`，默认值照参数表
- [ ] 步骤 3：`enum State { HIDDEN, RAISING, PHONE, LOWERING }`，输入按下→目标 PHONE，松开→目标 HIDDEN，过渡 `transition_time`
- [ ] 步骤 4：每帧按状态插值相机 `rotation_degrees.x` 和 `PhoneRig.position`，**不用 visible 开关**
- [ ] 步骤 5：每帧写自己的 `exposure`（0 / 0.6 / 1.0）和 `typing`
- [ ] 步骤 6：`GameState.is_playing() and typing` 时 `progress += Tuning.type_rate * dt`；到 1.0 发 `finished` 并停下
- [ ] 步骤 7：实例化进 `main.tscn`，位置 `(0, 1.2, 0)`，删掉 T1 的临时相机

**验收：** F5 按住左键低头、手机从画面下方滑入；松开回位。过渡中途松手再按不卡死。改 `transition_time` 立刻影响手感。F6 单跑不报错。

---

### 任务 4：teacher.tscn 巡逻

**文件：** 新建 `game/teacher.tscn`、`game/teacher.gd`

- [ ] 步骤 1：建 `teacher.tscn`（结构见上），挂脚本，实例化进 `main.tscn`，位置 `(0, 0, -4)`
- [ ] 步骤 2：`@export var player: Node3D`，**在 `main.tscn` 里选中 Teacher 把 Player 拖进去**
- [ ] 步骤 3：4 个行为参数写成 `@export`
- [ ] 步骤 4：`_ready()` 收集 3 个 Marker3D
- [ ] 步骤 5：`_physics_process` 实现"走 `walk_time` → 停 `idle_time`"，移动用 `lerp`，`look_at` 朝移动方向
- [ ] 步骤 6：停留阶段平滑转向 `player`；`player == null` 时保持朝向跳过

**验收：** 老师方块 3 点间来回走，每点停 2 秒并面向玩家。把 `walk_time` 改成 1.0 走速立刻变。F6 单跑不报错。

---

### 任务 5：视锥 + 注意值

**文件：** 改 `game/teacher.gd`

- [ ] 步骤 1：加公开变量 `attention: float` 和 `signal caught_player`
- [ ] 步骤 2：每帧算 `in_cone`：`to_player.length() <= sight_range` 且 `(-global_basis.z).dot(to_player.normalized()) >= cos(deg_to_rad(fov_half_angle))`
- [ ] 步骤 3：`GameState.is_playing() and in_cone and player.exposure > 0` → `attention += player.exposure * tuning.attack_rate * dt`，否则 `attention -= tuning.decay_rate * dt`，`clamp(0, tuning.catch_threshold)`
- [ ] 步骤 4：`attention >= tuning.catch_threshold` → `clamp` 住并发一次 `caught_player`
- [ ] 步骤 5：`GameState.phase_changed` 时若不在 `PLAYING` 则 `attention = 0` 并停手

**验收：** 先临时在 main 里把 `caught_player` 连到 `print`，按住左键等老师转头，注意值涨满打印一次（只打印一次）。

---

### 任务 6：hud.tscn

**文件：** 新建 `game/hud.tscn`、`game/hud.gd`

- [ ] 步骤 1：建 `hud.tscn`，根 `CanvasLayer`，挂脚本，实例化进 `main.tscn`
- [ ] 步骤 2：两个 `ProgressBar`（`max_value = 1`，`show_percentage = false`）+ 一个 `Label`
- [ ] 步骤 3：加 `@export var player: Node3D`、`@export var teacher: Node3D`，在 `main.tscn` 里拖进去
- [ ] 步骤 4：`_process` 每帧读 `player.progress` 和 `teacher.attention` 写进进度条；引用为空时跳过
- [ ] 步骤 5：注意条上色：< 0.5 灰，≥ 0.5 橙，到 1 红

**验收：** 按住左键注意条真的在涨，松开回落；进度条同步涨。

---

### 任务 7：阶段路由 + 重开

**文件：** 改 `game/main.gd`

- [ ] 步骤 1：加 `@export var player: Node3D`、`@export var teacher: Node3D`，在 `main.tscn` 里拖进去
- [ ] 步骤 2：`_ready()` 里 `GameState.reset()`，并把 `teacher.caught_player` 连到 `GameState.set_phase(CAUGHT)`、`player.finished` 连到 `GameState.set_phase(WON)`
- [ ] 步骤 3：`hud.gd` 连 `GameState.caught` / `won`，`Hint` 分别显示"她看见你了" / "发出去了"
- [ ] 步骤 4：`main.gd` 的 `_input` 监听 `R` → `get_tree().reload_current_scene()`

**验收：** 完整通关一次；故意被抓一次；两种结局提示都正确；按 R 干净重开（数值归零、老师回起点）。

---

### 任务 8：phone_ui.tscn

**文件：** 新建 `ui/phone_ui.tscn`、`ui/phone_ui.gd`

- [ ] 步骤 1：`Control` 场景，`ColorRect`（#0b1a12）铺满 + `Label`（#7dffa0，等宽字体）
- [ ] 步骤 2：加一条细 `ProgressBar`（`show_percentage = false`）
- [ ] 步骤 3：`@export var player: Node3D`，每帧读 `player.progress` 同步进度，文字分三段切换
- [ ] 步骤 4：实例化到 `hud.tscn`，占屏幕下半部 1/3，`modulate.a` 随手机状态淡入淡出

**验收：** 低头时界面淡入、消息逐条推进；抬头淡出。**这一步之后玩法完整可玩。**

---

### 任务 9：升级成 3D 手机屏

**文件：** 改 `game/player.tscn`、`game/hud.tscn`

- [ ] 步骤 1：`player.tscn` 里 `PhoneScreen` 旁加 `SubViewport`（512 × 1024，`render_target_update_mode = Always`）
- [ ] 步骤 2：把 `hud.tscn` 里的 `PhoneUI` 实例整体移到该 SubViewport 下
- [ ] 步骤 3：`PhoneScreen` 材质换 `StandardMaterial3D`，`Shading Mode = Unshaded`，`albedo_texture = New ViewportTexture` 指向 SubViewport，`texture_filter = Nearest`
- [ ] 步骤 4：UV 若上下颠倒，QuadMesh 绕 X 轴转 180°

**验收：** 低头看到 3D 手机屏上的绿色界面，抬头后随手机移出视野。

---

### 任务 10：调参 pass

**文件：** 只改 `tuning.tres` 和场景 `@export`

- [ ] 步骤 1：连玩 5 次，记录失败原因
- [ ] 步骤 2：按记录只调 1–2 个值：太简单调高 `attack_rate` 或 `idle_time`；太难调高 `type_rate` 或缩短 `transition_time`
- [ ] 步骤 3：目标手感——一次通关要 2–3 次切换，失败发生在"再按一下就好了"的瞬间

**验收：** 连续 3 次游玩，每次都能说清自己为什么被抓。

---

## 不做（本次范围内）

多 App、真键盘、老师寻路、遮挡射线、音效、动画、低多边形美术、剧情分支、存档。

## 验证方式

每个任务只认一个证据：F5 运行后亲眼看到验收描述里的现象。看不到就不算完成，不靠"代码写了"判断。
