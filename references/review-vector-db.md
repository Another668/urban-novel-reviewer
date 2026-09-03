# 审稿专用向量化数据库（Review Vector DB）

面向网文审稿的**文件型向量数据库**规范。零依赖、纯 Markdown/JSONL 存储、随项目走、跨设备可复制。审稿时由 AI 按本规范执行"建库 → 写入 → 相似度检索 → 比对判定"，效果等价于向量库：每条记录携带语义指纹（关键词向量 + 实体槽位），检索以语义相似度 + 实体精确匹配双通道进行。

---

## 一、项目隔离机制（强制）

### 1.1 库存放位置

每个网文项目一个**独立库实例**，存放在被审小说项目根目录下：

```text
<小说项目根目录>/
└── .review-db/                    # 审稿向量库（项目私有，不与他项目共享）
    ├── project.json               # 项目档案：项目ID、书名、频道、题材、创建时间、库版本
    ├── chapters.jsonl             # 章节向量记录（一章一条）
    ├── facts.jsonl                # 已确认事实/设定向量（不可打破项）
    ├── characters/
    │   ├── _index.md              # 人物名册（名字↔档案文件）
    │   ├── <人物slug>.md          # 人物档案：五维/铁则/语言指纹/情绪反应库/知识边界
    │   └── ...
    ├── plots.jsonl                # 剧情事件链向量（因果节点）
    ├── dialogues.jsonl            # 对白指纹向量（台词风格/口语化样本）
    ├── values.jsonl               # 数值状态流水（点数/等级/好感/货币）
    ├── hooks.jsonl                # 伏笔账（埋设/回收状态机）
    ├── social_ledger.jsonl        # 【v3.0】人情账本（谁欠谁人情/等级/偿还状态）
    ├── relations.jsonl            # 【v3.0】关系追踪（二人关系状态/好感度/猜忌度）
    ├── leverage.jsonl             # 【v3.0】把柄与筹码（持有者/对象/内容/是否曝光）
    ├── foreshadow/                # 【v3.4.0】伏笔专项子目录（台账+5类特征向量，物理隔离）
    │   ├── foreshadow_table.md    #   标准化伏笔台账（Markdown 表格，可直接存档）
    │   └── vectors/               #   5 类伏笔特征向量子集（实体/人物/力量体系/剧情长线/隐性弱埋线）
    └── audit-log.jsonl            # 历次审稿记录（审了哪章、发现什么、库如何更新）
```

> v3.0 新增社交三集合（social_ledger / relations / leverage），服务 D1 人情世故审查与 C2 人物利益校准；人物档案 `<人物slug>.md` 建议追加三块字段（模板见 `references/templates/shared/templates/social_persona_card.md`）：分层沟通规则（对上级/平级/下级/对手/恩人）、利益判断逻辑（底线/可交易项/卖人情场景/记仇事项）、情绪伪装模式表（真实情绪×外在表现×标志微动作）。v3.4.0 新增伏笔专项子目录（foreshadow/，台账 + 5 类特征向量），服务伏笔追踪专项（规范见 §六）。

### 1.2 首次审稿自动初始化

审稿第1步（记忆加载）时执行：

1. 在被审章节所在项目根目录查找 `.review-db/project.json`。
2. **不存在 → 判定为新项目，自动初始化**：
   - 创建 `.review-db/` 全部目录与空文件；
   - 生成 `project.json`：项目ID（项目目录名的 slug + 短哈希）、书名（从记忆文档/目录名推断，可向用户确认）、频道与题材（用 genre-classifier 首次识别结果）、`db_version: 2.0`、`created_at`；
   - 扫描项目内记忆文档（按 memory-index.md 的识别规则），把其中的人物、事实、数值、伏笔**首次灌库**（来源标注 `source: memory-doc`）；
   - 报告开头注明：`🆕 已为新项目《书名》初始化独立审稿数据库（.review-db/），项目间数据完全隔离。`
3. **已存在 → 打开对应库**，校验 `project.json` 的项目ID与当前项目路径一致；不一致（如复制了别的项目的库）则停止并提示用户，严禁串库。

### 1.3 隔离铁律

- 审稿时**只读写当前项目 `.review-db/`**，绝不引用其他项目的库文件。
- 库文件随小说项目一起存放/备份/移动；技能本身（skill 目录）不存任何项目数据——重装或更新技能不影响项目库。
- 用户可手动删除 `.review-db/` 实现"忘记这个项目"；下次审稿自动重建。
- `.review-db/` 建议加入项目备份但不加入发布包；严禁随技能 zip 分发任何项目库。

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

### 3.1 剧情逻辑一致性检查（plots.jsonl + facts.jsonl）

**写入**：每章审后，把本章剧情压成 1-N 个事件节点：
`{id, chapter, type:"event", text:"谁对谁做了什么/结果如何", vec:[...], slots:{who, where, cause, result, time}, prev:["上一事件id"]}`

`facts.jsonl` 存"已确认事实"：世界观规则、人物关系定局、不可打破设定（来源 `memory-doc` 权重最高）。

**审稿判定**：
- **因果链检查**：本章事件的 `cause` 必须能在 plots 中找到前置事件或在 facts 中找到依据；找不到 → 🔴 因果断裂（上帝之手）。
- **事实冲突检查**：本章陈述与 facts 语义通道命中且实体相同、结论相反 → 🔴 事实矛盾。引用格式：`事实库 fact-xx（出自第X章/记忆文档）记录为A，正文第Y段写为B`。
- **状态承接检查**：相邻章事件的 result → 下一章开局状态应承接；矛盾（上章重伤下章活蹦乱跳无交代）→ 🟡 承接断裂。
- **时间线检查**：slots.time 串联成故事内时钟，章际/章内时序矛盾 → 🔴。

### 3.2 人物设定 OOC 偏离检测（characters/ + dialogues.jsonl）

**人物档案**（首次灌库来自记忆文档，之后随审随补）每人一个 `.md`：

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
   - 语言指纹漂移（句长/口癖/用词突变）→ 取 dialogues.jsonl 中该人物近 5 条台词指纹比对，漂移分 > 0.5 → 🟡 台词不像此人。
   - 情绪反应克隆：本章反应与"情绪反应库"比对，同一情绪连续 ≥3 次使用同一反应 → 🟡 反应克隆（库自动轮换提醒可用反应）。
2. **成长弧豁免**：档案"成长弧"中已记录的演变方向上的变化不算 OOC；本章出现可能构成新成长的行为，标记为"成长候选"，审后请用户确认是否回写。
3. 配角行为对照 `supporting` 类事实：路人不该知道的信息（知识边界越界）→ 🟡。

### 3.3 对白台词口语化验证（dialogues.jsonl）

**写入**：每章抽取每条对白（≥10 字的）为一条记录：
`{id, type:"dialogue", chapter, text, vec:[...], slots:{speaker, listener, scene}, stats:{avg_len, 口语标记数, 书面标记数, 动作锚定:bool, tier:1-4, move_type, anchor_count, subtext:bool}}`
（v3.0 扩展 stats：`tier` 话题阶位 1事实/2立场/3底线/4利益；`move_type` 攻防动作=攻击/防守/转折/试探/出价/还价/威胁/让步/成交/寒暄；博弈判定规则见 [rules-pack/dialogue-game-rules.md](rules-pack/dialogue-game-rules.md)）

**口语化指纹库**：`stats` 按说话人累计均值，形成该人物的"对白基线"。

**审稿判定**：
- **书面腔检测**：单条对白命中书面标记（长定语串联、"因此/然而/不仅…而且"、四字词连用 ≥2、完整复句无断裂）且口语标记（短句、语气词、省略、倒装、插话）为 0 → 🟡 台词像念稿。
- **千人一面检测**：同一场景两个说话人的台词指纹（vec + stats）相似度 > 0.7 → 🟡 对话 DNA 缺失（去掉名字分不清谁在说话）。
- **动作锚定**：连续 ≥4 个对白轮次无任何动作/表情/环境锚定 → 🔴/🟡 飘对话（规则包 F1）。
- **功能化检测**：对白 vec 与 plots 事件 vec 高度重合（台词纯在复述剧情/设定）→ 🟡 信息倾倒/科普嘴。
- **口语基线偏离**：某人物本条对白 stats 与其历史基线偏离 > 0.5（如平时句长 8 字突然 25 字长句）→ 标记，结合语境判定是 OOC 还是特殊情境（演讲/吵架可豁免，需场景支持）。
- **轮次空转**（v3.0）：同场景连续 >2 轮 move_type 为寒暄/重复且无新 slots 实体 → 🟡 原地拉扯。
- **阶梯停滞**（v3.0）：tier 同一阶停留 >2 轮且无新筹码/新信息事件 → 🟡。
- **局势零变化**（v3.0）：对话场景结束时 plots 无对应 event、relations 槽位无更新 → 🟡 无效对话。
- **单方碾压**（v3.0）：对峙/辩论场景弱势方 move_type 中有效反击/转移计数 <1 → 🟡。
- **直白情绪词**（v3.0）：正则命中 `(生气|开心|愤怒|冷笑|高兴)地?[说道吼骂]` → 🟡。
- **长台词独白**（v3.0）：单条 >50 字且其后 1 轮内无对方反应 → 🟡。

---

## 四、数值与伏笔流水

- **values.jsonl**：每个数值类信息一条 `{type:"value", chapter, slots:{name:"好感值/点数/等级/金额", owner, value, delta, reason}}`。审稿时按 name+owner 排序成时间线：delta 累计 ≠ 新 value → 🔴 数值穿帮；播报格式（如"【叮！】"风格）前后不一 → 🟢。
- **hooks.jsonl**：伏笔状态机 `{id, type:"hook", chapter_buried, chapter_due, status:"open/half/closed", text, vec, slots:{chekhov:"物品/预言/人物"}}`。超过 `chapter_due` 仍 open → 🟡 伏笔超期；closed 伏笔与埋设内容矛盾 → 🔴；正文回收了但库中无埋设记录 → 提示补登记。**v3.4.0 起与 `.review-db/foreshadow/foreshadow_table.md` 标准化台账同源同步**（映射规范见 §六），一次回写两处，严禁账实分离。
- **social_ledger.jsonl**（v3.0）：人情账 `{type:"favor", chapter, slots:{creditor, debtor, content, level:"轻微/一般/重大/救命", repaid:false, repaid_chapter}}`。审稿核对：人情轻重与事件重量不匹配（救命级换小忙）→ 🔴 人情失重；单向受惠无回请且无 repaid 记录 → 🟡 关系失衡；无缘无故的善意/恶意（ ledger 与 plots 均无成因）→ 🟡。
- **relations.jsonl**（v3.0）：二人关系 `{type:"relation", chapter, slots:{pair:"A-B", status, affinity:0-100, suspicion:0-100, summary}}`。每章按回写规则更新；好感度双轴校验 CP 行为（按低的一方算，好感不足写亲密 → 🔴/🟡）；猜忌度骤降无事件支撑 → 🟡。
- **leverage.jsonl**（v3.0）：把柄筹码 `{type:"leverage", chapter, slots:{holder, target, content, kind:"把柄/筹码", revealed:false}}`。谈判/背刺场景审查：翻脸前无 leverage 埋设记录且无试探情节 → 🔴 突然翻脸；谈判筹码无来源 → 🟡。

**社交数值建议幅度**（回写参考）：重大人情 affinity +15~25、一般 +5~10；猜忌事件 suspicion +10~20；撕破脸 affinity 归零并标记 status。

---

## 五、审稿时的库操作时序

```text
第1步 记忆加载 → 打开/初始化 .review-db → 加载 project.json + 人物档案 + facts + 未闭合 hooks
第2步 题材识别 → 结果写入 project.json（题材字段滚动更新）
第4步 执行审查 → 每个疑点：生成查询指纹 → 检索对应集合 → 双通道命中比对 → 出判定
第5步 审后回写 → 追加 chapters/events/dialogues/values 记录；
                  hooks 状态推进；新人物建档；成长候选/新事实请用户确认后写入；
                  audit-log.jsonl 追加本次审稿摘要
```

**回写纪律**：事实类（facts/人物铁则/数值）只追加与确认后修改，不覆盖历史；冲突保留两条记录并标注 `superseded_by`，可追溯。库文件全部为明文，用户可随时人工查阅纠错。

---

## 六、伏笔专项台账与特征向量（v3.4.0 新增）

伏笔追踪专项（判定标准 [rules-pack/foreshadow-judgment-rules.md](rules-pack/foreshadow-judgment-rules.md)、冲突校验 [rules-pack/foreshadow-conflict-rules.md](rules-pack/foreshadow-conflict-rules.md)、分题材模板 [rules-pack/foreshadow-topic-templates.md](rules-pack/foreshadow-topic-templates.md)）在库内的存储与同步规范：

### 6.1 foreshadow/ 子目录结构

- `foreshadow/foreshadow_table.md` — **标准化伏笔台账**（Markdown 表格，可直接存档）：每行一条伏笔，字段为 编号 / 大类·小类（五大类 22 小类，F1-F22）/ 内容摘要 / 埋设章 / 强化章 / 计划回收章 / 状态（planted/reinforced/half-closed/closed/overdue/broken）/ 优先级（高/中/低）/ 原文锚点（强制）/ 预警冲突记录；
- `foreshadow/vectors/` — **伏笔特征向量子集**（5 类，与原 plots/facts 检索双通道同构）：实体类伏笔特征向量（F1-F6）/ 人物类（F7-F11）/ 力量体系类（F12-F15）/ 剧情长线类（F16-F19）/ 隐性弱埋线（F20-F22）；检索顺序：先跑通用特征 → 再叠加伏笔专属特征 → 统一排序。

### 6.2 与 hooks.jsonl 同源同步（强制）

伏笔专项状态机与既有 hooks 轻量状态机的映射：`planted / reinforced → open`、`half-closed → half`、`closed → closed`、`overdue → open + 超期标记`、`broken → closed + 矛盾标记`。

**回写纪律**：每章审后伏笔状态推进**一次回写两处**（hooks.jsonl + foreshadow_table.md），严禁只写一处造成账实分离；台账为完整账（分类 / 优先级 / 回收计划），hooks 为轻量账（服务 D2 连载一致性速查），检索时互为引用、**不出两套结论**。

### 6.3 跨章节继承与隔离

- 每章审稿第1步自动读取 `foreshadow_table.md` 全局台账作为增量校验底座（不存在则本章审后首次建档）；
- 台账随项目 `.review-db/` 存放 / 备份 / 移动，不随技能分发，与 1.3 隔离铁律一致；
- 伏笔专项数据独立于原向量库集合（plots/facts/characters/dialogues/hooks/values），物理隔离不污染原库；`.review-db/foreshadow/` 与 `.review-db/gender-transition/` 同为专项独立子目录。
