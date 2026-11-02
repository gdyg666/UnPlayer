# Shift Demo 实施计划

**目标：** 做出一个能玩的最小闭环——按住鼠标低头玩手机推进进度，老师转头看你时必须提前松手，被抓则失败，进度满则过关。

**架构：** 单个 `main.tscn`。规则与数值全放 `GameState` 自动加载单例，`player_phone.gd` 只负责"按住→低头"的状态机，`teacher.gd` 负责巡逻与视锥，`hud.gd` 只读 GameState 显示。手机 UI 先用 CanvasLayer 做，验证玩法后再升级成 SubViewport 贴到 3D 屏幕。

**技术栈：** Godot 4.7.2（Forward+，Jolt，D3D12），纯 GDScript，无外部美术资源。

**项目根：** `res://` = `D:\GodotProjects\un_player\un-player`

## 全局约束

- 所有几何体用 `BoxMesh` / `QuadMesh` / `CapsuleMesh` + 纯色 `StandardMaterial3D`，不导入任何模型贴图。
- 所有可调数值写成 `game_state.gd` 顶部的 `const`，禁止散落在场景里。
- 状态机用 `enum` + `match`，不用 AnimationTree、不用 Tween 节点。
- 视觉层级最多到"能看清几何和状态"，不做材质、不用 Environment 后处理。
- 每个任务结束时工程必须能按 F5 跑起来，不允许中间态报错。

## 核心数值（先写死，T8 再调）

| 项 | 值 | 含义 |
|---|---|---|
| `TRANSITION_TIME` | 0.35 s | 抬起/放下手机的过渡时长 |
| `EXPOSURE_HIDDEN` | 0.0 | 收手时暴露度 |
| `EXPOSURE_PHONE` | 1.0 | 举着手机时暴露度 |
| `EXPOSURE_TRANSITION` | 0.6 | 过渡中的暴露度（主题所在） |
| `TYPE_RATE` | 0.28 /s | 打字进度增速（约 3.6 秒一条） |
| `ATTACK_RATE` | 1.2 /s | 被注视时注意值增速 |
| `DECAY_RATE` | 0.8 /s | 安全时注意值衰减 |
| `CATCH_THRESHOLD` | 1.0 | 注意值到此被抓 |
| `FOV_HALF_ANGLE` | 30° | 半视角 |
| `SIGHT_RANGE` | 8.0 m | 可视距离 |
| `WALK_TIME` | 3.0 s | 每段移动耗时 |
| `IDLE_TIME` | 2.0 s | 每个巡逻点停留时长 |

## 场景结构（T1 一次建好骨架）

```
Main (Node3D)                     main.gd
├── World (Node3D)
│   ├── Floor        MeshInstance3D   BoxMesh 12 × 0.2 × 10   position (0, -0.1, 0)
│   ├── BackWall     MeshInstance3D   BoxMesh 12 × 3 × 0.2    position (0, 1.5, -5)
│   ├── Blackboard   MeshInstance3D   BoxMesh 4 × 1.2 × 0.05  position (0, 1.6, -4.85)
│   ├── Desk         MeshInstance3D   BoxMesh 1.6 × 0.05 × 0.7 position (0, 0.75, -0.6)
│   └── DeskLeg      MeshInstance3D   BoxMesh 0.06 × 0.75 × 0.06 ×2
├── Player (Node3D)                player_phone.gd   position (0, 1.2, 0)
│   └── Camera3D     current = true
│       └── PhoneRig (Node3D)      position (0, -0.2, -0.4)
│           ├── PhoneBody     MeshInstance3D  BoxMesh 0.075 × 0.15 × 0.008
│           └── PhoneScreen   MeshInstance3D  QuadMesh 0.068 × 0.13
├── Teacher (Node3D)               teacher.gd   position (0, 0, -4)
│   ├── Body         MeshInstance3D  CapsuleMesh radius 0.25 height 1.7
│   └── Patrol (Node3D)
│       ├── P1       Marker3D  (-2.0, 0, -3.5)
│       ├── P2       Marker3D  ( 2.0, 0, -3.5)
│       └── P3       Marker3D  ( 0.0, 0, -2.5)
└── HUD (CanvasLayer)              hud.gd
    ├── AttentionBar  ProgressBar  max_value 1
    ├── ProgressBar   ProgressBar  max_value 1
    ├── Hint          Label
    └── PhoneUI       Control      （T7 搬进 SubViewport）
```

---

### 任务 1：灰盒教室 + 座位机位

**文件：** 新建 `main.tscn`、`scripts/main.gd`

- [ ] 步骤 1：新建 3D 场景，根节点改名 `Main`，挂 `scripts/main.gd`（暂时空脚本）
- [ ] 步骤 2：按上面骨架建 `World` 下的 5 个 MeshInstance3D，逐个设 `mesh` 和 `position`
- [ ] 步骤 3：建 `Player` + `Camera3D`，`position (0, 1.2, 0)`，勾选 `current`
- [ ] 步骤 4：相机 `rotation_degrees.x = -5`，FOV 保持 75
- [ ] 步骤 5：给 World 下每个 Mesh 一个纯色材质（地板灰、墙米白、黑板深绿、桌子棕），`albedo_color` 随便选
- [ ] 步骤 6：Project Settings → Application → Run → Main Scene 设为 `res://main.tscn`，按 F5

**验收：** 运行后视野里能同时看到桌面（下方）、黑板（正前方）、左右两侧地面。看不到黑板说明机位太高或桌子位置不对。

---

### 任务 2：手持手机 + 状态机

**文件：** 新建 `scripts/game_state.gd`、`scripts/player_phone.gd`

**Interfaces：**
- `GameState` 提供：`exposure: float`（每帧由玩家脚本写）、`attention: float`、`progress: float`、`enabled: bool`
- `player_phone.gd` 消费 `GameState.const`，向 `GameState.exposure` 写值

- [ ] 步骤 1：Project Settings → Globals → Autoload，加 `scripts/game_state.gd`，节点名 `GameState`
- [ ] 步骤 2：在 `game_state.gd` 顶部写完全部 `const`（见数值表），并声明 `var exposure := 0.0`、`var attention := 0.0`、`var progress := 0.0`、`var enabled := true`
- [ ] 步骤 3：Project Settings → Input Map 新建 action `type_message`，绑鼠标左键
- [ ] 步骤 4：`player_phone.gd` 用 `enum State { HIDDEN, RAISING, PHONE, LOWERING }` 实现状态机；`_physics_process(delta)` 里按"输入按下→目标 PHONE、松开→目标 HIDDEN"推进状态与 0.35 秒计时
- [ ] 步骤 5：同脚本每帧用 `lerp` 把 `Camera3D.rotation_degrees.x` 从 -5 拉向 -40（PHONE）或 -5（HIDDEN）
- [ ] 步骤 6：`PhoneRig.visible` 在 HIDDEN 时关、其余开
- [ ] 步骤 7：每帧把当前状态对应的暴露度写进 `GameState.exposure`

**验收：** 按住左键，镜头平滑低头（约 0.35 秒到位），手机方块进入视野；松开，镜头抬起、手机消失。过渡中途松手再按，状态不能卡死。

---

### 任务 3：老师巡逻

**文件：** `scripts/teacher.gd`（挂在 Teacher 上）

**Interfaces：**
- 消费 `GameState` 的常量；对外只暴露 `var player: Node3D`

- [ ] 步骤 1：`_ready()` 里把 `Patrol` 下 3 个 Marker3D 收进数组，记录 `current_index := 0`
- [ ] 步骤 2：用 `_physics_process(delta)` 实现"走 3 秒 → 停 2 秒"循环：移动阶段 `position = lerp(起点, 终点, t/WALK_TIME)`，朝向用 `look_at` 指向移动方向
- [ ] 步骤 3：停留阶段用 `lerp` 让朝向平滑转向 `player.global_position`
- [ ] 步骤 4：在 `Main` 的 `_ready()` 里把 Player 赋给 `Teacher.player`

**验收：** 老师方块在 3 个点之间来回走，每到一个点就站起来面向玩家 2 秒再走。走的方向是沿黑板水平移动。

---

### 任务 4：视锥 + 注意值 + 被抓

**文件：** 改 `teacher.gd`，新建 `scripts/hud.gd`

- [ ] 步骤 1：`teacher.gd` 每帧算 `to_player = player.global_position - global_position`；`in_cone = to_player.length() <= SIGHT_RANGE and (-global_basis.z).dot(to_player.normalized()) >= cos(deg_to_rad(FOV_HALF_ANGLE))`
- [ ] 步骤 2：`in_cone and GameState.exposure > 0` → `attention += exposure * ATTACK_RATE * delta`；否则 `attention -= DECAY_RATE * delta`，结果 `clamp(0, CATCH_THRESHOLD)`
- [ ] 步骤 3：`attention >= CATCH_THRESHOLD` 时把 `GameState.enabled = false`，发一个自定义信号 `caught`
- [ ] 步骤 4：`hud.gd` 每帧把 `GameState.attention` 写进 `AttentionBar.value`，`GameState.progress` 写进 `ProgressBar.value`
- [ ] 步骤 5：`Hint` 标签在 `enabled == false` 时显示"她看见你了 — 按 R 重开"

**验收：** 按住左键不放并等老师转身，注意条在 1 秒内涨满，提示出现，输入失效。老师背对时注意条回落。

---

### 任务 5：打字进度 + 过关 + 重开

**文件：** 改 `game_state.gd`、`player_phone.gd`、`main.gd`

- [ ] 步骤 1：`player_phone.gd` 在 `State.PHONE` 且 `GameState.enabled` 时 `GameState.progress += TYPE_RATE * delta`
- [ ] 步骤 2：`GameState.progress >= 1.0` 时置 `enabled = false`，`Hint` 显示"发出去了"
- [ ] 步骤 3：`main.gd` 里处理 `R` 键 → `get_tree().reload_current_scene()`
- [ ] 步骤 4：`GameState` 提供 `reset()`，`_ready()` 时调用，保证重开干净

**验收：** 一次成功：老师走到远处时按住，注意条涨起来就松手，来回 2–3 次后进度满，出现过关提示。一次失败：故意在老师停留时按住，被抓。

---

### 任务 6：手机 UI（CanvasLayer 版）

**文件：** 新建 `ui/phone_ui.tscn`、`scripts/phone_ui.gd`

- [ ] 步骤 1：建一个 `ColorRect`（深墨绿 #0b1a12）+ `Label`（等宽字体，浅绿 #7dffa0），文字先写死"MIA：你在干嘛"
- [ ] 步骤 2：再放一个细 `ProgressBar`，`show_percentage = false`，代表打字进度
- [ ] 步骤 3：把 `phone_ui.tscn` 实例化到 `HUD/PhoneUI` 下，尺寸占屏幕下半部 1/3
- [ ] 步骤 4：`phone_ui.gd` 每帧跟 `GameState.progress` 同步进度条，并在 `State.PHONE` 时淡入、否则淡出
- [ ] 步骤 5：输出文字随进度变化：0–33% "MIA：你在干嘛"，33–66% "你：在上课"，66–99% "你：等下说"

**验收：** 低头时手机界面淡入并显示消息逐条推进，抬头时淡出。这一步之后玩法已经完整可玩。

---

### 任务 7：升级成 3D 手机屏（可选，但这是视觉签名）

**文件：** 改 `main.tscn`、`player_phone.gd`

- [ ] 步骤 1：在 `Main` 下加 `SubViewport`，尺寸 512 × 1024，`render_target_update_mode = Always`，`transparent_bg = false`
- [ ] 步骤 2：把 `HUD/PhoneUI` 整个节点移到 SubViewport 下
- [ ] 步骤 3：`PhoneScreen` 的材质换成 `StandardMaterial3D`，`shading_mode = Unshaded`，`albedo_texture = New ViewportTexture`，路径指向上一步的 SubViewport
- [ ] 步骤 4：材质里 `texture_filter = Nearest`，避免屏幕文字发糊
- [ ] 步骤 5：`PhoneScreen` 的 UV 若上下颠倒，把 QuadMesh 绕 X 轴转 180°

**验收：** 低头看到 3D 手机屏幕上显示同样的绿色界面，抬头收手后屏幕跟着移出视野。UI 不再浮在屏幕上。

---

### 任务 8：调参 pass

**文件：** 只改 `game_state.gd` 的 const

- [ ] 步骤 1：连续玩 5 次，记录每次的失败原因（没来得及松手 / 贪了一下 / 看不懂老师朝向）
- [ ] 步骤 2：按记录只调 1–2 个值：太简单就 `ATTACK_RATE` 上调或 `IDLE_TIME` 延长；太难就 `TYPE_RATE` 上调或 `TRANSITION_TIME` 缩短
- [ ] 步骤 3：目标手感——一次通关需要 2–3 次切换，失败发生在"再按一下就好了"的时刻

**验收：** 连续 3 次游玩，每次都能说清自己为什么被抓。

---

## 不做（本次范围内）

多 App、真键盘、老师寻路、遮挡射线、音效、动画、低多边形美术、弹窗剧情、存档。这些都不影响核心循环是否成立。

## 验证方式

每个任务只认一个证据：F5 运行后亲眼看到验收描述里的现象。看不到就不算完成，不靠"代码写了"判断。
