# 审稿专用向量化数据库（Review Vector DB）

面向网文审稿的**文件型向量数据库**规范。零依赖、纯 Markdown/JSON 存储、随项目走、跨设备可复制。审稿时由 AI 按本规范执行"建库 → 检索 → 比对判定"，效果等价于向量库：每条记录携带语义指纹（关键词向量 + 实体槽位），检索以语义相似度 + 实体精确匹配双通道进行。

> **v3.7.0 重大精简**：砍掉大部分持久化向量存储（人物/剧情/对白/数值等向量不再持久化），改为审稿时临时从正文 + setting.md 提取，审完即弃。核心目标：减少 60%~75% 的额外 token 消耗。
>
> **v3.9.0 轻量记忆索引体系**：v3.7 的"临时提取"策略在超长篇（>100 章）下回溯正文成本过高。本次引入**结构化轻量索引**（比向量库轻一个数量级）——实体注册表（entity_index.json）+ 分层人物库（characters/）+ 倒排索引（keyword_index.json）+ 滚动摘要（story_summaries.json）。核心思路：**用"确定性结构化索引"替代"语义相似度检索"**——大多数审稿查询本质是"某人物/物品/伏笔在哪章、状态是什么"，精确查表即可命中，无需语义计算。常驻加载控制在 ~600 行以内，超长篇审稿预计再省 50-60% 的回溯 token。索引更新全部为增量追加，纳入三级更新分级（轻量级自动维护，无需用户指令）。

---

## 一、项目隔离机制（强制）

### 1.1 库存放位置（v3.7.0 精简版）

每个网文项目一个**独立库实例**，存放在被审小说项目根目录下：

```text
<小说项目根目录>/
└── .review-db/                    # 审稿数据库（项目私有，不与他项目共享）
    ├── meta.json                  # 项目元数据：书名、题材、cached_genre 路由缓存、当前章节、模块标记（极轻量）
    ├── setting.md                 # 核心设定单文件：世界观 + 主角/核心配角卡 + 力量体系（按段落分区，控制在 ~300 行内）
    ├── project_state.json         # 全专项状态合并：
    │   ├── system_state           #   系统文专项状态
    │   ├── gender_state           #   性转专项状态
    │   ├── road_state             #   公路求生专项状态
    │   └── san_value              #   全局 SAN 值进度
    ├── entity_index.json          # 【v3.9.0】实体注册表：人物/物品/势力/地点名片（一实体一行，检索入口）
    ├── characters/                # 【v3.9.0】分层人物库：重要配角独立建档（出场≥3章才建档，每人一文件）
    │   ├── C003_王胖子.md
    │   └── ...
    ├── keyword_index.json         # 【v3.9.0】倒排索引：核心关键词 → 章节列表（伏笔定位/事件回溯用）
    ├── story_summaries.json       # 【v3.9.0】滚动摘要：最近10章详情 + arc 卷级摘要 + 全局简介 + 章节标签
    ├── foreshadow/                # 伏笔专项子目录（索引+详情+归档，物理隔离）
    │   ├── index.json             #   伏笔轻量索引：FID+状态+章节，日常仅读这个
    │   ├── details/               #   单条伏笔详情，按需读写
    │   └── archived.json          #   已回收伏笔归档，日常不碰
    └── style_fingerprint.json     # 文风指纹（量化+定性，其余向量临时计算）
```

> **版本演进说明**：
> - v3.0：社交三集合（social_ledger / relations / leverage），服务 D1 人情世故审查；
> - v3.4.0：伏笔专项子目录（foreshadow/，台账 + 5 类特征向量）；
> - v3.7.0 **精简重构**：砍掉冗余向量库持久化（chapters/facts/plots/dialogues/values/hooks/social_ledger/relations/leverage 等全部改为临时计算），人物档案合并入 setting.md，专项状态合并入 project_state.json，文件数量从 10+ 压缩到 4 个核心文件；
> - v3.9.0 **轻量索引体系**：为超长篇新增 4 个结构化索引（entity_index / characters/ / keyword_index / story_summaries）——不是恢复 v3.6 的向量持久化，而是用"确定性查表"替代"临时回溯正文"，单文件均控制在几百行内，增量追加维护，常驻加载总量 ~600 行。

### 1.2 首次审稿自动初始化（v3.9.0 轻量初始化）

审稿第1步（记忆加载）时执行：

1. 在被审章节所在项目根目录查找 `.review-db/meta.json`。
2. **不存在 → 判定为新项目，执行最小化初始化**：
   - 创建 `.review-db/` 标准目录结构（meta.json / setting.md / project_state.json / entity_index.json / characters/ / keyword_index.json / story_summaries.json / foreshadow/ / style_fingerprint.json）；
   - 生成 `meta.json`：项目ID（项目目录名的 slug + 短哈希）、书名（从记忆文档/目录名推断，可向用户确认）、频道与题材（用 genre-classifier 首次识别结果，**同步写入 `cached_genre` 路由缓存**）、`db_version: 3.9`、`current_chapter: 0`、`created_at`；
   - 初始化 `setting.md`：从扫描到的记忆文档中提取世界观/人物/力量体系核心内容，按标题分区写入（**仅保留主角 + 出场排名前 5 的核心配角，其余人物迁入 entity_index 注册表**）；
   - 初始化 `entity_index.json`：从记忆文档提取全部已知人物/物品/势力/地点，生成名片行（人物详情暂不建档，等出场≥3 章再建）；
   - 初始化 `keyword_index.json` / `story_summaries.json`：空结构（keyword_map / recent_chapters / arc_summaries / global_summary）；
   - 初始化 `project_state.json`：所有专项字段为空对象，随专项触发按需填充；
   - 初始化 `foreshadow/index.json`：空数组，从记忆文档提取的伏笔按需追加；
   - 报告开头注明：`🆕 已为《书名》初始化独立审稿数据库（.review-db/），项目间数据完全隔离。`
3. **已存在 → 打开对应库**，校验 `meta.json` 的项目ID与当前项目路径一致；不一致则停止并提示用户，严禁串库。**旧版本库（无 entity_index.json 等 v3.9 文件）不强制迁移**——审稿时按需惰性创建：首次审稿回写时若发现索引文件缺失，自动补建空结构并从 setting.md / 正文增量灌入，下一次审稿即生效。

### 1.3 隔离铁律

- 审稿时**只读写当前项目 `.review-db/`**，绝不引用其他项目的库文件。
- 库文件随小说项目一起存放/备份/移动；技能本身（skill 目录）不存任何项目数据——重装或更新技能不影响项目库。
- 用户可手动删除 `.review-db/` 实现"忘记这个项目"；下次审稿自动重建。
- `.review-db/` 建议加入项目备份但不加入发布包；严禁随技能 zip 分发任何项目库。

---

## 一点五、v3.7.0 精简策略：临时向量 + 持久化最小集

### 为什么砍掉持久化向量库？

v3.6 及之前，人物/剧情/对白/数值等向量全部持久化存储，每次审稿都要读写多个 JSONL 文件，token 消耗巨大。但实际上：
- 大部分向量只用一次，后续审稿用不上；
- 设定类信息已经在 setting.md 中有完整记录，重复存储是浪费；
- 剧情/人物状态可以从正文回溯 + 当前章节提取，不需要全量持久化。

### 持久化最小集（v3.9.0：5 核心文件 + 4 索引文件）

| 文件 | 作用 | 更新频率 |
|------|------|---------|
| `meta.json` | 项目元数据（书名/题材缓存/当前章节） | 每章更新（仅改章节号） |
| `setting.md` | 世界观 + 常驻人物卡（主角+核心配角）+ 力量体系 | 默认不更新，/sync-setting 时增量修改 |
| `project_state.json` | 全专项状态（系统/性转/公路/SAN） | 默认不更新，/sync-setting 时更新触发字段 |
| `foreshadow/index.json` | 伏笔轻量索引 | 默认轻量级更新（仅改状态/追加） |
| `style_fingerprint.json` | 文风指纹 | 默认轻量级更新（EWMA 滑动） |
| `entity_index.json` 【v3.9.0】 | 实体注册表（人物/物品/势力/地点名片） | 默认轻量级更新（计数+1/追加名片） |
| `characters/*.md` 【v3.9.0】 | 建档层人物卡（重要配角） | /sync-setting 时建档/更新 |
| `keyword_index.json` 【v3.9.0】 | 倒排索引（关键词→章节） | 默认轻量级更新（追加关键词） |
| `story_summaries.json` 【v3.9.0】 | 滚动摘要（最近10章+arc+全局） | 默认轻量级更新（追加摘要） |

### 临时计算向量（审完即弃）

以下向量在审稿时**临时从正文 + setting.md 提取**，不写入磁盘：
- 剧情事件链（plots）：从本章正文提取事件节点，用于因果链检查；
- 人物行为向量：从本章正文提取关键行为/台词，用于 OOC 比对；
- 对白指纹（dialogues）：从本章正文提取对白，用于口语化检测；
- 数值流水（values）：从本章正文提取数值变动，用于穿帮检查；
- 人情/关系/筹码（social_ledger/relations/leverage）：从本章正文提取社交事件，用于人情世故审查；
- 事实冲突（facts）：从 setting.md + 本章正文提取已确认事实，用于一致性校验。

**检索算法不变**（双通道相似度），只是数据源从"持久化向量库"变为"临时提取的本章 + 设定上下文"。

---

## 一点八、v3.9.0 轻量记忆索引体系：确定性查表替代语义检索

### 设计原理

v3.7 的"临时提取"在超长篇下有致命弱点：查"某物品上次出现在哪章""某配角上次干了什么"需要回溯正文，章数越多 token 越贵。向量化可以解决但成本高（建库费 + 检索费 + 语义漂移风险）。

**审稿查询的本质分析**：90% 的一致性核查查询是确定性查询——"张三的金手指是什么""混沌珠第几章出现""王胖子上次出场状态"。这类查询用**结构化索引精确命中**即可，命中率 100%，检索成本≈0，且人可直接阅读维护。仅剩 10% 的模糊语义查询（"类似打脸的场景在哪"）才需要回溯正文，可接受。

### 1.8.1 entity_index.json — 实体注册表（检索总入口）

一实体一行"名片"，不存完整档案：

```json
{
  "characters": [
    {"id": "C001", "name": "张三", "alias": ["三爷"], "role": "主角",
     "first_ch": 1, "last_ch": 87, "appear_count": 82,
     "core_tags": ["重生者", "混沌珠持有者"],
     "key_facts": ["重生回到大学", "与李家有血仇"],
     "status": "active", "detail": "setting.md"}
  ],
  "items": [
    {"id": "I001", "name": "混沌珠", "type": "金手指",
     "first_ch": 3, "last_ch": 45, "owner": "张三",
     "key_facts": ["空间储物", "时间流速10:1"], "status": "active"}
  ],
  "factions": [
    {"id": "F001", "name": "李家", "type": "势力",
     "first_ch": 1, "last_ch": 89, "key_facts": ["反派势力", "与主角血仇"], "status": "active"}
  ],
  "locations": [
    {"id": "L001", "name": "临江大学", "type": "地点",
     "first_ch": 1, "last_ch": 30, "key_facts": ["主角母校"], "status": "archived"}
  ]
}
```

**字段规范**：
- `key_facts`：最多 5 条，每条 ≤20 字，只存高频核查事实；
- `status`：`active`（活跃）/ `archived`（长期不出场，可降级只留名片）；
- `detail`：`"setting.md"`（核心人物，常驻设定文件）或 `"characters/Cxxx.md"`（重要配角，按需读）或 `"none"`（边缘角色，临时提取）。

**每章审后维护（轻量级自动）**：本章出场实体仅更新 `last_ch` 和 `appear_count` +1；新实体追加一行；`key_facts` 只在 /sync-setting 时更新。

### 1.8.2 characters/ — 分层人物库（人物卡三级金字塔）

```
第一层 · 常驻层（setting.md 内）：
  主角 + 核心配角（appear_count 前 5 或 role 标记核心）
  → 每次审稿必加载，含五维/灵魂铁则/语言指纹/情绪反应库完整档案

第二层 · 建档层（characters/Cxxx_名字.md）：
  重要配角（appear_count ≥ 3 且未进第一层）
  → 仅当该人物在本章出场时按需读取；格式同常驻层档案

第三层 · 名片层（仅 entity_index.json 一行）：
  边缘角色（appear_count < 3）
  → 只存名片行（名字/身份/1-2个标签），审稿时从本章正文临时提取补充
```

**晋升/降级规则**：边缘角色出场满 3 章 → 提示建档（轻量级仅提示，/sync-setting 时正式建档）；核心配角超过 30 章未出场 → 降级到建档层（/sync-outline 时执行）。人物卡格式沿用本文件 §3.2 五维档案模板。

### 1.8.3 keyword_index.json — 倒排索引（伏笔定位 / 事件回溯）

```json
{
  "混沌珠": [3, 7, 12, 45, 67],
  "李家": [1, 5, 12, 23, 45, 67, 89, 112],
  "拍卖会": [23, 45, 78],
  "背叛": [1, 56, 89],
  "_meta": {"total_keywords": 214, "last_updated_ch": 112}
}
```

**收录规则**：每章审后提取 8-12 个核心关键词——具名实体（人物/物品/势力/地点，与 entity_index 同源）+ 关键事件词（打脸/突破/背叛/拍卖会等剧情节点词）。**不收录**：通用词（说/看/走）、情绪词、单次出现的场景词。

**体积控制**：单关键词章节列表只保留最近 30 个章节号；总关键词 > 500 时，清除只出现 1 次的条目。

**用法**：伏笔回收核对（"混沌珠"出现在 3/7/12/45 章 → 直接读第 45 章摘要核对回收细节）；事件冲突检查（"背叛"在 1/56/89 章 → 检查三次背叛是否指向同一事件或有无矛盾）；跨章对比审的章节定位。

### 1.8.4 story_summaries.json — 滚动摘要（剧情记忆固定上限）

```json
{
  "recent_chapters": [
    {"ch": 105, "events": ["张三识破李家二房内应", "王胖子正式入股"],
     "chars": ["张三", "王胖子", "李慕白"], "tags": ["商战", "转折"],
     "hooks_out": ["F023"]}
  ],
  "arc_summaries": [
    {"arc": 1, "range": "1-20",
     "summary": "张三重生回到大学，获混沌珠，积累第一桶金，与李家结仇（15句内）",
     "key_events": ["重生", "获宝", "结仇李家"],
     "chars_introduced": ["张三", "王胖子", "李霸天"]}
  ],
  "global_summary": "重生者张三凭混沌珠在都市商战中崛起对抗李家（≤50字）"
}
```

**滚动策略（自动，零用户指令）**：
- `recent_chapters` 每章审后追加（3-5 句 events + 标签），**只保留最近 10 章**；
- 第 11 章进入时，最老的一条自动并入对应 `arc_summaries`（每 20 章一个 arc，合并为 ≤15 句摘要）——轻量级模式下做**粗合并**（拼接关键事件句，压缩到 15 句内），/sync-outline 时做**精合并**（重写润色）；
- `global_summary` 在 /sync-outline 时重写。

**效果**：不管书写到多少章，剧情记忆总量恒定在 ~150-250 行（10 条详细 + N 条 arc + 1 句全局）。

### 1.8.5 分层加载策略（审稿时读什么）

| 数据 | 加载时机 | 体积预估 |
|------|---------|---------|
| meta.json + entity_index.json + foreshadow/index.json | **每次必读**（常驻索引层） | ~150 行 |
| setting.md 核心段落（世界观涉及部分 + 本章出场常驻人物卡） | 每次按段落读 | ~100-150 行 |
| story_summaries.json（recent_chapters + 当前 arc） | 每次必读（承接上文） | ~50-80 行 |
| characters/Cxxx.md（本章出场的建档配角） | 出场才读，每人 ~40 行 | 0-120 行 |
| keyword_index.json | 仅伏笔/冲突核查时查（可按关键词段查询） | 按需 |
| story_summaries.arc_summaries（历史卷） | 剧情复盘/跨卷核对才读 | 按需 |
| foreshadow/details/Fxxx.json | 具体伏笔核对才读 | 按需 |

**常驻总量 ≈ 300-500 行**（对比 v3.7 超长篇回溯正文的数千行，节省 60%+）。

### 1.8.6 与三级更新分级的整合

| 更新等级 | 索引维护动作 | 额外成本 |
|---------|-------------|---------|
| **轻量级（默认）** | ① entity_index：出场实体 +1/追加名片行；② keyword_index：追加 8-12 个关键词；③ story_summaries：追加本章摘要（3-5 句）+ 溢出章粗合并进 arc | ~100-150 token，纯追加 |
| **标准级（/sync-setting）** | + 人物卡建档/更新（出场满 3 章的配角）；+ key_facts 增量更新；+ setting.md 段落更新 | 中 |
| **全量级（/sync-outline）** | + arc 摘要精合并重写；+ global_summary 重写；+ entity_index 全量校验（死实体归档）；+ 晋升/降级执行 | 较高 |

**铁律**：索引维护全部为**增量追加/单条修改**，禁止全量重写索引文件；索引数据人可直读，用户可手动修正。

---

## 二、向量记录结构

每条 JSONL 记录的通用字段：

```json
{
  "id": "ch-006",                    // 记录ID，类型前缀+序号
  "type": "chapter",                 // chapter/fact/character/event/dialogue/value/hook/audit
  "chapter": 6,                      // 所属章节号（全局事实用 0）
  "source": "chapter-text",          // chapter-text / memory-doc / audit
  "text": "原文摘录（≤120字）",       // 语义锚点文本
  "vec": ["关键词", "关键词", ...],   // 语义向量：8-15个实词/短语关键词（去停用词）
  "slots": { "实体槽位": "值" },      // 精确匹配通道：人名/地点/数值/时间等
  "embed_ref": "chapters#ch-006",    // 去重引用
  "updated_at": "2026-08-31",
  "note": "检索用备注"
}
```

### 检索算法（双通道相似度）

审稿时对待判定内容生成查询指纹（`q_vec` 关键词 + `q_slots` 实体），在对应集合中检索：

1. **语义通道**：`q_vec` 与记录 `vec` 的关键词重合度得分 = 2×(交集词数) / (两向量词数之和)。
2. **实体通道**：`slots` 中同名实体（人名/物品名/数值名/地点）精确命中加权 +0.3；数值类槽位相等 +0.5、不等 -0.5。
3. 综合分 ≥ 0.45 视为相关命中，按分数降序取 top-5 作为比对依据。
4. 无命中 = 数据库中无相关记载 → 该信息首次出现，进入"新增候选"，审后提示回写，**不得当作矛盾判 BUG**。

---

## 三、三大核心审稿功能

### 3.1 剧情逻辑一致性检查（临时提取事件链 + 已确认事实）

**临时提取**：审稿时把本章剧情压成 1-N 个事件节点（会话内使用，不落盘）：
`{id, chapter, type:"event", text:"谁对谁做了什么/结果如何", vec:[...], slots:{who, where, cause, result, time}, prev:["上一事件id"]}`

已确认事实从 `setting.md` 与记忆文档提取：世界观规则、人物关系定局、不可打破设定（来源 `memory-doc` 权重最高）；跨章事件链查 `story_summaries.json` 摘要 / `keyword_index.json` 章节定位，不回溯正文全章。

**审稿判定**：
- **因果链检查**：本章事件的 `cause` 必须能在前情摘要（story_summaries/keyword_index 定位的前置章）或已确认事实中找到依据；找不到 → 🔴 因果断裂（上帝之手）。
- **事实冲突检查**：本章陈述与已确认事实（setting.md/记忆文档）语义命中且实体相同、结论相反 → 🔴 事实矛盾。引用格式：`setting.md/记忆文档（出自第X章）记录为A，正文第Y段写为B`。
- **状态承接检查**：相邻章事件的 result → 下一章开局状态应承接；矛盾（上章重伤下章活蹦乱跳无交代）→ 🟡 承接断裂。
- **时间线检查**：slots.time 串联成故事内时钟，章际/章内时序矛盾 → 🔴。

### 3.2 人物设定 OOC 偏离检测（分层人物库 + 临时提取对白指纹）

**人物档案**（setting.md 主角/核心配角卡 + characters/ 建档层，见 §1.8.2；名片层人物临时提取）每人一个 `.md`：

```markdown
# <人物名>
- 五维：性格核心 / 价值观 / 能力边界 / 社交段位 / 知识边界
- 灵魂铁则：[绝不做的事，如"不主动表白""不对弱者动手"]
- 语言指纹：句长偏好 / 口癖 / 用词雅俗 / 称呼习惯 / 标点习惯
- 情绪反应库：{ 害羞: [反应A,反应B...], 愤怒: [...], 紧张: [...] }（每个反应标注首次出现章节）
- 关系槽位：{ 对方人物: 关系状态, 变化章节 }
- 成长弧：已发生的性格演变（章节 + 触发事件 + 演变方向）
```

**OOC 判定流程**：
1. 本章该人物的每个关键行为/台词，与档案逐项比对：
   - 违反"灵魂铁则"且无剧情铺垫 → 🔴 OOC。
   - 语言指纹漂移（句长/口癖/用词突变）→ 取本章及 story_summaries 近 5 章中该人物台词的临时指纹比对，漂移分 > 0.5 → 🟡 台词不像此人。
   - 情绪反应克隆：本章反应与"情绪反应库"比对，同一情绪连续 ≥3 次使用同一反应 → 🟡 反应克隆（库自动轮换提醒可用反应）。
2. **成长弧豁免**：档案"成长弧"中已记录的演变方向上的变化不算 OOC；本章出现可能构成新成长的行为，标记为"成长候选"，审后请用户确认是否回写。
3. 配角行为对照 `supporting` 类事实：路人不该知道的信息（知识边界越界）→ 🟡。

### 3.3 对白台词口语化验证（临时提取对白指纹，v3.7.0 起不落盘）

**临时提取**：每章抽取每条对白（≥10 字的）为一条比对记录：
`{id, type:"dialogue", chapter, text, vec:[...], slots:{speaker, listener, scene}, stats:{avg_len, 口语标记数, 书面标记数, 动作锚定:bool, tier:1-4, move_type, anchor_count, subtext:bool}}`
（v3.0 扩展 stats：`tier` 话题阶位 1事实/2立场/3底线/4利益；`move_type` 攻防动作=攻击/防守/转折/试探/出价/还价/威胁/让步/成交/寒暄；博弈判定规则见 [rules-pack/dialogue-game-rules.md](rules-pack/dialogue-game-rules.md)）

**口语化指纹库**：`stats` 按说话人累计均值，形成该人物的"对白基线"。

**审稿判定**：
- **书面腔检测**：单条对白命中书面标记（长定语串联、"因此/然而/不仅…而且"、四字词连用 ≥2、完整复句无断裂）且口语标记（短句、语气词、省略、倒装、插话）为 0 → 🟡 台词像念稿。
- **千人一面检测**：同一场景两个说话人的台词指纹（vec + stats）相似度 > 0.7 → 🟡 对话 DNA 缺失（去掉名字分不清谁在说话）。
- **动作锚定**：连续 ≥4 个对白轮次无任何动作/表情/环境锚定 → 🔴/🟡 飘对话（规则包 F1）。
- **功能化检测**：对白 vec 与本章事件链指纹高度重合（台词纯在复述剧情/设定）→ 🟡 信息倾倒/科普嘴。
- **口语基线偏离**：某人物本条对白 stats 与其历史基线偏离 > 0.5（如平时句长 8 字突然 25 字长句）→ 标记，结合语境判定是 OOC 还是特殊情境（演讲/吵架可豁免，需场景支持）。
- **轮次空转**（v3.0）：同场景连续 >2 轮 move_type 为寒暄/重复且无新 slots 实体 → 🟡 原地拉扯。
- **阶梯停滞**（v3.0）：tier 同一阶停留 >2 轮且无新筹码/新信息事件 → 🟡。
- **局势零变化**（v3.0）：对话场景结束时事件链无对应 event、关系槽位无更新 → 🟡 无效对话。
- **单方碾压**（v3.0）：对峙/辩论场景弱势方 move_type 中有效反击/转移计数 <1 → 🟡。
- **直白情绪词**（v3.0）：正则命中 `(生气|开心|愤怒|冷笑|高兴)地?[说道吼骂]` → 🟡。
- **长台词独白**（v3.0）：单条 >50 字且其后 1 轮内无对方反应 → 🟡。

---

## 四、数值与社交临时核对（v3.7.0 起不落盘，唯一持久化的状态机为伏笔索引）

- **数值流水（临时提取）**：审稿时从本章正文提取数值类信息 `{chapter, slots:{name:"好感值/点数/等级/金额", owner, value, delta, reason}}`，与 `entity_index.json` key_facts、setting.md 数值段核对：delta 累计 ≠ 新 value → 🔴 数值穿帮；播报格式（如"【叮！】"风格）前后不一 → 🟢。
- **伏笔状态机（持久化）**：由 `foreshadow/index.json` + `details/` 唯一承载（见 §六），轻量级模式仅推进 index.json 对应 FID 状态字段；超过 `chapter_due` 仍 planted/reinforced → 🟡 伏笔超期；closed 伏笔与埋设内容矛盾 → 🔴；正文回收了但索引无埋设记录 → 提示补登记。
- **人情账（临时提取）**：从本章正文提取社交事件 `{chapter, slots:{creditor, debtor, content, level:"轻微/一般/重大/救命", repaid:false, repaid_chapter}}`。审稿核对：人情轻重与事件重量不匹配（救命级换小忙）→ 🔴 人情失重；单向受惠无回请且无 repaid 迹象 → 🟡 关系失衡；无缘无故的善意/恶意（人情账与事件链均无成因）→ 🟡。
- **二人关系（临时提取）**：`{chapter, slots:{pair:"A-B", status, affinity:0-100, suspicion:0-100, summary}}`；好感度双轴校验 CP 行为（按低的一方算，好感不足写亲密 → 🔴/🟡）；猜忌度骤降无事件支撑 → 🟡。
- **把柄筹码（临时提取）**：`{chapter, slots:{holder, target, content, kind:"把柄/筹码", revealed:false}}`。谈判/背刺场景审查：翻脸前无 leverage 埋设记录且无试探情节 → 🔴 突然翻脸；谈判筹码无来源 → 🟡。

**社交数值建议幅度**（/sync-setting 回写 setting.md 时参考）：重大人情 affinity +15~25、一般 +5~10；猜忌事件 suspicion +10~20；撕破脸 affinity 归零并标记 status。

---

## 五、审稿时的库操作时序（v3.9.0 轻量模式）

```text
第1步 记忆加载 → 打开/初始化 .review-db → 读取 meta.json（<100token，含 cached_genre 题材缓存）
                                   → 读取常驻索引层：entity_index.json + foreshadow/index.json（~150行）
                                   → 按段落加载 setting.md（世界观涉及部分 + 本章出场常驻人物卡）
                                   → 读取 story_summaries.json 的 recent_chapters + 当前 arc（承接上文）
                                   → 触发专项时才读 project_state.json 对应字段 + style_fingerprint.json
第2步 题材路由 → meta.json 有 cached_genre 且置信度≥80% → 校验 5-8 个强信号 → 通过则直接按缓存加载模板
                → 无缓存/校验失败 → 走 genre-classifier 完整识别（结果写入 meta.json.cached_genre）
第4步 执行审查 → 本章出场人物：常驻层用 setting.md 档案；建档层按需读 characters/Cxxx.md；名片层临时提取
                → 跨章核查：keyword_index.json 定位章节 → story_summaries 对应摘要核对，禁止直接回溯正文
                → 专项比对：临时提取查询指纹 → 双通道比对 → 出判定
第5步 审后回写 → 【默认轻量级】：
                      1. 更新 meta.json 当前章节号
                      2. 增量更新 foreshadow/index.json（状态推进/新增条目）
                      3. EWMA 更新 style_fingerprint.json
                      4. 索引维护（v3.9.0）：entity_index 出场实体计数/新名片 + keyword_index 追加关键词
                         + story_summaries 追加本章摘要（溢出章粗合并进 arc）
                      不碰：setting.md / project_state.json / characters/ 建档 / 章纲 / 卷纲
                  【/sync-setting 标准级】：
                      + 增量修改 setting.md 对应段落
                      + 更新 project_state.json 对应专项字段
                      + 人物卡建档（出场满3章的配角创建 characters/Cxxx.md）
                      + entity_index key_facts 增量更新
                  【/sync-outline 全量级】：
                      + 同步更新章纲 + 联动修正卷纲
                      + arc 摘要精合并重写 + global_summary 重写
                      + entity_index 全量校验（死实体归档）+ 人物晋升/降级执行
                      + 全量校验一致性
```

**回写纪律（v3.7.0 增量写入铁律 + v3.9.0 索引扩展）**：
1. 所有更新仅修改命中的对应段落/条目，**禁止全量重写文件**；
2. setting.md 按标题定位，仅替换涉及的人物/世界观段落；
3. 伏笔索引仅追加/修改对应 FID 条目，不重写全表；
4. project_state.json 仅更新触发的专项字段，其余字段保留；
5. entity_index 仅修改出场实体的计数字段/追加新名片行，key_facts 仅标准级更新；
6. keyword_index 仅追加本章关键词到既有条目，不重建索引；
7. story_summaries 仅追加本章摘要 + 溢出章合并，arc 精合并仅全量级执行；
8. 已归档数据默认不触碰，仅手动指令触发归档操作；
9. 库文件全部为明文，用户可随时人工查阅纠错。

---

## 六、伏笔专项存储与同步规范（v3.4.0 新增 / v3.7.0 精简）

伏笔追踪专项（判定标准 [rules-pack/foreshadow-judgment-rules.md](rules-pack/foreshadow-judgment-rules.md)、冲突校验 [rules-pack/foreshadow-conflict-rules.md](rules-pack/foreshadow-conflict-rules.md)、分题材模板 [rules-pack/foreshadow-topic-templates.md](rules-pack/foreshadow-topic-templates.md)）在库内的存储与同步规范。

### 6.1 foreshadow/ 子目录结构（v3.7.0 精简版）

```
foreshadow/
├── index.json     # 伏笔轻量索引：FID+状态+章节，日常仅读这个（快速加载）
├── details/       # 单条伏笔详情（每条一个 JSON 文件），按需读取
│   ├── F001.json
│   ├── F002.json
│   └── ...
└── archived.json  # 已回收伏笔归档，日常不加载
```

- **`index.json`** — 轻量索引数组，每条含：`{fid, category, status, chapter_buried, chapter_due, priority, summary}`。日常审稿仅加载此文件，快速获取全局伏笔状态，token 消耗极低。
- **`details/`** — 单条伏笔详情，每条一个 JSON 文件，包含完整信息：大类·小类（六大类 27 小类，F1-F27，含公路场景专属 F23-F27）/ 内容摘要 / 埋设章 / 强化章 / 计划回收章 / 状态 / 优先级 / 原文锚点 / 预警冲突记录等。仅在需要核对具体伏笔时才读取对应文件，禁止批量加载。
- **`archived.json`** — 已完全回收（closed）的伏笔归档数组，日常不加载。由 `/force-archive` 指令手动触发归档，减少 index.json 体积。

> **v3.7.0 精简说明**：原 `foreshadow_table.md`（Markdown 台账）和 `vectors/`（伏笔特征向量）不再持久化。台账功能由 index.json + details/ 替代（索引+详情分离，更省 token）；特征向量改为审稿时临时从正文提取，审完即弃。

### 6.2 状态机与回写纪律

伏笔状态机（六大状态）：`planted（已埋）` / `reinforced（强化）` / `half-closed（半回收）` / `closed（已回收）` / `overdue（超期）` / `broken（冲突断裂）`。

**回写纪律（v3.7.0 增量铁律）**：
1. 每章审后伏笔状态推进，**仅修改 index.json 中对应 FID 的状态字段**，不重写整个索引；
2. 新增伏笔时，**仅追加一条新条目到 index.json**，同时在 details/ 中创建对应详情文件；
3. 归档时，**仅将对应条目从 index.json 移至 archived.json**，不改动其他条目；
4. 详情文件（details/Fxxx.json）仅在用户查看具体伏笔或 /sync-setting 时才更新，默认轻量模式不触碰。

### 6.3 跨章节继承与隔离

- 每章审稿第1步自动读取 `foreshadow/index.json` 轻量索引作为增量校验底座（不存在则本章审后首次建档）；
- 索引随项目 `.review-db/` 存放 / 备份 / 移动，不随技能分发，与 1.3 隔离铁律一致；
- 伏笔专项数据独立于 setting.md 和 project_state.json，物理隔离不污染；
- 需要查看具体伏笔详情时，才按需读取 `details/Fxxx.json`，不批量加载全量详情。
