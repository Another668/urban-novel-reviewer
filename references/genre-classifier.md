# 网文类型智能识别与模板映射（Genre Classifier）

审稿第2步的执行手册：对被审内容做自动类型识别 → 打分判定主/辅类型 → 映射加载对应审稿模板。模板全部来自整合进本技能的 silver-novel-skills 模板库（见文末目录），离线可用、跨设备一致。

---

## 〇、题材缓存快速路由（v3.9.0，第二次及以后审稿必走）

**同一本书的题材不会每章都变。识别一次、缓存复用，跳过全量打分。**

### 路由流程

```text
读取 .review-db/meta.json 的 cached_genre 字段
  ├─ 无缓存（首次审稿）→ 走下方第一节完整识别流程 → 结果写入 meta.json.cached_genre
  └─ 有缓存 且 confidence ≥ 80%
       → 快速校验：抽取被审文本 5-8 个强信号词，与缓存的 main_type 强信号表比对
           ├─ 命中 ≥3 个（或 ≥50%）→ 校验通过，直接按缓存加载模板（跳过打分）
           └─ 命中 <3 个 → 疑似题材漂移 → 回退完整识别流程
                ├─ 识别结果与缓存一致 → 更新 last_verified_ch，继续用缓存
                └─ 识别结果不同 → 报告标注「⚠️ 题材漂移：缓存为X，本章识别为Y」→ 用新结果并更新缓存
```

### cached_genre 字段结构

```json
{
  "cached_genre": {
    "channel": "男频",
    "main_type": "都市日常",
    "sub_type": "商战",
    "confidence": 92,
    "templates": ["male/templates/genres/dushi.md", "male/templates/antagonist_design.md"],
    "agents": ["shared/agents/review/logic_checker.md", "shared/agents/review/conflict_checker.md"],
    "first_identified_ch": 1,
    "last_verified_ch": 45
  }
}
```

**缓存写入时机**：首次完整识别后立即写入；每次快速校验通过后更新 `last_verified_ch`；漂移重识别后覆盖更新。混合题材（双主类型权重接近）不缓存 main_type，每次都走完整识别。

**收益**：跳过全量信号打分与推理，每次审稿节省 ~150-200 token；首次审稿流程与原版完全一致，零学习成本。

---

## 一、识别流程（三步，不得跳步）

1. **频道判定**：先判男频 / 女频（决定模板库分支 male/ 还是 female/）。
2. **题材打分**：用第二节信号词表对每个候选题材加权计分，得出主类型 + 辅类型。
3. **模板加载**：按第四节映射表 Read 对应模板文件，把模板中的"审稿雷区 / 评价标准"转为检查清单执行；混合题材叠加加载。

判定结果必须在报告"题材识别"行写明，格式：
`主类型X（得分S1，权重%）+ 辅类型Y（得分S2，权重%）｜频道：男频/女频｜已加载模板：文件列表`

---

## 二、频道判定信号

| 信号 | 男频倾向 | 女频倾向 |
|------|---------|---------|
| 主视角 | 男主第一/第三人称，目标=变强/赚钱/登顶 | 女主或双男主/双女主视角，目标=情感/关系 |
| 核心驱动力 | 升级、打脸、资源获取、谜题破解 | 感情线推进、关系变化、情绪价值 |
| 章节高潮形态 | 战斗/谈判/揭秘/实力展示 | 心动/误会/和解/关系突破 |
| 读者功能 | 爽感（掌控、逆袭、碾压） | 嗑感（暧昧、拉扯、甜虐） |
| 高频词 | 修为、境界、系统提示、项目、股份、对手 | 他/她的眼神、心跳、关系、吃醋、告白、CP |

- 频道得分 = 男频信号命中数 vs 女频信号命中数，取高者；差距 ≤1 判为**跨频道**，主流程走高得分分支，另分支只加载核心专项模板（见第四节跨频道规则）。

---

## 三、题材打分表

每个候选题材按"强信号 +3 / 中信号 +2 / 弱信号 +1"累计，统计被审文本（多章审时取全部样本章节）。

### 男频题材

| 题材 | 强信号（+3） | 中信号（+2） | 弱信号（+1） |
|------|-------------|-------------|-------------|
| 都市日常 | 校园/职场/家庭生活流、无超自然、事件小 | 室友/同事/同学群像、吐槽、生活费/考勤 | 现代都市背景、吃穿住行细节 |
| 高武 | 武道境界、气血/战力数值、武馆/武考、异兽入侵现代都市 | 修炼资源、排行榜、强者为尊的现代社会 | 打斗、异能管理局类机构 |
| 异能/都市异能 | 系统、面板、异能觉醒、灵气复苏、修真传承在都市 | 任务发布、点数/抽奖、隐藏身份 | 超自然事件、非常规能力 |
| 商战 | 公司、股权、谈判、融资、竞标、商业模式 | 职场晋升、甲乙方、老板/董事、合同 | 赚钱、项目、行业术语 |
| 娱乐圈 | 明星、拍戏、综艺、粉丝、热搜、经纪公司 | 剧本、票房、代言、黑粉 | 演艺圈背景 |
| 玄幻 | 异世大陆、宗门、斗气/魔法、种族 | 丹药、功法、大陆地图 | 强者、修炼（非现代背景） |
| 仙侠 | 修真、飞剑、仙门、渡劫、灵石 | 道友、法力、洞府 | 古风超自然 |
| 悬疑 | 命案、推理、反转、线索链、侦探/法医 | 密室、不在场证明、连环案 | 悬念、调查 |
| 穿越/重生 | 重生回到过去、穿越异世、历史知识碾压 | 前世记忆、弥补遗憾 | 年代差异 |
| 游戏 | 电竞、网游、虚拟舱、赛事、副本 | 段位、公会、直播 | 游戏术语 |
| 科幻 | 星际、机甲、未来科技、外星文明 | 基因、飞船、赛博 | 未来设定 |
| 历史 | 古代朝堂、权谋、架空王朝 | 科举、封侯、边军 | 古风非修仙 |
| 恐怖灵异 | 鬼、灵异事件、副本规则、茅山 | 凶宅、诅咒、纸人 | 恐怖氛围 |
| 公路求生·克苏鲁向（v3.6.0） | 公路/载具求生为核心舞台、线性公路节点（服务区/隧道/加油站）、SAN 值/理智值面板、成体系行车规则与路牌禁忌 | 燃油/食物/零件资源消耗与搜刮、载具改装升级、收音机异常频段、异常路牌/后视镜影子、夜间行驶 | 末世/诡异背景、移动推进叙事、循环路段、废弃车辆遗留物、认知污染氛围 |

### 女频题材

| 题材 | 强信号（+3） | 中信号（+2） | 弱信号（+1） |
|------|-------------|-------------|-------------|
| 现代言情/恋爱 | CP互动为核心、总裁/校园/都市恋爱、暧昧心动 | 吃醋、告白、约会、双箭头 | 感情线占比高 |
| 古代言情 | 古代背景恋爱、王爷/公主/宫廷 | 及笄、赐婚、宅院 | 古风 + 感情线 |
| 耽美(BL) | 双男主恋爱、攻受、他×他 | 双男主无女主、兄弟情变质 | 男性CP |
| 百合(GL) | 双女主恋爱、她×她 | 女性CP、闺蜜变质 | 女性双主 |
| 女尊/女强 | 女强世界、性别反转、女主登顶 | 女帝、女官体系 | 强势女主+权力 |
| 快穿/穿书 | 系统、多个世界、任务者、攻略目标 | 原著剧情、炮灰逆袭、宿主 | 世界切换 |
| 悬疑恋爱 | 推理+感情并行、甜蜜惊悚 | 案件中的CP、嫌疑人男主 | 悬念+恋爱 |
| 女频仙侠 | 女主修仙、仙门恋、师徒 | 飞升、灵根+感情线 | 古风超自然+女主 |

**判定规则**：
- 最高分题材 = 主类型；得分 ≥ 主类型 60% 的其他题材 = 辅类型（混合题材）。
- 用户在记忆文档/大纲中已声明题材的，以声明为准，识别结果仅作校验（声明与文本严重不符时在报告中提示"题材漂移"）。
- 非都市题材（玄幻/古言/科幻等）识别置信度高时：本技能都市矩阵降权，改以 silver 对应题材模板 + 通用 13 维审稿 agent 为主，并提示用户"非都市题材，建议转通用审计技能做长篇专项"。

---

## 四、类型 → 模板映射表

模板根目录：`references/templates/`（silver-novel-skills 模板库离线副本）。加载时先 Read 该分支 INDEX.md 确认文件，再 Read 具体模板。

### 男频映射

| 识别类型 | 题材模板（必加载） | 专项模板（按命中叠加） | 专项审稿 agent |
|---------|------------------|---------------------|---------------|
| 都市日常 | `male/templates/genres/dushi.md` | `shared/templates/writing_craft/depth_balance.md`、`shared/templates/writing_craft/scene_craft.md` | `shared/agents/review/pace_critic.md`、`shared/agents/review/description_quality_agent.md`、`shared/agents/review/supporting_checker.md` |
| 高武 | `male/templates/genres/urban_fantasy.md`（+`male/templates/genres/xuanhuan.md` 取境界体系） | `male/templates/goldfinger_design.md` | `shared/agents/review/goldfinger_checker.md`、`shared/agents/review/logic_checker.md`、`shared/agents/review/conflict_checker.md` |
| 异能/系统 | `male/templates/genres/urban_fantasy.md` | `male/templates/goldfinger_design.md`、`male/templates/antagonist_design.md` | `shared/agents/review/goldfinger_checker.md`、`shared/agents/review/info_auditor.md`、`shared/agents/review/foreshadow_hunter.md` |
| 商战 | `male/templates/genres/dushi.md`、`male/templates/genres/entertainment.md`（娱乐圈商战时） | `male/templates/antagonist_design.md`、`male/templates/climax_design.md` | `shared/agents/review/logic_checker.md`、`shared/agents/review/conflict_checker.md`、`shared/agents/review/character_judge.md` |
| 娱乐圈 | `male/templates/genres/entertainment.md` | `male/templates/antagonist_face_slapping.md` | `shared/agents/review/pace_critic.md`、`shared/agents/review/plot_structure_agent.md` |
| 玄幻 | `male/templates/genres/xuanhuan.md` | `male/templates/protagonist_design.md`、`male/templates/goldfinger_design.md` | 全套 `shared/agents/review/` |
| 仙侠 | `male/templates/genres/xianxia.md` | 同上 | 同上 |
| 悬疑 | `male/templates/genres/mystery.md` | `male/templates/climax_design.md` | `shared/agents/review/logic_checker.md`、`shared/agents/review/foreshadow_hunter.md`、`shared/agents/review/info_auditor.md` |
| 穿越/重生 | `male/templates/genres/transmigration.md` | `male/templates/goldfinger_design.md` | `shared/agents/review/logic_checker.md`、`shared/agents/review/pov_checker.md` |
| 游戏 | `male/templates/genres/gaming.md` | — | `shared/agents/review/pace_critic.md`、`shared/agents/review/conflict_checker.md` |
| 科幻 | `male/templates/genres/scifi.md` | `shared/templates/writing_craft/world_craft.md`（技法） | `shared/agents/review/logic_checker.md`、`shared/agents/review/info_auditor.md` |
| 历史 | `male/templates/genres/historical.md` | `male/templates/antagonist_design.md` | `shared/agents/review/logic_checker.md`、`shared/agents/review/character_judge.md` |
| 恐怖灵异 | `male/templates/genres/horror.md`、`male/templates/genres/cosmic_horror.md`（克苏鲁向） | — | `shared/agents/review/pace_critic.md`、`shared/agents/review/pov_checker.md`；男频专项 `male/agents/review/cosmic_horror_evaluator.md` |
| 公路求生·克苏鲁向（v3.6.0） | `male/templates/genres/horror.md`、`male/templates/genres/cosmic_horror.md`（克苏鲁氛围） | rules-pack 专项规则包（按需加载，见 SKILL 铁律 13）：`system-novel-rules.md` #21 赛道模板（与 #4 末世求生、#16 诡异克苏鲁三重叠加）、`foreshadow-judgment-rules.md` 第六大类 F23-F27、`character-logic-rules.md` §1.6 公路节点节奏 + §2.6 SAN 分级行为校验 | `shared/agents/review/foreshadow_hunter.md`、`shared/agents/review/pace_critic.md`、`shared/agents/review/logic_checker.md`；男频专项 `male/agents/review/cosmic_horror_evaluator.md` |
| DND奇幻 | `male/templates/genres/dnd.md` | — | 男频专项 `male/agents/review/dnd_evaluator.md` |

### 女频映射

| 识别类型 | 题材模板（必加载） | 专项模板（按命中叠加） | 专项审稿 agent |
|---------|------------------|---------------------|---------------|
| 现代言情/恋爱 | `female/templates/genres/romance_modern.md` | `female/templates/romance_line.md`、`female/templates/protagonist_female.md`、`female/templates/dual_protagonist.md`（双主时） | `female/agents/review/romance_line_judge.md`、`female/agents/review/male_roles_judge.md`；`shared/templates/writing_craft/emotional_craft.md` |
| 古代言情 | `female/templates/genres/ancient_romance.md` | `female/templates/romance_line.md` | `female/agents/review/romance_line_judge.md`、`female/agents/review/male_roles_judge.md` |
| 耽美 BL | `female/templates/genres/boys_love.md` | `female/templates/dual_protagonist.md` | `female/agents/review/bl_relationship_judge.md`、`female/agents/review/male_roles_judge.md` |
| 百合 GL | `female/templates/genres/girls_love.md` | `female/templates/dual_protagonist.md` | `female/agents/review/gl_relationship_judge.md` |
| 女尊/女强 | `female/templates/genres/female_dominance.md` | `female/templates/protagonist_female.md`、`female/templates/female_goldfinger_design.md` | `female/agents/review/male_roles_judge.md`、`shared/agents/review/female_character_judge.md` |
| 快穿/穿书 | `female/templates/genres/quick_pass.md` | `female/templates/female_goldfinger_design.md`、`female/templates/antagonist_face_slapping_female.md` | `shared/agents/review/foreshadow_hunter.md`、`shared/agents/review/logic_checker.md`、`female/agents/review/romance_line_judge.md` |
| 悬疑恋爱 | `female/templates/genres/mystery_romance.md` | `female/templates/romance_line.md` | `female/agents/review/romance_line_judge.md`、`shared/agents/review/logic_checker.md` |
| 女频仙侠 | `female/templates/genres/female_xianxia.md` | `female/templates/female_goldfinger_design.md` | `female/agents/review/romance_line_judge.md`、`shared/agents/review/goldfinger_checker.md` |

### 跨频道规则

- 男主言情向：男频主流程 + `female/templates/romance_line.md` + `female/agents/review/romance_line_judge.md`。
- 女强升级流：女频主流程 + `male/templates/goldfinger_design.md` + `shared/agents/review/goldfinger_checker.md`。
- 任何题材都可叠加共享写作技法模板（`shared/templates/writing_craft/`）：对白问题→`dialogue_craft.md`；视角问题→`narrative_pov.md`；场景问题→`scene_craft.md`；情感问题→`emotional_craft.md`；世界观问题→`world_craft.md`；节奏/信息密度问题→`depth_balance.md`。

### 通用审稿 agent 库（13 维，所有题材可用）

`shared/agents/review/INDEX.md` 为入口：`shared/agents/review/character_judge.md`（人物）、`shared/agents/review/climax_checker.md`（高潮）、`shared/agents/review/conflict_checker.md`（冲突）、`shared/agents/review/description_quality_agent.md`（描写）、`shared/agents/review/female_character_judge.md`（女性角色）、`shared/agents/review/foreshadow_hunter.md`（伏笔）、`shared/agents/review/goldfinger_checker.md`（金手指）、`shared/agents/review/info_auditor.md`（信息投放）、`shared/agents/review/logic_checker.md`（逻辑）、`shared/agents/review/pace_critic.md`（节奏）、`shared/agents/review/plot_structure_agent.md`（结构）、`shared/agents/review/pov_checker.md`（视角）、`shared/agents/review/supporting_checker.md`（配角）。

---

## 五、模板加载纪律

1. 一次审稿加载模板 ≤ 5 个：1 个题材模板 + 命中专项 + 最多 2 个 agent；避免上下文膨胀。
2. 模板中的"创作要求"在审稿场景下**反向使用**：模板要求的必备元素缺失 = 问题；模板列出的雷区命中 = 问题。
3. 模板规则与记忆文档冲突时，按铁律仲裁：记忆文档事实 > 平台规则 > 模板方法论。
4. 模板库文件清单以磁盘 INDEX.md 为准；映射表中文件不存在时跳过并在报告中注明，不得伪造模板内容。
