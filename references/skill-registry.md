# 外部技能功能数据库（Skill Registry）

审稿启动时自动扫描本机技能目录，识别已安装的文字创作类技能，提取核心功能参数，建立调度映射。

> **v3.0 重大变更：规则已离线内置。** 下列九大技能的核心规则不再只是"调度引用"，已完整内化为 [rules-pack/](rules-pack/INDEX.md) 离线规则包：
> - 本机**已安装**对应技能 → 报告中标注 `[调度:技能名]`（规则来源可追溯）；
> - 本机**未安装** → 自动使用内置规则包，标注 `[内置规则包]`，审稿能力不降级；
> - 规则包为检查清单本体，外部技能文件不再是审稿必需品；用户要求"用 XX 技能深度改写"时仍建议在主对话显式触发原技能。
>
> | 技能 | 内置规则包 | 内置状态 |
> |------|-----------|---------|
> | novel-audit 网文审计 | ai-flavor-rules（词库/25项速检）、character-logic-rules（11维判定）、scripts/text_stats.py | ✅ 规则+脚本已内置 |
> | plot-tension-review | character-logic-rules §1.5（五维加权/Top3 格式） | ✅ 已内置 |
> | 网文对话博弈大师 | dialogue-game-rules（5铁则/3场景/话题阶梯/Q1-Q10） | ✅ 已内置 |
> | novel-social-intelligence | character-logic-rules §2-3、social-audit-checklist、social-scenario-rules、social_persona_card/relationship_ledger 模板、向量库社交三集合 | ✅ 规则+清单+模板已内置 |
> | qu-ai-wei-main | ai-flavor-rules（51类模式精要/语体矩阵/仲裁/六法） | ✅ 已内置（精要版） |
> | 说人话 shuorenhua | ai-flavor-rules（Tier 密度阈值/表演腔/装饰性细节/scope 纪律） | ✅ 已内置（精要版） |
> | humanizer-zh-main | ai-flavor-rules §六（24类/删除金句/灵魂6法/50分评分思路） | ✅ 已内置（精要版） |
> | 番茄 fanqie-novel-skill | platform-gate-rules（门禁8项/话疗/战斗/循环/rubric/生死线）、ai-flavor-rules（9禁用词） | ✅ 已内置；**合规红线细目为自建**（原技能仅有5条宏观红线） |
> | oh-story / story-review | template-cliche-rules（banned-words/21类检测器/开头同质化）、platform-gate-rules（三平台rubric）、character-logic-rules（读者契约/主角代理权） | ✅ 已内置（精要版） |

> 扫描路径（Trae 环境）：
> - `c:\Users\<用户>\.trae-cn\skills\`（用户级技能）
> - `c:\Users\<用户>\.trae-cn\work\*\oh-story-claudecode-main\skills\`（工作区技能）
> - 项目内 `.trae/skills/`（项目级技能）
>
> 扫描方式：用 Glob 检索 `**/SKILL.md`，读取 frontmatter 的 `name`/`description` 与正文能力章节，匹配下表技能名。命中即标记"已安装"，未命中标记"缺失→使用内置等效规则"。

---

## 一、已登记技能数据库（本机实测安装）

### S1. 网文审计技能（novel-audit）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/网文审计技能-novel-audit/` |
| 核心能力 | 11维度系统审计（文字/重复/AI痕迹/情节/时间线/连贯/视角/节奏爽点/人物/世界观/对话） |
| 关键参数 | 加权评分：A类(基础质量)×0.35 + B类(叙事逻辑)×0.40 + C类(阅读体验)×0.25；双模式（单章详审/多章对比）；25项AI快速检测（命中≥5项预警） |
| 输出格式 | 评分表 + 🔴🟡🟢分级问题清单 + ❌原文→✅建议→💡思路 三段式改写 |
| 审稿取用 | 作为本技能**基础12维审计的主框架**；报告模板沿用其评分表与三段式 |
| 触发词 | 审计、审稿、检查这章、有没有AI味、前后矛盾吗、质量怎么样 |

### S2. plot-tension-review（剧情张力审稿）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/plot-tension-review/` |
| 核心能力 | 剧情张力五维诊断：冲突强度(25%)、节奏控制(20%)、悬念钩子(20%)、因果链条(20%)、情绪起伏(15%) |
| 关键参数 | 段落功能标记法（冲突/说明/回忆/对话/动作/过渡段）；Top3核心问题输出（位置/本质/2-3种方案/预期效果）；张力曲线描述 |
| 审稿取用 | C1节奏爽点维度的细化工具；B1情节合理性的因果链检测 |
| 原则 | 只给可落地建议、不做文字润色、尊重原作设定、以读者留存为核心标准 |

### S3. 网文对话博弈大师

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/网文对话博弈大师/` |
| 核心能力 | 多轮对话审查与优化：嘴遁辩论、谈判博弈、日常互动、人情世故、反派算计、商战 |
| 关键参数（铁则） | ①对话-动作锚定比例：每2-3句对白配1处动作/神态；②潜台词三层：表层义+真实意图+情绪暗流，直白说明≤30%；③轮次推进：每轮必须改变局势；④人设语言锚点；⑤节奏：情绪越烈句子越短 |
| 场景公式 | 攻防回合制（对峙）、筹码拉锯线（谈判：试探-出价-还价-施压-让步）、话题阶梯升级法（事实→立场→底线→利益，每3轮升一阶，超2轮无进展必须抛新变量） |
| 审稿取用 | C4对话质量维度主规则；商战文B2谈判检测；恋爱文L1暧昧对话检测 |
| 禁用清单 | 50字以上独白、千人一面、对话后局势无变化、"他生气地说"直白情绪词 |

### S4. novel-social-intelligence-skill（人情世故增强）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/novel-social-intelligence-skill/` |
| 核心能力 | 社交设定注入、对话潜台词分层、行为利益校准、关系图谱与人情账本审计 |
| 依赖文件 | `setting/character_social.md`（社交人格卡）、`setting/relationship_map.md`（关系利益图谱）、`setting/social_scenarios.md`（场景社交规则）；缺失则用模板生成 |
| 关键参数 | ①行为决策逻辑：**利益 > 立场 > 情绪 > 对错**；②禁止配角降智/反派送人头；③社交段位匹配：高位者留余地、小人物可直来直去；④求人/拒绝场景：客套铺垫-说事-推拉-收尾，话不说透留台阶 |
| 后置审计 | OOC点标注、人情往来记账（谁欠谁人情/好感猜忌变化/阵营变动） |
| 审稿取用 | D1人情世故维度主规则；商战文B3反派不降智检测；日常文R1活人感 |

### S5. qu-ai-wei-main（去AI味）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/qu-ai-wei-main/` |
| 核心能力 | 简体中文AI腔检测与改写：51类模式 + 冲突仲裁顺序六级 |
| 关键参数 | 模式分组：A内容(空洞拔高/背景套话)、B语言(高频词堆叠/名词化)、B+逻辑连接空转、C修辞(成语排比模板化)、D交流(客服腔/谄媚)、E填充(冗余短语)、F翻译腔、G篇章节奏(句长均质化)、H平台文体(自媒体套路/故事AI味)、I幻觉格式 |
| 核心原则 | **看密度不看出现**（单次出现不判，200字内反复堆叠才判）；语体识别前置（9种语体激进度不同，叙事文保留铺垫）；不发明事实；信息完整性（改写不删事实） |
| 打磨六法 | 动词强化、节奏重塑、filler切除、抽象换具体、语序归位、保留人味 |
| 审稿取用 | A3 AI痕迹维度主规则库 |

### S6. 说人话（shuorenhua）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/说人话/` |
| 核心能力 | AI套路清理：模板感、收束腔、虚假主语、语域漂移、表演性技术腔 |
| 关键参数 | 场景判定(chat/status/docs/public-writing) → 保护项划界(protected spans) → Tier1/2/3问题强度 → 档位(minimal/standard/aggressive) → scope(structural/bounded/in-place)；保真回读+残留味回读两遍 |
| 原则 | 保信息优先；不用机械同义词替换；关键词该重复就重复；可删句/并句/降调/换主语/去总结式收尾 |
| 审稿取用 | A3维度补充规则；改写建议的力度控制参考 |

### S7. humanizer-zh-main

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/humanizer-zh-main/` |
| 核心能力 | 识别去除AI生成文本痕迹，使文字自然有人味 |
| 审稿取用 | A3维度交叉验证；"人味"细节（自嘲/不确定/不合时宜小动作）的判定参考 |

### S8. 番茄小说写作 Skill（fanqie-novel-skill）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/番茄小说写作-skill/` |
| 核心能力 | 番茄平台长篇系统：Truth Files状态维护 + 平台规则 + AI去味 + 商业审查 |
| 关键参数（写后最小审计集8项） | ①字数2000-2500；②AI去味（替换非删除）；③因果链；④行为-规则一致性；⑤时间线；⑥战斗场景；⑦**对话占比≤40%**；⑧**话疗检测（BOSS禁止被说服）** |
| 状态文件 | story_bible / book_rules / outline / current_state / pending_hooks / handoff_current / progress_tracker / pattern-detection（循环模式每5章更新） |
| 审稿取用 | 平台门禁审（genre-matrix 第六节）；D2连载一致性的状态文件交叉引用；叙事循环检测 |

### S9. AI 小说创作引擎 v3.0

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/ai-小说创作引擎-v3-0/`（含 sub-skills/） |
| 相关子技能 | novel-memory-load（记忆加载）、novel-check-quality（质量检查）、novel-chapter-update（章节更新） |
| 关键参数 | 记忆加载策略：必载(世界观/主角/力量体系/大纲)+相关(活跃伏笔/上一章/出场人物)，Token≤8000超限按相关性截断；离线≥10章角色需生成变化 |
| 质检规则 | 一致性(设定冲突/OOC)警告不阻塞；结构60-20-20比例（铺垫-高潮-收尾）错误需修正；完整性必填元素缺失需修正 |
| 审稿取用 | 记忆加载策略参考；C1节奏维度的60-20-20结构比例校验 |

### S10. oh-story · story-review（多视角对抗式审查）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/work/.../oh-story-claudecode-main/skills/story-review/` |
| 核心能力 | 四视角对抗审查：story-architect（结构）、character-designer（角色）、narrative-writer（叙事文字）、consistency-checker（一致性）；full/lean/solo三模式，agent缺失自动降级solo |
| 参考规则库 | review-quality（质量清单）、quality-rubric（评分）、anti-ai-writing（去AI味）、plot-core-methods（剧情循环/高潮公式）、character-relations（角色关系/好感度）、dialogue-mastery（对话）、banned-words（禁用词）、平台rubric（fanqie/qidian/zhihu） |
| 铁律 | "审查是找问题，不是验证正确性" |
| 审稿取用 | 多视角审查思路；平台rubric选择；禁用词库交叉验证 |

### S11. silver-novel-skills-master

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/silver-novel-skills-master/` |
| 核心能力 | 小说架构师，按需加载分类 INDEX.md 与对应文件，引导创作全流程 |
| 审稿取用 | 需要查阅创作方法论/分类索引时的参考库 |

### S12. oh-story 主技能（全流程工具箱）

| 项 | 内容 |
|----|------|
| 路径 | `~/.trae-cn/skills/oh-story/` 及工作区 story-long-* / story-short-* 系列 |
| 相关子技能 | story-long-analyze（长篇拆文分析）、story-deslop（去糟粕）、story-review（审查） |
| 审稿取用 | 长篇跨章分析方法；扫榜/拆文视角的商业性判断 |

---

## 二、审稿问题 → 技能调度映射表

审稿中发现某类问题时，按此表调用对应技能规则，并在报告中标注 `[调度:技能名]`：

| 问题类型 | 主调度 | 辅助调度 |
|---------|--------|---------|
| AI腔/套话/翻译腔 | S5 qu-ai-wei | S6 说人话、S7 humanizer、S10 anti-ai-writing |
| 对话干巴/同质化/无潜台词 | S3 对话博弈大师 | S10 dialogue-mastery、S4 |
| 谈判/商战博弈失真 | S3 对话博弈大师（场景3） | S4 social-intelligence |
| 人物OOC/行为不符合利益 | S4 social-intelligence | S10 character-relations、S9 质检 |
| 社交失分寸/人情世故假 | S4 social-intelligence | S3（场景1人情世故专项） |
| 剧情平/拖沓/无钩子 | S2 plot-tension-review | S10 plot-core-methods、S9（60-20-20） |
| 时间线/设定/伏笔矛盾 | S1 novel-audit（B类） | S8 current_state/pending_hooks、本技能记忆索引 |
| 数值/物品/技能穿帮 | 本技能记忆索引（D2） | S8 Truth Files、S9 memory-load |
| 节奏注水/对话占比过高 | S8 番茄skill（维度31） | S2 节奏控制 |
| 冲突靠嘴炮解决 | S8 番茄skill（话疗检测维度32） | S2 冲突强度 |
| 桥段克隆/叙事循环 | S8 pattern-detection | S1（A2重复雷同） |
| 评分/综合评级 | S1 novel-audit 加权公式 | S10 quality-rubric、平台rubric |
| 平台合规/发布门禁 | S8 番茄skill | S10 平台rubric（fanqie/qidian/zhihu） |

---

## 三、调度规则

1. **规则内化为主，技能切换为辅**：默认将外部技能的判定规则内化为检查清单执行，报告中标注调度来源；不中断审稿流程去切换技能。
2. **用户显式要求时深度转交**：用户说"用去AI味技能重写这段""让对话大师改这段对话"时，在审稿报告后建议用户在主对话显式触发对应技能做专项改写，并附上建议的触发指令（如 `去AI味：[段落]`）。
3. **技能缺失降级**：某技能未安装时，使用本技能内置的等效规则（基础12维 + genre-matrix 已覆盖大部分判定），报告中标注"[内置规则]"。
4. **规则冲突仲裁**：记忆文档事实 > 平台规则（S8/S10 rubric）> 专项技能方法论（S2/S3/S4）> 通用写作规律。
5. **不重复造轮子**：外部技能已有详细词库/清单的（如S5的51类模式、S3的场景示例库），审稿时直接引用其结论框架，不在本技能内复制维护词库，只存索引。
