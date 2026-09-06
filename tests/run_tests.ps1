# run_tests.ps1 - urban-novel-reviewer v3.9.0 测试套件（单元 + 集成）
# 零依赖 PowerShell，Windows 原生运行：
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
# 覆盖：T1 结构完整性（含 v3.8 已删文件清除确认）/ T2 九技能映射 / T3 六大审查接线 /
#       T4 脚本集成 / T5 坏样本AI味检出 / T6 好样本低误判 / T7 对话博弈 / T8 模板化 /
#       T9 合规红线机制 / T10 向量库 v3.7 临时提取策略 / T11 v3.1前置语义解析层接线 /
#       T12 v3.2大纲审稿分支+系统文专项接线 / T13 v3.2.1系统文扩容接线 /
#       T14 v3.3.0性别转变角色专项接线 /
#       T15 v3.3.1性转兼容方案接线（版本统一/三层路由/六项复用/双触发+降级+开关/统一附录输出/跨模块联动/原生兼容/灰度兜底/全链路版本一致性）/
#       T16 v3.4.0伏笔追踪专项接线（版本统一/判定-冲突-分题材三规则包/触发与深度三档/index.json 台账/附录输出/INDEX联动/灰度兜底/README登记）/
#       T18 v3.5.0数据路径架构重构接线（版本统一/前置约定四条+目录树/按需加载三步/手动指令集/统一附录输出/全局资源索引/总数一致性；
#              v3.9.0 起版本链路顺延为 3.9.0，目录树/指令集/附录骨架按 v3.7~v3.9 现状校验）/
#       T19 v3.6.0公路求生·克苏鲁向题材适配接线（版本历史保留/#21赛道模板/F23-F27第六大类伏笔/12类分题材模板/
#              §1.6节点节奏+§2.6 SAN分级/SKILL全链路+意图词典/INDEX联动/genre-classifier+vector-db交叉引用/
#              零侵入门控+灰度回退/README同步；v3.9.0 起台账载体按 index.json 校验）/
#       T20 v3.7/v3.8/v3.9 记忆架构接线（版本全链路统一/轻量索引四件套/三级更新分级/8指令集/
#              题材缓存路由/人物卡三级金字塔/v3.7精简架构/v3.8精简优化/增量写入规则/README登记）
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Ref = Join-Path $Root "references"
$Rules = Join-Path $Ref "rules-pack"
$Fixtures = Join-Path $PSScriptRoot "fixtures"
$script:Results = @()

function Check($tid, $name, [bool]$cond, $detail = "") {
    $script:Results += [pscustomobject]@{ Id = $tid; Name = $name; Ok = $cond; Detail = $detail }
}
function Read-Text($rel) {
    $p = Join-Path $Root $rel
    if (-not (Test-Path $p)) { return $null }
    # Always read as raw bytes then UTF8 decode — works with and without BOM on any PowerShell/codepage
    $bytes = [System.IO.File]::ReadAllBytes($p)
    $skip = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $skip = 3 }
    return [System.Text.Encoding]::UTF8.GetString($bytes, $skip, $bytes.Length - $skip)
}
function Count-Sub($hay, $needle) {
    if (-not $hay) { return 0 }
    $c = 0; $i = 0
    while (($i = $hay.IndexOf($needle, $i)) -ge 0) { $c++; $i += [Math]::Max(1, $needle.Length) }
    return $c
}

# ── T1 结构完整性（v3.9.0：rules-pack 12 文件 + review_flow 合并 + 已删文件清除确认）──
$required = @(
    "SKILL.md", "README.md",
    "references\skill-registry.md", "references\report-template.md",
    "references\review-vector-db.md", "references\style-memory-db.md",
    "references\memory-index.md", "references\genre-classifier.md", "references\genre-matrix.md",
    "references\rules-pack\INDEX.md",
    "references\rules-pack\ai-flavor-rules.md",
    "references\rules-pack\dialogue-game-rules.md",
    "references\rules-pack\character-logic-rules.md",
    "references\rules-pack\template-cliche-rules.md",
    "references\rules-pack\platform-gate-rules.md",
    "references\rules-pack\outline-review-rules.md",
    "references\rules-pack\system-novel-rules.md",
    "references\rules-pack\gender-transition-rules.md",
    "references\rules-pack\foreshadow-judgment-rules.md",
    "references\rules-pack\foreshadow-conflict-rules.md",
    "references\rules-pack\foreshadow-topic-templates.md",
    "references\templates\shared\templates\social_persona_card.md",
    "references\templates\shared\templates\relationship_ledger.md",
    "references\templates\shared\prompts\review_flow.md",
    "scripts\text_stats.py", "scripts\text_stats.ps1",
    "tests\fixtures\sample-bad.txt", "tests\fixtures\sample-good.txt"
)
$missing = $required | Where-Object { -not (Test-Path (Join-Path $Root $_)) }
# v3.8.0 已删除文件确认不存在 + SKILL/registry 无路径级残留引用（INDEX/README 历史说明性提及合法）
$deleted = @("references\rules-pack\social-audit-checklist.md", "references\rules-pack\social-scenario-rules.md")
$stillThere = @($deleted | Where-Object { Test-Path (Join-Path $Root $_) })
$skillEarly = Read-Text "SKILL.md"
$regEarly = Read-Text "references\skill-registry.md"
$staleRef = @()
foreach ($f in @("social-audit-checklist.md", "social-scenario-rules.md")) {
    if ($skillEarly -like "*$f*") { $staleRef += "SKILL.md::$f" }
    if ($regEarly -like "*$f*") { $staleRef += "skill-registry.md::$f" }
}
$t1ok = ($missing.Count -eq 0 -and $stillThere.Count -eq 0 -and $staleRef.Count -eq 0)
Check "T1" "技能包结构完整（rules-pack 12 文件+review_flow 合并+模板2+脚本2+样本2）+ v3.8 已删文件确认清除" $t1ok $(if (-not $t1ok) { "缺失: $($missing -join ', ')；应删未删: $($stillThere -join ', ')；残留引用: $($staleRef -join ', ')" } else { "$($required.Count) 个必备文件就位，2 个 v3.8 已删文件确认清除" })
$tmplCount = (Get-ChildItem (Join-Path $Ref "templates") -Recurse -Filter *.md).Count
Check "T1b" "silver 模板库离线副本保留(≥60)" ($tmplCount -ge 60) "模板文件数=$tmplCount"

# ── T2 九大技能映射 ──
$reg = Read-Text "references\skill-registry.md"
$skills = @("novel-audit", "plot-tension-review", "对话博弈大师", "social-intelligence", "qu-ai-wei", "说人话", "humanizer", "番茄", "oh-story")
$missReg = $skills | Where-Object { $reg -notlike "*$_*" }
Check "T2" "九大技能全部在 skill-registry 登记" ($missReg.Count -eq 0) $(if ($missReg) { "缺失: $($missReg -join ',')" } else { "9/9" })
$builtinMarks = ([regex]::Matches($reg, "✅")).Count
Check "T2b" "九大技能均标注离线内置状态(≥9个✅)" ($builtinMarks -ge 9) "内置标记数=$builtinMarks"
$idx = Read-Text "references\rules-pack\INDEX.md"
$packs = @("ai-flavor-rules", "dialogue-game-rules", "character-logic-rules", "template-cliche-rules", "platform-gate-rules")
$missPack = $packs | Where-Object { $idx -notlike "*$_*" }
Check "T2c" "rules-pack/INDEX 五个主规则包全部可索引" ($missPack.Count -eq 0) $(if ($missPack) { "缺失: $($missPack -join ',')" } else { "5/5" })

# ── T3 SKILL.md 六大审查接线 ──
$skill = Read-Text "SKILL.md"
$wiring = [ordered]@{
    "a)逻辑结构" = ($skill -like "*逻辑结构审查*")
    "b)人物塑造" = ($skill -like "*人物塑造审查*")
    "c)对话质量" = ($skill -like "*对话质量审查*")
    "d)模板化"   = ($skill -like "*内容模板化检查*")
    "e)内容合规" = ($skill -like "*内容合规审查*")
    "f)AI味"     = ($skill -like "*AI 味检查*")
    "门禁G0-G6"  = ($skill -like "*G0 合规红线*" -and $skill -like "*G6*")
    "规则包引用" = ($skill -like "*rules-pack/ai-flavor-rules.md*" -and $skill -like "*rules-pack/platform-gate-rules.md*")
    "版本3.3.1"  = ($skill -like "*version: 3.3.1*" -or $skill -like "*3.3.1*")
    "脚本说明"   = ($skill -like "*text_stats.py*")
}
$badWire = @($wiring.Keys | Where-Object { -not $wiring[$_] })
Check "T3" "SKILL.md 六大审查+门禁+规则包全部接线" ($badWire.Count -eq 0) $(if ($badWire) { "未接线: $($badWire -join ',')" } else { "10/10 接线点" })

# ── T4 text_stats.ps1 脚本集成 ──
$scriptOut = & powershell -ExecutionPolicy Bypass -File (Join-Path $Root "scripts\text_stats.ps1") -Path (Join-Path $Fixtures "sample-bad.txt") -Mode ai 2>&1 | Out-String
Check "T4" "text_stats.ps1 可独立运行（--mode ai 等价）" ($LASTEXITCODE -eq 0 -and $scriptOut.Length -gt 100) "输出 $($scriptOut.Length) 字符"

# ── T5 坏样本 AI 味检出 ──
$bad = Get-Content (Join-Path $Fixtures "sample-bad.txt") -Raw -Encoding UTF8
$signals = @("深吸一口气", "嘴角微微上扬", "五味杂陈", "不动声色", "缓缓开口", "倒吸一口冷气", "面面相觑", "命运的齿轮", "空气中弥漫", "淡淡地说")
$sigHit = ($signals | Where-Object { $bad -like "*$_*" }).Count
Check "T5" "问题样本植入 AI 味信号充分(≥8/10)" ($sigHit -ge 8) "植入信号 $sigHit/10"
$scriptHit = $false
foreach ($s in @("深吸", "嘴角", "五味杂陈", "倒吸", "命运", "弥漫", "不禁", "仿佛")) { if ($scriptOut -like "*$s*") { $scriptHit = $true; break } }
Check "T5b" "量化脚本对问题样本产出命中输出" $scriptHit $(if ($scriptHit) { "脚本输出含命中词" } else { ($scriptOut.Substring(0, [Math]::Min(150, $scriptOut.Length)) -replace "`n", " ") })

# ── T6 好样本低误判（真人门检）──
$good = Get-Content (Join-Path $Fixtures "sample-good.txt") -Raw -Encoding UTF8
$human = @("骂了句脏话", "……", "你小子", "拍清了一半", "三元", "六点四十", "顿了顿")
$humHit = ($human | Where-Object { $good -like "*$_*" }).Count
Check "T6" "对照样本含真人毛边信号(≥4/7)" ($humHit -ge 4) "真人信号 $humHit/7"
$aiWords = @("深吸一口气", "嘴角微微上扬", "五味杂陈", "倒吸一口冷气", "命运的齿轮", "空气中弥漫", "未来可期", "不禁", "宛如")
$falseHit = @($aiWords | Where-Object { $good -like "*$_*" })
Check "T6b" "对照样本无高危 AI 套话（防误判）" ($falseHit.Count -eq 0) $(if ($falseHit) { "误含: $($falseHit -join ',')" } else { "0 误判" })
$goodOut = & powershell -ExecutionPolicy Bypass -File (Join-Path $Root "scripts\text_stats.ps1") -Path (Join-Path $Fixtures "sample-good.txt") -Mode ai 2>&1 | Out-String
function Get-AiTotal($out) {
    $m = [regex]::Match($out, "AI 特征词总命中:\s*(\d+)")
    if ($m.Success) { return [int]$m.Groups[1].Value } else { return -1 }
}
$badTotal = Get-AiTotal $scriptOut; $goodTotal = Get-AiTotal $goodOut
Check "T6c" "脚本对好坏样本有区分度（坏≥好）" ($badTotal -ge $goodTotal -and $goodTotal -ge 0) "坏样本命中=$badTotal / 好样本命中=$goodTotal"

# ── T7 对话博弈 ──
$drules = Read-Text "references\rules-pack\dialogue-game-rules.md"
$dth = @("2-3 句", "≥4 个对白轮次", "≤30%", "50 字", ">0.7", "每 3 轮", ">2 轮", "≤10 字", "≥20 字")
$missD = @($dth | Where-Object { $drules -notlike "*$_*" })
Check "T7" "对话博弈规则含量化阈值(9项)" ($missD.Count -eq 0) $(if ($missD) { "缺失: $($missD -join ',')" } else { "9/9 阈值" })
Check "T7b" "问题样本含飘对话/轮次空转场景" ($bad -like "*你到底想怎么样*" -and $bad -like "*没得谈*") "对峙+空转桥段已植入"
$anchors = ([regex]::Matches($good, "筷子|抹布|碗|手机|蛋|棚子|指尖|站|低头|凑近|斜")).Count
Check "T7c" "对照样本动作锚定密集(≥8处)" ($anchors -ge 8) "锚定动作 $anchors 处"

# ── T8 模板化 ──
$crules = Read-Text "references\rules-pack\template-cliche-rules.md"
$cmust = @("不是 A", "眼中闪过", "嘴角勾起", "T1", "T5", "T8", "21 类", "同质化", "章尾", "身体部位")
$missC = @($cmust | Where-Object { $crules -notlike "*$_*" })
Check "T8" "模板化规则包覆盖克隆/最毒句式/检测器/同质化" ($missC.Count -eq 0) $(if ($missC) { "缺失: $($missC -join ',')" } else { "10/10 要点" })
Check "T8b" "问题样本含章尾总结体/预告体" ($bad -like "*刚刚开始*" -and $bad -like "*他不知道的是*") "trailer 信号已植入"

# ── T9 合规红线 ──
$gates = Read-Text "references\rules-pack\platform-gate-rules.md"
$cgroups = @("C1 政治", "C2 色情", "C3 暴力", "C4 封建迷信", "C5 价值观", "C6 平台")
$missG = @($cgroups | Where-Object { $gates -notlike "*$_*" })
Check "T9" "合规红线 C1-C6 六组全部建立" ($missG.Count -eq 0) $(if ($missG) { "缺失: $($missG -join ',')" } else { "6/6 组" })
$gitems = @("G1 字数", "G2 对话占比", "G3 话疗", "G4 战斗", "G5 循环", "G6 节奏")
$missGi = @($gitems | Where-Object { $gates -notlike "*$_*" })
Check "T9b" "平台门禁 G1-G6 完整" ($missGi.Count -eq 0) $(if ($missGi) { "缺失: $($missGi -join ',')" } else { "6/6 门禁项" })
$gth = @("2000-2500", "40%", "三句话", "≥3 次", "70%", "15%")
$missGt = @($gth | Where-Object { $gates -notlike "*$_*" })
Check "T9c" "门禁关键阈值齐全" ($missGt.Count -eq 0) $(if ($missGt) { "缺失: $($missGt -join ',')" } else { "字数/占比/话疗/攻击/相似度/高潮密度 就位" })
$rt = Read-Text "references\report-template.md"
Check "T9d" "报告模板含门禁表与未命中免责声明" ($rt -like "*G0 合规红线*" -and $rt -like "*不替代平台审核*") "门禁表+声明就位"

# ── T10 向量库 v3.7.0 临时提取策略（原社交三集合持久化已砍，改为临时提取审完即弃）──
$vdb = Read-Text "references\review-vector-db.md"
$v37Keys = @("v3.7.0 重大精简", "临时提取", "审完即弃", "social")
$missV37 = @($v37Keys | Where-Object { $vdb -notlike "*$_*" })
Check "T10" "向量库 v3.7.0 精简策略接线（社交/人物/剧情等向量临时提取、审完即弃、不持久化）" ($missV37.Count -eq 0) $(if ($missV37) { "缺失: $($missV37 -join ',')" } else { "4/4 精简要点" })
$vfields = @("tier", "move_type", "轮次空转", "阶梯停滞", "局势零变化", "单方碾压")
$missVf = @($vfields | Where-Object { $vdb -notlike "*$_*" })
Check "T10b" "dialogues 博弈字段与判定接线" ($missVf.Count -eq 0) $(if ($missVf) { "缺失: $($missVf -join ',')" } else { "tier/move_type+4条博弈判定" })

# ── T11 v3.1 前置语义解析层接线 ──
$parse = [ordered]@{
    "前置解析章节" = ($skill -like "*输入解析与意图路由规则*" -and $skill -like "*优先级最高*")
    "语义补全四维度" = ($skill -like "*审稿对象*" -and $skill -like "*审稿维度*" -and $skill -like "*审稿深度*" -and $skill -like "*输出要求*")
    "上下文继承"   = ($skill -like "*上下文继承*" -and $skill -like "*继承上一轮*")
    "审稿任务单"   = ($skill -like "*审稿任务单*" -and $skill -like "*核心维度*" -and $skill -like "*执行标准*")
    "路由表"       = ($skill -like "*路由执行*" -and $skill -like "*路由到*")
    "分级澄清"     = ($skill -like "*轻度模糊*" -and $skill -like "*中度模糊*" -and $skill -like "*重度模糊*")
    "意图词典附录" = ($skill -like "*附录：审稿意图词典*" -and $skill -like "*指令修饰词*")
    "误触发限定"   = ($skill -like "*仅用于网文小说创作中的审稿与润色场景*" -or $skill -like "*仅用于网文小说、文稿的审稿与润色场景*" -or $skill -like "*适用于审稿*")
}
$badParse = @($parse.Keys | Where-Object { -not $parse[$_] })
Check "T11" "v3.1 前置语义解析层（补全/继承/任务单/路由/澄清/词典/限定）全接线" ($badParse.Count -eq 0) $(if ($badParse) { "未接线: $($badParse -join ',')" } else { "8/8 接线点" })
$dictWords = @("人设崩", "人物不对劲", "太假了", "台词尬", "商战假", "番茄能过吗", "文风飘了", "简单看看", "第三章也来一遍")
$missDict = @($dictWords | Where-Object { $skill -notlike "*$_*" })
Check "T11b" "意图词典覆盖口语化触发词(9项)" ($missDict.Count -eq 0) $(if ($missDict) { "缺失: $($missDict -join ',')" } else { "9/9 口语词" })

# ── T12 v3.2 大纲审稿分支 + 系统文专项接线 ──
$ol = Read-Text "references\rules-pack\outline-review-rules.md"
$sy = Read-Text "references\rules-pack\system-novel-rules.md"
$idxNew = Read-Text "references\rules-pack\INDEX.md"
$v32skill = [ordered]@{
    "版本3.3.1"      = ($skill -like "*3.3.1*")
    "大纲分支章节"   = ($skill -like "*大纲审稿专项流程*" -and $skill -like "*输入类型判断*")
    "只建议不改写"   = ($skill -like "*只提建议、不改原文*" -or $skill -like "*只提建议不改原文*")
    "大纲模式表"     = ($skill -like "*大纲专项审*" -and $skill -like "*系统文专项*")
    "意图词典大纲类" = ($skill -like "*大纲审稿分支*" -and $skill -like "*卷纲*" -and $skill -like "*章纲*")
    "新铁律第9条"    = ($skill -like "*大纲/设定只提建议不改原文*")
}
$bad32 = @($v32skill.Keys | Where-Object { -not $v32skill[$_] })
Check "T12" "SKILL.md v3.2 大纲分支+系统文全接线" ($bad32.Count -eq 0) $(if ($bad32) { "未接线: $($bad32 -join ',')" } else { "6/6 接线点" })
$olMust = @("大纲 / 卷纲 / 章纲 / 设定集", "前置识别", "模板匹配", "前瞻风险", "核心问题", "前瞻预警", "章纲细化", "只提建议、不改原文")
$missOl = @($olMust | Where-Object { $ol -notlike "*$_*" })
Check "T12b" "outline-review-rules 四步流程+三级输出+章纲清单+铁则齐全" ($missOl.Count -eq 0) $(if ($missOl) { "缺失: $($missOl -join ',')" } else { "8/8 要点" })
$syMust = @("登场节点", "黄金三章", "触发逻辑", "主线任务", "≥10 章", "可选任务占比", "≥60%", "世界观上限的 10%", "签到流", "神豪流", "职业 / 技能流", "末世求生流", "诸天穿梭流", "种田经营流", "好感度", "属性加点流", "终极目标", "信息差", "边际递减")
$missSy = @($syMust | Where-Object { $sy -notlike "*$_*" })
Check "T12c" "system-novel-rules 四维度阈值+主流八类型模板要点齐全" ($missSy.Count -eq 0) $(if ($missSy) { "缺失: $($missSy -join ',')" } else { "19/19 要点" })
Check "T12d" "rules-pack/INDEX 登记两个新规则包" ($idxNew -like "*outline-review-rules.md*" -and $idxNew -like "*system-novel-rules.md*") "INDEX 双包登记"

# ── T13 v3.2.1 系统文专项扩容接线（20 类赛道 + 12 套性格人设 + 双校验；v3.6.0 起赛道扩至 21 类）──
$v321skill = [ordered]@{
    "版本3.5.0"    = ($skill -like "*3.5.0*")
    "赛道模板计数" = ($skill -like "*21 类*" -or $skill -like "*21类*")
    "性格人设库"   = ($skill -like "*性格人设*")
    "双校验"       = ($skill -like "*双校验*")
    "三节点推演"   = ($skill -like "*30 章*" -and $skill -like "*大结局*")
}
$bad321 = @($v321skill.Keys | Where-Object { -not $v321skill[$_] })
$t13extra = ($idxNew -like "*20 类赛道模板*")
Check "T13" "SKILL.md v3.2.1 系统文扩容（21类赛道现状+INDEX 20类扩容历史+性格人设/双校验/三节点）全接线" (($bad321.Count -eq 0) -and $t13extra) $(if ($bad321) { "未接线: $($bad321 -join ',')" } elseif (-not $t13extra) { "INDEX 缺 20 类扩容历史声明" } else { "5/5 接线点 + INDEX 历史声明" })
$types12 = @("反派 / 掠夺系统", "直播 / 弹幕系统", "词条 / 设定编辑系统", "养崽 / 宿主养成系统", "轮回 / 死亡回档系统", "身份扮演 / 马甲系统", "学霸 / 知识转化系统", "诡异 / 克苏鲁系统", "宗门 / 门派建设系统", "美食 / 食神系统", "山贼 / 军阀争霸系统", "赘婿 / 上门龙婿系统")
$missT12 = @($types12 | Where-Object { $sy -notlike "*$_*" })
Check "T13b" "system-novel-rules 新增 12 类细分赛道模板（含设定标准/崩盘点/校验清单）" ($missT12.Count -eq 0) $(if ($missT12) { "缺失: $($missT12 -join ',')" } else { "12/12 赛道" })
$personas = @("冰冷机械型", "毒舌吐槽型", "软萌可爱型", "腹黑奸商型", "导师长辈型", "三无寡言型", "骚话搞怪型", "威严主神型", "忠犬守护型", "疯批混沌型", "功利冷漠型", "博学资料库型")
$missP = @($personas | Where-Object { $sy -notlike "*$_*" })
Check "T13c" "system-novel-rules 新增 12 套系统性格人设模板" ($missP.Count -eq 0) $(if ($missP) { "缺失: $($missP -join ',')" } else { "12/12 人设" })
$v321sy = @("人设一致性", "题材适配度", "双重校验", "30 章", "100 章", "大结局", "系统机制评分", "系统人设评分", "中期风险预警", "优化建议")
$missV321 = @($v321sy | Where-Object { $sy -notlike "*$_*" })
Check "T13d" "system-novel-rules 双子维度+双校验+三节点+输出四模块齐全" ($missV321.Count -eq 0) $(if ($missV321) { "缺失: $($missV321 -join ',')" } else { "10/10 要点" })
$idxV321 = @("20 类", "性格人设")
$missIdx321 = @($idxV321 | Where-Object { $idxNew -notlike "*$_*" })
Check "T13e" "rules-pack/INDEX 同步 v3.2.1 系统文扩容描述" ($missIdx321.Count -eq 0) $(if ($missIdx321) { "缺失: $($missIdx321 -join ',')" } else { "2/2 要点" })
$readme321 = Read-Text "README.md"
Check "T13f" "README 登记 v3.2.1 版本与性格人设扩容" ($readme321 -like "*v3.2.1*" -and $readme321 -like "*性格人设*") "v3.2.1 版本记录+更新说明"

# ── T14 v3.3.0 性别转变角色专项接线（六大维度 + 6 套模板 + 正文联动）──
# 确认新规则文件存在且关键章节齐全
$gt = Read-Text "references\rules-pack\gender-transition-rules.md"
$gtKps = @("六大核心审查维度", "心理转变逻辑", "行为习惯转变", "生理反应适配", "社会身份重构", "核心人设一致性", "剧情价值匹配",
          "硬性转", "渐变式性转", "女装大佬", "变嫁文", "末世求生性转", "修仙 / 玄幻性转", "职场 / 商战性转", "娱乐圈性转", "古风情转", "无限流 / 系统性转", "校园青春性转", "反派 / 重生性转",
          "冲击与否认期", "抗拒与挣扎期", "妥协与适应期", "接纳与重构期", "整合与升华期",
          "试探与羞耻期", "习惯与动摇期", "分化与选择期",
          "排斥与戒备", "改观与动摇", "接纳与身份重构",
          "震惊与茫然期", "探索与碰壁期", "适应与整合期", "升华期",
          "强制型性转", "核心人设保留校验", "【转变节奏评分】", "【心理逻辑评分】", "【行为细节评分】",
          "核心问题", "分阶段优化建议", "前瞻风险预警",
          "C1", "C2", "C4")
$missGt = @()
foreach ($k in $gtKps) {
    $ok = $false
    switch ($k) {
        "核心问题"       { $ok = ($gt -like "*【核心问题*" -or $gt -like "*核心问题*") }
        "分阶段优化建议" { $ok = ($gt -like "*【分阶段优化建议*" -or ($gt -like "*优化建议*" -and $gt -like "*阶段*")) }
        "前瞻风险预警"   { $ok = ($gt -like "*【前瞻风险预警*" -or $gt -like "*前瞻风险*" -or $gt -like "*前瞻预警*") }
        default          { $ok = ($gt -like "*$k*") }
    }
    if (-not $ok) { $missGt += $k }
}
Check "T14"  "gender-transition-rules 六大维度+四模式+双方向+八小众赛道+6套模板+输出七模块+C1/C2/C4联动齐全" ($missGt.Count -eq 0) $(if ($missGt) { "缺失: $($missGt -join ',')" } else { "$(@($gtKps).Count)/$(@($gtKps).Count) 要点" })
# SKILL 接线：新路由行 + 新审查模式行 + 参考文件行 + 意图词典行
$gtSkillKps = @("性别转变专项", "gender-transition-rules", "六大维度", "性转、性别转换、变身", "女装大佬、伪娘、男娘", "变嫁", "强制型性转叠加")
$missGtS = @($gtSkillKps | Where-Object { $skill -notlike "*$_*" })
Check "T14b" "SKILL.md 性别转变模块全接线（路由/模式/参考/意图词/叠加）" ($missGtS.Count -eq 0) $(if ($missGtS) { "未接线: $($missGtS -join ',')" } else { "$(@($gtSkillKps).Count)/$(@($gtSkillKps).Count) 接线点" })
# INDEX 条目与联动规则
$idxGtKps = @("gender-transition-rules.md", "性别转变正文联动", "强制型性转同时叠加")
$missIdxGt = @($idxGtKps | Where-Object { $idxNew -notlike "*$_*" })
Check "T14c" "rules-pack/INDEX 新规则登记与正文联动" ($missIdxGt.Count -eq 0) $(if ($missIdxGt) { "缺失: $($missIdxGt -join ',')" } else { "3/3 要点" })
# README 登记
$readme = Read-Text "README.md"
Check "T14d" "README 登记 v3.3.0 性别转变专项 + v3.3.1 兼容方案" ($readme -like "*v3.3.0*" -and $readme -like "*性别转变*" -and $readme -like "*v3.3.1*") "README 版本记录+更新说明"

# ── T15 v3.3.1 性转 / 变嫁专项兼容方案接线 ──
# T15a v3.3.1 版本历史链路保留（SKILL/README/INDEX/GT-rules 声明 3.3.1；README 徽章已顺延为 version-3.9.0）
$idx15 = Read-Text "references\rules-pack\INDEX.md"
$gt15  = Read-Text "references\rules-pack\gender-transition-rules.md"
$t15a = ($skill -like "*3.3.1*" -and $readme -like "*version-3.9.0*" -and $readme -like "*v3.3.1*" -and $idx15 -like "*3.3.1*" -and $gt15 -like "*3.3.1*")
Check "T15a" "v3.3.1 版本历史保留 + 徽章顺延（SKILL/README/INDEX/GT-rules 声明 3.3.1；README 徽章=version-3.9.0）" $t15a $(if ($t15a) { "5/5 声明到位（含 README v3.9.0 徽章顺延校验）" } else { "SKILL=$($skill -like '*3.3.1*') README_39=$($readme -like '*version-3.9.0*') README_331=$($readme -like '*v3.3.1*') INDEX=$($idx15 -like '*3.3.1*') GT=$($gt15 -like '*3.3.1*')" })

# T15b SKILL 三层路由架构 + 四级优先级排序
$routingKeys = @("语义解析层", "通用审稿内核", "专项增强层", "统一输出层", "正文 / 大纲 / 设定集", "主题材匹配", "通用专项匹配", "细分专项匹配")
$missRoute = @($routingKeys | Where-Object { $skill -notlike "*$_*" })
Check "T15b" "SKILL.md 三层路由架构（四节点链路）+ 四级路由优先级排序齐全" ($missRoute.Count -eq 0) $(if ($missRoute) { "缺失: $($missRoute -join ',')" } else { "$(@($routingKeys).Count)/$(@($routingKeys).Count) 要点" })

# T15c 六项底层能力复用（记忆扩展字段 / 4 类向量 / 文风校准 / 三步模板叠加 / 通用优先三仲裁 / 调度增强标注）
$reuseKeys = @("性别转变状态", "当前阶段", "核心转变节点",
               "gender_state", "性别场景文风校准",
               "主题材模板", "性转专项模板",
               "通用规则优先级高于专项规则",
               "[调度:技能名 + 性转专项增强]")
$missReuse = @($reuseKeys | Where-Object { $skill -notlike "*$_*" -or (
    # 记忆/向量/文风/模板/规则/调度 六支柱覆盖：INDEX 也同步声明通用优先
    $_ -eq "通用规则优先级高于专项规则" -and -not ($idx15 -like "*$_*" -and $gt15 -like "*$_*")) })
Check "T15c" "六项底层能力复用（记忆3字段 / gender_state 向量 / 文风校准 / 三步模板叠加 / 通用优先三仲裁 / 调度增强标注）全链路接线" ($missReuse.Count -eq 0) $(if ($missReuse) { "缺失: $($missReuse -join ',')" } else { "$(@($reuseKeys).Count)/$(@($reuseKeys).Count) 要点" })

# T15d 双重触发校验 + 四级优先级 + <70% 自动降级 + 手动开关两指令
$triggerKeys = @("双重触发校验", "性转类关键词", "上下文确认题材匹配", "70%", "自动降级", "启用性转专项审查", "禁用性转专项，按通用标准审")
$missTrigger = @()
foreach ($k in $triggerKeys) {
    $ok = $false
    switch ($k) {
        # 「上下文确认题材匹配」兼容同源表述：上下文确认为性转题材 / 上下文确认题材匹配
        "上下文确认题材匹配" { $ok = ($skill -like "*上下文确认题材匹配*" -or $skill -like "*上下文确认为性转题材*") }
        "双重触发校验"      { $ok = ($skill -like "*$_*" -and $idx15 -like "*$_*" -and $gt15 -like "*$_*") }
        default             { $ok = ($skill -like "*$_*") }
    }
    if (-not $ok) { $missTrigger += $k }
}
Check "T15d" "三级触发防护（双重触发条件/四级优先级排序/置信度<70%自动降级/手动开关两指令）齐全" ($missTrigger.Count -eq 0) $(if ($missTrigger) { "缺失: $($missTrigger -join ',')" } else { "$(@($triggerKeys).Count)/$(@($triggerKeys).Count) 要点" })

# T15e 统一附录式输出（未命中不变 / 命中追加附录四子段 / 单独计分不影响总分 / 建议级灰度默认）
$outputKeys = @("【专项审查附录】", "转变节奏评分", "心理逻辑评分", "行为细节评分", "核心人设一致性校验", "单独计分", "建议级")
$missOutput = @()
foreach ($k in $outputKeys) {
    $ok = $false
    switch ($k) {
        # SKILL v3.8 瘦身后四子段为斜杠连写（转变节奏/心理逻辑/行为细节评分），按子串兼容；其余三文档仍查完整词
        "转变节奏评分" { $ok = ($skill -like "*转变节奏*" -and $idx15 -like "*$k*" -and $gt15 -like "*$k*" -and $readme -like "*$k*") }
        "心理逻辑评分" { $ok = ($skill -like "*心理逻辑*" -and $idx15 -like "*$k*" -and $gt15 -like "*$k*" -and $readme -like "*$k*") }
        default        { $ok = ($skill -like "*$k*" -and $idx15 -like "*$k*" -and $gt15 -like "*$k*" -and $readme -like "*$k*") }
    }
    if (-not $ok) { $missOutput += $k }
}
Check "T15e" "统一附录式输出兼容（未命中输出不变 / 命中追加【专项审查附录】四子段 / 单独计分不影响总分 / 默认建议级灰度）四文档一致" ($missOutput.Count -eq 0) $(if ($missOutput) { "缺失: $($missOutput -join ',')" } else { "$(@($outputKeys).Count)/$(@($outputKeys).Count) 要点" })

# T15f 跨模块联动九点（大纲阶段规划三 / 系统双源分流三+节奏匹配度 / 合规复用C1-C6三要点）
$crossKeys = @("阶段规划校验", "变嫁情感线与主线剧情的节奏匹配度", "身份转变伏笔",
               "系统任务节奏与人物转变节奏是否匹配",
               "C1-C6 红线清单", "不单独做合规结论")
$missCross = @()
foreach ($k in $crossKeys) {
    $inSkill = $false
    $inGt = $false
    switch ($k) {
        # 系统/人物节奏匹配：兼容「匹配度：高 / 中 / 低 + 失配节点」的同源结论句式
        "系统任务节奏与人物转变节奏是否匹配" {
            $inSkill = ($skill -like "*系统任务节奏*" -and $skill -like "*人物转变节奏*匹配度*")
            $inGt    = ($gt15 -like "*系统任务节奏*" -and $gt15 -like "*人物转变节奏*匹配度*")
        }
        # C1-C6 红线清单：兼容「C1-C6 红线」等同源表述
        "C1-C6 红线清单" {
            $inSkill = ($skill -like "*C1-C6 红线*" -and $skill -like "*清单*") -or ($skill -like "*C1-C6 红线清单*")
            $inGt    = ($gt15 -like "*C1-C6*" -and ($gt15 -like "*清单*" -or $gt15 -like "*红线*"))
        }
        # 不单独做合规结论：兼容「不单独出具合规定论」「不单独下合规定论」的同源表述
        "不单独做合规结论" {
            $inSkill = ($skill -like "*不单独做合规结论*" -or $skill -like "*性转专项不单独*")
            $inGt    = ($gt15 -like "*不单独*合规*结论*" -or $gt15 -like "*不单独出具合规定论*")
        }
        default {
            $inSkill = ($skill -like "*$_*")
            $inGt    = ($gt15 -like "*$_*")
        }
    }
    if (-not ($inSkill -and $inGt)) { $missCross += $k }
}
Check "T15f" "跨模块联动九点（大纲×阶段规划 / 系统×双源分流+节奏匹配度 / 合规×C1-C6复用+不单独定论）在 SKILL 与 GT-rules 同步声明" ($missCross.Count -eq 0) $(if ($missCross) { "缺失: $($missCross -join ',')" } else { "$(@($crossKeys).Count)/$(@($crossKeys).Count) 要点" })

# T15g Trae Skill 原生兼容：上下文继承 + 性转参数 + 占位目录删除有声明（v3.7.0 起独立子目录并入 project_state.json）
$nativeKeys = @("上下文继承", "性转参数", "已删除合并")
$missNative = @()
foreach ($k in $nativeKeys) {
    $ok = $true
    switch ($k) {
        # 上下文继承：三文档需至少包含「上下文继承」短语
        "上下文继承" {
            $a = ($skill -like "*上下文继承*")
            $b = ($readme -like "*上下文继承*")
            $c = ($idx15 -like "*上下文继承*")
            $ok = ($a -and $b -and $c)
        }
        # 性转参数：兼容「性转参数 / 性别转变阶段 / 人物状态」等同源参数名
        "性转参数" {
            $a = ($skill -like "*性转参数*" -or $skill -like "*性别转变阶段*")
            $b = ($readme -like "*性转参数*" -or $readme -like "*性别转变阶段*" -or $readme -like "*人物状态*")
            $c = ($idx15 -like "*性转参数*" -or $idx15 -like "*性别转变阶段*" -or $idx15 -like "*人物状态*")
            $ok = ($a -and $b -and $c)
        }
        # 已删除合并：INDEX 声明占位目录并入（原 references/gender-transition/ 与 .review-db/gender-transition/ 子目录）
        "已删除合并" {
            $ok = ($idx15 -like "*已删除合并*" -and $skill -like "*gender-transition/*")
        }
    }
    if (-not $ok) { $missNative += $k }
}
Check "T15g" "Trae Skill 原生兼容（占位目录删除有声明 + 触发词追加既有词典 + 上下文继承性转参数）三文档一致" ($missNative.Count -eq 0) $(if ($missNative) { "缺失: $($missNative -join ',')" } else { "$(@($nativeKeys).Count)/$(@($nativeKeys).Count) 要点" })

# T15h 灰度与兜底：默认建议级 / 数据物理隔离 / 模块级回退清单 + 只提建议铁则
$safeguardKeys = @("建议级", "问题级", "隔离", "模块级回退", "只提建议")
$missSafe = @()
foreach ($k in $safeguardKeys) {
    $a = ($skill -like "*$k*")
    $b = ($idx15 -like "*$k*")
    $c = ($gt15 -like "*$k*")
    $d = ($readme -like "*$k*")
    $ok = ($a -and $b -and $c -and $d)
    if (-not $ok) { $missSafe += $k }
}
Check "T15h" "灰度与兜底兼容（建议级默认→稳定升问题级 / 数据物理隔离 / 模块级回退清单 + 只提建议铁则）四文档一致" ($missSafe.Count -eq 0) $(if ($missSafe) { "缺失: $($missSafe -join ',')" } else { "$(@($safeguardKeys).Count)/$(@($safeguardKeys).Count) 要点" })

# T15i README 测试套件历史总数 57 项声明保留（与 T15/T16 系列覆盖范围一致）
$readmeCountOk = ($readme -like "*57 项单元+集成测试*" -and $readme -like "*T15 系列：分层路由*" -and $readme -like "*T16 系列*")
Check "T15i" "README 测试套件历史总数声明（57 项）与 T15/T16 系列覆盖范围一致" $readmeCountOk $(if ($readmeCountOk) { "57 项历史声明就位，T15/T16 范围描述齐全" } else { "声明缺失或范围不匹配" })

# ── T16 v3.4.0 伏笔追踪专项接线（版本统一 / 判定-冲突-分题材三规则包 / 触发与深度三档 / index.json 台账 / 附录输出 / INDEX 联动 / 灰度兜底 / README 登记）──
$fj16  = Read-Text "references\rules-pack\foreshadow-judgment-rules.md"
$fc16  = Read-Text "references\rules-pack\foreshadow-conflict-rules.md"
$ft16  = Read-Text "references\rules-pack\foreshadow-topic-templates.md"
$vdb16 = Read-Text "references\review-vector-db.md"
$sty16 = Read-Text "references\style-memory-db.md"

# T16a v3.4.0 版本号历史保留（SKILL description / README 历史更新章节 / INDEX 概述 / 三伏笔规则包 保留 v3.4.0 声明）
$t16a = ($skill -like "*v3.4.0*伏笔追踪*" -and $readme -like "*历史更新（v3.4.0*" -and $idx15 -like "*v3.4.0*伏笔追踪*" -and $fj16 -like "*v3.4.0*" -and $fc16 -like "*v3.4.0*" -and $ft16 -like "*v3.4.0*")
Check "T16a" "v3.4.0 版本历史保留（SKILL description / README 历史更新章节 / INDEX 概述 / 判定-冲突-模板三规则包 六处声明v3.4.0）" $t16a $(if ($t16a) { "6/6 历史声明保留" } else { "SKILL_desc=$($skill -like '*v3.4.0*伏笔追踪*') README_history=$($readme -like '*历史更新（v3.4.0*') INDEX=$($idx15 -like '*v3.4.0*伏笔追踪*') FJ=$($fj16 -like '*v3.4.0*') FC=$($fc16 -like '*v3.4.0*') FT=$($ft16 -like '*v3.4.0*')" })

# T16b 判定标准：六大类 27 小类 + 生命周期状态机 + index.json 台账字段 + 埋设强度伪装度 + 深度三档
$fjKps = @("六大类", "27 小类", "实体类", "人物类", "力量体系类", "剧情长线类", "隐性弱埋线", "F1", "F27",
           "planted", "reinforced", "closed", "overdue", "broken", "生命周期", "状态机",
           "index.json", "编号", "优先级", "锚点", "计划回收章",
           "明示", "暗示", "伪装度", "文风自然度", "quick", "full", "precise", "foreshadow_base")
$missFj = @($fjKps | Where-Object { $fj16 -notlike "*$_*" })
Check "T16b" "foreshadow-judgment-rules 六大类27小类+生命周期状态机+index.json台账字段+埋设强度伪装度+深度三档+精度对比齐全" ($missFj.Count -eq 0) $(if ($missFj) { "缺失: $($missFj -join ',')" } else { "$(@($fjKps).Count)/$(@($fjKps).Count) 要点" })

# T16c 冲突校验：四类冲突（联动 C1-C3/B1-B3/D2）+ 回收节奏 + 遗忘预警阈值 + index.json 状态机承载 + 精度对比
$fcKps = @("设定冲突", "人物冲突", "时间线冲突", "剧情自洽", "C3", "B2", "B1", "D2",
           "5-15 章", "30-60 章", "150 章", "遗忘预警", "30 章", "60 章", "膨胀", "倒查",
           "吃书", "知识边界", "index.json", "状态机", "精度对比")
$missFc = @($fcKps | Where-Object { $fc16 -notlike "*$_*" })
Check "T16c" "foreshadow-conflict-rules 四类冲突校验(联动C1-C3/B1-B3/D2)+回收节奏+遗忘预警阈值+index.json状态机承载+精度对比齐全" ($missFc.Count -eq 0) $(if ($missFc) { "缺失: $($missFc -join ',')" } else { "$(@($fcKps).Count)/$(@($fcKps).Count) 要点" })

# T16d 分题材模板：题材速查表（12 行）+ 分题材伏笔类型 + 跨题材五雷区 + 大纲联动 + 叠加顺序
$ftKps = @("系统文", "变嫁", "末世", "仙侠", "商战", "悬疑", "快穿", "古言", "娱乐圈", "职场",
           "任务伏笔", "奖励伏笔", "身份伏笔", "情感伏笔", "秘密伏笔", "战力伏笔", "势力伏笔", "人脉伏笔", "信息差", "布局",
           "三层真相", "空降伏笔", "伏笔坟场", "回收倾销", "伪伏笔", "重复埋设",
           "大纲", "速查表", "叠加顺序")
$missFt = @($ftKps | Where-Object { $ft16 -notlike "*$_*" })
Check "T16d" "foreshadow-topic-templates 题材速查表12行+分题材伏笔类型+跨题材五雷区+大纲联动+叠加顺序齐全" ($missFt.Count -eq 0) $(if ($missFt) { "缺失: $($missFt -join ',')" } else { "$(@($ftKps).Count)/$(@($ftKps).Count) 要点" })

# T16e SKILL.md 伏笔专项全接线（复用机制 / index.json 台账 / 深度三档 / 触发词 / 开关 / 前缀输出 / 专项通用铁律）
$v340skill = [ordered]@{
    "专项复用机制章节" = ($skill -like "*伏笔追踪专项复用机制*")
    "三规则包引用"     = ($skill -like "*foreshadow-judgment-rules*" -and $skill -like "*foreshadow-conflict-rules*" -and $skill -like "*foreshadow-topic-templates*")
    "台账持久化"       = ($skill -like "*foreshadow/index.json*" -and $skill -like "*.review-db/foreshadow/*")
    "唯一台账声明"     = ($skill -like "*唯一台账*")
    "深度三档映射"     = ($skill -like "*深度三档*" -and $skill -like "*quick*" -and $skill -like "*full*" -and $skill -like "*precise*")
    "触发词三类"       = ($skill -like "*埋线*" -and $skill -like "*挖坑*" -and $skill -like "*剧情吃书*" -and $skill -like "*前后矛盾*" -and $skill -like "*线索遗漏*")
    "自动叠加场景"     = ($skill -like "*自动叠加*")
    "手动开关"         = ($skill -like "*启用伏笔专项深度审查*" -and $skill -like "*禁用伏笔专项，按通用标准审*")
    "伏笔前缀输出"     = ($skill -like "*【伏笔】*" -and $skill -like "*【伏笔预警】*")
    "精度对比可选"     = ($skill -like "*foreshadow_base*")
    "专项通用铁律"     = ($skill -like "*专项通用铁律*")
}
$bad340 = @($v340skill.Keys | Where-Object { -not $v340skill[$_] })
Check "T16e" "SKILL.md v3.4.0 伏笔专项全接线（复用机制/index.json台账+唯一台账/深度三档/触发词/开关/伏笔前缀/专项通用铁律）" ($bad340.Count -eq 0) $(if ($bad340) { "未接线: $($bad340 -join ',')" } else { "$(@($v340skill).Count)/$(@($v340skill).Count) 接线点" })

# T16f 台账持久化 + 向量库 / 文风库联动接线（v3.7.0 起 5 类特征向量临时提取）
$v340db = [ordered]@{
    "向量库伏笔子目录" = ($vdb16 -like "*foreshadow*" -and $vdb16 -like "*index.json*")
    "台账文件"         = ($vdb16 -like "*index.json*" -and $vdb16 -like "*details/*")
    "5类特征向量"      = ($vdb16 -like "*5 类特征向量*" -or ($vdb16 -like "*伏笔特征*" -and $vdb16 -like "*临时提取*"))
    "物理隔离"         = ($vdb16 -like "*物理隔离*")
    "文风自然度校验"   = ($sty16 -like "*伏笔自然度校验*" -and $sty16 -like "*伪装度*")
    "明示密度阈值"     = ($sty16 -like "*2 处/千字*" -or $sty16 -like "*2处/千字*")
}
$bad340db = @($v340db.Keys | Where-Object { -not $v340db[$_] })
Check "T16f" "台账持久化与底层库联动（.review-db/foreshadow index.json+details / 5类特征向量临时提取 / style 库伏笔自然度校验+明示密度阈值）接线" ($bad340db.Count -eq 0) $(if ($bad340db) { "未接线: $($bad340db -join ',')" } else { "$(@($v340db).Count)/$(@($v340db).Count) 接线点" })

# T16g 报告模板伏笔附录 + 输出降级规则
$rtFKps = @("伏笔追踪专项附录", "伏笔追踪专项结论", "本章新增预埋", "全局未回收", "逻辑冲突", "原生系统精度对比", "全书伏笔追踪表", "【伏笔】", "【伏笔预警】", "foreshadow_base", "降级")
$missRtF = @($rtFKps | Where-Object { $rt -notlike "*$_*" })
Check "T16g" "report-template 伏笔追踪专项附录（预埋/未回收/冲突/精度对比/追踪表 五子段）+【伏笔】前缀+【伏笔预警】+降级规则齐全" ($missRtF.Count -eq 0) $(if ($missRtF) { "缺失: $($missRtF -join ',')" } else { "$(@($rtFKps).Count)/$(@($rtFKps).Count) 要点" })

# T16h INDEX 登记联动 + SKILL 灰度兜底（通用优先/不重复/建议级/模块级回退/可选依赖/任意叠加）
$idxFKps = @("foreshadow-judgment-rules.md", "foreshadow-conflict-rules.md", "foreshadow-topic-templates.md", "伏笔追踪专项", "同源", "冲突处理", "自动叠加", "precise", "foreshadow_base", "建议级", "只提建议", "模块级回退", "不重复")
$missIdxF = @($idxFKps | Where-Object { $idx15 -notlike "*$_*" })
$skillSafe340 = @("建议级", "模块级回退清单", "物理隔离", "foreshadow_base", "任意叠加")
$missSkillSafe = @($skillSafe340 | Where-Object { $skill -notlike "*$_*" })
Check "T16h" "INDEX 伏笔三包登记+联动条款（同源/冲突处理/自动叠加/precise/建议级/只提建议/模块级回退/不重复）与 SKILL 灰度兜底（建议级/回退清单/物理隔离/可选依赖/任意叠加）齐备" (($missIdxF.Count -eq 0) -and ($missSkillSafe.Count -eq 0)) $(if ($missIdxF -or $missSkillSafe) { "INDEX 缺失: $($missIdxF -join ', ')；SKILL 缺失: $($missSkillSafe -join ', ')" } else { "INDEX $(@($idxFKps).Count)/$(@($idxFKps).Count) + SKILL $($skillSafe340.Count)/$($skillSafe340.Count) 要点" })

# T16i README v3.4.0 伏笔追踪专项历史保留（历史更新章节/版本记录/功能特性/触发词/模式/目录/.review-db）
$readmeFKps = @("历史更新（v3.4.0", "v3.4.0", "伏笔追踪", "伏笔追踪专项", "foreshadow_table", "五大类 22 小类", "遗忘预警", "深度三档", "foreshadow_base", "65 项单元+集成测试", "T16 系列")
$missRdF = @($readmeFKps | Where-Object { $readme -notlike "*$_*" })
Check "T16i" "README v3.4.0 伏笔追踪专项历史保留（历史更新章节/版本记录/功能特性/触发词/审稿模式/调度映射/目录结构/.review-db/测试65项+T16范围）齐全" ($missRdF.Count -eq 0) $(if ($missRdF) { "缺失: $($missRdF -join ',')" } else { "$(@($readmeFKps).Count)/$(@($readmeFKps).Count) 要点" })

# ── T18 v3.5.0 数据路径架构重构接线（v3.9.0 起 frontmatter/badge/测试头顺延为 3.9.0，v3.5.0 功能与历史声明保留；目录树/指令集/附录骨架按 v3.7~v3.9 现状校验）──
# T18a 版本链路统一（当前版本 SKILL frontmatter 3.9.0 + run_tests 头 3.9.0 + README badge 3.9.0；v3.5.0 数据路径功能与历史声明保留）
$t18a = ($skill -like "*version: 3.9.0*" -and $skill -like "*v3.5.0*" -and $skill -like "*前置强制执行：数据路径约定*" -and
         $readme -like "*version-3.9.0*" -and $readme -like "*v3.5.0*数据路径*" -and
         $idx15 -like "*v3.5.0*数据路径*" -and
         (Get-Content $PSCommandPath -Raw -Encoding UTF8) -like "*v3.9.0 测试套件*")
Check "T18a" "版本链路统一（SKILL frontmatter=3.9.0 / README badge=3.9.0 / run_tests 头=3.9.0；v3.5.0 数据路径功能与历史声明五处保留）" $t18a $(if ($t18a) { "当前版本 3.9.0 + v3.5.0 历史保留，链路一致" } else { "SKILL_ver=$($skill -like '*version: 3.9.0*') SKILL_v35=$($skill -like '*v3.5.0*') SKILL_path=$($skill -like '*前置强制执行：数据路径约定*') README_badge=$($readme -like '*version-3.9.0*') README_v35hist=$($readme -like '*v3.5.0*数据路径*') INDEX=$($idx15 -like '*v3.5.0*数据路径*') Tests=$((Get-Content $PSCommandPath -Raw -Encoding UTF8) -like '*v3.9.0 测试套件*')" })

# T18b SKILL 前置约定章节存在且包含四条约定关键句 + v3.9.0 标准目录树九项
$pathKeys = @("前置强制执行：数据路径约定", "全局资源目录", "references/", "项目专属数据库", ".review-db/", "路径基准", "自动初始化", "meta.json", "setting.md", "project_state.json", "entity_index.json", "characters/", "keyword_index.json", "story_summaries.json", "foreshadow/", "style_fingerprint.json")
$missPath = @($pathKeys | Where-Object { $skill -notlike "*$_*" })
Check "T18b" "SKILL 前置约定章节存在且包含四条约定（全局/项目/路径基准/自动初始化）+ v3.9.0 标准目录树九项（meta/setting/project_state/四大索引/foreshadow/style_fingerprint）" ($missPath.Count -eq 0) $(if ($missPath) { "缺失: $($missPath -join ',')" } else { "$(@($pathKeys).Count)/$(@($pathKeys).Count) 要点" })

# T18c SKILL 按需加载三步流程 Step 0/1/2 + 模块映射（project_state 字段式）+ 增量写入规则
$loadKeys = @("数据加载执行流程", "严格控 token", "Step 0", "启动预检", "meta.json", "<100 token", "Step 1", "模块级按需加载", "Step 2", "深度详情按需读取", "基础审稿", "setting.md", "project_state.json", "system_state", "gender_state", "foreshadow/index.json", "增量写入", "禁止全量重写")
$missLoad = @($loadKeys | Where-Object { $skill -notlike "*$_*" })
Check "T18c" "SKILL 按需加载三步流程（Step 0启动预检<100token / Step 1模块级按需 / Step 2深度详情单条）+ project_state 字段映射 + 增量写入规则齐全" ($missLoad.Count -eq 0) $(if ($missLoad) { "缺失: $($missLoad -join ',')" } else { "$(@($loadKeys).Count)/$(@($loadKeys).Count) 要点" })

# T18d SKILL 手动指令集章节（六、）+ 八条指令表格 + 意图词典追加
$cmdKeys = @("六、手动控制指令集", "/init-review", "/full-load", "/light-mode", "/sync-setting", "/sync-outline", "/force-archive", "/archive-closed", "/export-foreshadow", "标准级更新", "全量级更新", "强制归档")
$missCmds = @($cmdKeys | Where-Object { $skill -notlike "*$_*" })
Check "T18d" "SKILL 手动指令集章节（六、）+ 八条指令表格（/init-review /full-load /light-mode /sync-setting /sync-outline /force-archive /archive-closed /export-foreshadow）+ 附录词典追加" ($missCmds.Count -eq 0) $(if ($missCmds) { "缺失: $($missCmds -join ',')" } else { "$(@($cmdKeys).Count)/$(@($cmdKeys).Count) 要点" })

# T18e SKILL 统一输出格式骨架 + report-template 详细附录 + 降级规则（v3.8.0 起详细模板外移 report-template.md）
$outputKeys = @("【专项审查附录】", "命中时显示", "转变节奏", "心理逻辑", "行为细节", "核心人设一致性", "本章新增预埋", "全局未回收", "逻辑冲突")
$missOut = @($outputKeys | Where-Object { $skill -notlike "*$_*" })
$rtAppendix = ($rt -like "*【专项审查附录】*" -and $rt -like "*伏笔追踪专项*" -and $rt -like "*降级*")
Check "T18e" "SKILL 统一输出格式骨架（【专项审查附录】+四子段）+ report-template 详细附录与降级规则" (($missOut.Count -eq 0) -and $rtAppendix) $(if ($missOut) { "SKILL 缺失: $($missOut -join ',')" } elseif (-not $rtAppendix) { "report-template 附录/降级缺失" } else { "SKILL $(@($outputKeys).Count)/$(@($outputKeys).Count) + RT 附录降级就位" })

# T18f SKILL 全局资源索引章节（七、）+ references/ 文件清单 + 按需读取
$resKeys = @("七、全局资源索引", "references/", "rules-pack/", "templates/", "memory-index.md", "genre-classifier.md", "genre-matrix.md", "review-vector-db.md", "style-memory-db.md", "按需读取")
$missRes = @($resKeys | Where-Object { $skill -notlike "*$_*" })
Check "T18f" "SKILL 全局资源索引章节（七、）+ references/ 文件清单（记忆分类/数据库规范/rules-pack/templates）+ 按需读取" ($missRes.Count -eq 0) $(if ($missRes) { "缺失: $($missRes -join ',')" } else { "$(@($resKeys).Count)/$(@($resKeys).Count) 要点" })

# T18g INDEX / README 同步（v3.9.0 README 最新更新章节，v3.5.0 数据路径内容在版本记录与 INDEX 中保留）
$syncOk = ($idx15 -like "*v3.5.0*数据路径*" -and $idx15 -like "*按需加载*" -and
           $readme -like "*## 📌 最新更新（v3.9.0*" -and
           $readme -like "*| **v3.5.0** | **2026-09-03** |*" -and
           $readme -like "*数据路径*")
Check "T18g" "INDEX v3.5.0 数据路径重构声明保留 + README 最新更新章节为 v3.9.0 + 版本记录表 v3.5.0 条目保留" $syncOk $(if ($syncOk) { "INDEX/README 同步到位（最新更新=v3.9.0，v3.5.0 历史保留）" } else { "INDEX_v350=$($idx15 -like '*v3.5.0*数据路径*') INDEX_load=$($idx15 -like '*按需加载*') README_update=$($readme -like '*## 📌 最新更新（v3.9.0*') README_v35record=$($readme -like '*| **v3.5.0** | **2026-09-03** |*') README_datapath=$($readme -like '*数据路径*')" })

# T18h README 测试套件总数声明（v3.9.0 起 85 项）与实际数量一致
$actualCheckCount = (Get-Content $PSCommandPath -Raw -Encoding UTF8 | Select-String -Pattern 'Check "T\d+' -AllMatches).Matches.Count
$readmeCountOk = ($readme -like "*85 项单元+集成测试*" -and $actualCheckCount -eq 85)
Check "T18h" "README 测试套件总数声明（85 项）与实际数量一致" $readmeCountOk $(if ($readmeCountOk) { "README 声明 85 项，实际 $actualCheckCount 项，一致" } else { "README 声明 vs 实际数量不匹配（README 期望 85，实际 $actualCheckCount）" })

# ── T19 v3.6.0 公路求生·克苏鲁向题材适配接线（v3.9.0 起版本链路顺延，v3.6.0 历史声明保留，台账载体按 index.json 校验）──
$cl19  = Read-Text "references\rules-pack\character-logic-rules.md"
$gc19  = Read-Text "references\genre-classifier.md"

# T19a 版本号全链路统一（SKILL frontmatter=3.9.0 + v3.6.0 公路适配历史 / README badge=3.9.0 + 最新更新 v3.9.0 + 版本记录 v3.6.0 / INDEX 概述 / system-novel 头 / run_tests 头）
$t19a = ($skill -like "*version: 3.9.0*" -and $skill -like "*v3.6.0 公路求生·克苏鲁向题材适配说明*" -and
         $readme -like "*version-3.9.0*" -and $readme -like "*## 📌 最新更新（v3.9.0*" -and $readme -like "*| **v3.6.0** | **2026-09-04** |*" -and
         $idx15 -like "*v3.6.0*公路求生*" -and $sy -like "*v3.6.0*" -and
         (Get-Content $PSCommandPath -Raw -Encoding UTF8) -like "*v3.9.0 测试套件*")
Check "T19a" "v3.6.0 历史声明保留 + v3.9.0 版本链路统一（SKILL frontmatter 3.9.0+适配说明 / README badge 3.9.0+最新更新+版本记录 / INDEX / system-novel 头 / run_tests 头）" $t19a $(if ($t19a) { "7/7 声明到位" } else { "SKILL_ver=$($skill -like '*version: 3.9.0*') SKILL_desc=$($skill -like '*v3.6.0 公路求生·克苏鲁向题材适配说明*') README_badge=$($readme -like '*version-3.9.0*') README_update=$($readme -like '*## 📌 最新更新（v3.9.0*') README_record=$($readme -like '*| **v3.6.0** | **2026-09-04** |*') INDEX=$($idx15 -like '*v3.6.0*公路求生*') SY=$($sy -like '*v3.6.0*') Tests=$((Get-Content $PSCommandPath -Raw -Encoding UTF8) -like '*v3.9.0 测试套件*')" })

# T19b system-novel-rules #21 公路求生·克苏鲁向赛道模板（六维标准 + 崩盘点 + 校验清单 + 三重叠加 + 计数 21 类）
$syRoad = @("21 类", "21. 公路求生", "公路求生·克苏鲁向", "载具核心机制", "公路节点与推进节奏", "资源消耗体系",
            "SAN 值与认知污染机制", "公路诡异规则体系", "任务与奖励机制", "三重叠加", "禁止凭空修复", "3:1",
            "移动性丧失", "补给 + 危险 + 线索", "禁止无限补给", "掉得快恢复得更快")
$missSyRoad = @($syRoad | Where-Object { $sy -notlike "*$_*" })
Check "T19b" "system-novel-rules #21 公路求生·克苏鲁向赛道模板（六维标准/六大崩盘点/校验清单/三重叠加/21类计数）齐全" ($missSyRoad.Count -eq 0) $(if ($missSyRoad) { "缺失: $($missSyRoad -join ',')" } else { "$(@($syRoad).Count)/$(@($syRoad).Count) 要点" })

# T19c foreshadow-judgment 第六大类 F23-F27（标识/载具/道路/节点/规则 + 计数六大类27小类 + 公路题材高精度门控）
$fjRoad = @("六大类", "27 小类", "公路场景专属伏笔", "F23", "F24", "F25", "F26", "F27",
            "标识类", "载具类", "道路类", "节点类", "规则类", "收音机", "里程标", "循环", "命中公路求生题材")
$missFjRoad = @($fjRoad | Where-Object { $fj16 -notlike "*$_*" })
Check "T19c" "foreshadow-judgment 第六大类 F23-F27（标识/载具/道路/节点/规则 五小类 + 六大类27小类计数 + 公路题材高精度门控）齐全" ($missFjRoad.Count -eq 0) $(if ($missFjRoad) { "缺失: $($missFjRoad -join ',')" } else { "$(@($fjRoad).Count)/$(@($fjRoad).Count) 要点" })

# T19d foreshadow-topic-templates 公路题材速查行 + §二.6 专项细则（短中长三线 + 伪规则判 C3 + SAN 接触史互证 + 双专项联动）
$ftRoad = @("公路求生·克苏鲁向（v3.6.0）", "F23-F27", "节点遗留物", "规则伏笔", "循环类空间伏笔",
            "伪规则", "判 C3", "接触史", "与系统文专项联动", "与 SAN 行为校验联动", "12 类题材")
$missFtRoad = @($ftRoad | Where-Object { $ft16 -notlike "*$_*" })
Check "T19d" "foreshadow-topic-templates 公路题材速查行 + §二.6 专项细则（F23-F27 短中长三线/伪规则判C3/SAN接触史/双专项联动/12类计数）齐全" ($missFtRoad.Count -eq 0) $(if ($missFtRoad) { "缺失: $($missFtRoad -join ',')" } else { "$(@($ftRoad).Count)/$(@($ftRoad).Count) 要点" })

# T19e character-logic §1.6 公路节点节奏模型 + §2.6 SAN 值四级污染行为校验
$clRoad = @("公路节点节奏模型", "小型节点", "中型节点", "大型节点", "3:1", "25~35 章",
            "过密预警", "过疏预警", "失衡预警", "移动性丧失预警", "风险 + 收益 + 线索",
            "SAN 值状态行为校验", "轻度污染", "中度污染", "重度污染", "失控同化",
            "不判定 OOC", "诱因", "秒回满", "数值穿帮", "底色")
$missClRoad = @($clRoad | Where-Object { $cl19 -notlike "*$_*" })
Check "T19e" "character-logic §1.6 公路节点节奏模型（三级节点/3:1配比/四预警/三要素）+ §2.6 SAN 四级污染行为校验（分级豁免/诱因/恢复/底色/穿帮红线）齐全" ($missClRoad.Count -eq 0) $(if ($missClRoad) { "缺失: $($missClRoad -join ',')" } else { "$(@($clRoad).Count)/$(@($clRoad).Count) 要点" })

# T19f SKILL.md 全链路接线（公路适配说明+零侵入 / 意图词典公路类触发词 / 三重叠加调度 / 21类+六大类27小类+F23-F27+§1.6+§2.6 引用 / 正文与大纲双路由）
$skillRoad = [ordered]@{
    "公路适配说明"     = ($skill -like "*公路求生·克苏鲁向题材适配说明*" -and $skill -like "*零侵入*")
    "意图词典公路类"   = ($skill -like "*公路求生·克苏鲁向类*" -and $skill -like "*公路求生*" -and $skill -like "*行车规则*" -and $skill -like "*载具求生*")
    "元素触发词"       = ($skill -like "*SAN 值*" -and $skill -like "*收音机怪谈*" -and $skill -like "*路牌诡异*" -and $skill -like "*服务区事件*" -and $skill -like "*隧道异常*")
    "三重叠加调度"     = ($skill -like "*三重叠加*")
    "21类赛道引用"     = ($skill -like "*21 类赛道模板*" -or $skill -like "*21 类类型模板库*" -or $skill -like "*21类赛道*" -or $skill -like "*21 类*")
    "六大类27小类引用" = ($skill -like "*六大类 27 小类*")
    "F23-F27引用"      = ($skill -like "*F23-F27*")
    "节奏与SAN引用"    = ($skill -like "*§1.6*" -and $skill -like "*§2.6*" -and $skill -like "*公路节点节奏*")
    "正文大纲双路由"   = ($skill -like "*system-novel-rules #21*" -and $skill -like "*公路求生·克苏鲁向要素*")
    "资源索引同步"     = ($skill -like "*公路场景专属*" -and $skill -like "*SAN 值四级污染*")
}
$badSkillRoad = @($skillRoad.Keys | Where-Object { -not $skillRoad[$_] })
Check "T19f" "SKILL.md v3.6.0 全链路接线（公路适配说明+零侵入/意图词典公路类+元素词/三重叠加/计数引用/F23-F27/§1.6§2.6/双路由/资源索引）" ($badSkillRoad.Count -eq 0) $(if ($badSkillRoad) { "未接线: $($badSkillRoad -join ',')" } else { "$(@($skillRoad).Count)/$(@($skillRoad).Count) 接线点" })

# T19g INDEX 同步登记（v3.6.0 概述 / 21类 / 六大类27小类 / F23-F27 / 12类题材 / 第21条调度条款 / §1.6§2.6 引用）
$idxRoad = @("v3.6.0", "21 类", "六大类 27 小类", "F23-F27", "12 类题材",
             "公路求生·克苏鲁向专项调度", "§1.6", "§2.6", "三重叠加", "移动性丧失")
$missIdxRoad = @($idxRoad | Where-Object { $idx15 -notlike "*$_*" })
Check "T19g" "rules-pack/INDEX v3.6.0 同步登记（概述/三包计数/F23-F27/第21条调度条款/§1.6§2.6/三重叠加/移动性丧失判罚点）齐全" ($missIdxRoad.Count -eq 0) $(if ($missIdxRoad) { "缺失: $($missIdxRoad -join ',')" } else { "$(@($idxRoad).Count)/$(@($idxRoad).Count) 要点" })

# T19h genre-classifier 题材信号+映射 / review-vector-db 台账计数+特征向量临时提取 / gender-transition 交叉引用 三文件联动
$crossRoad = [ordered]@{
    "classifier信号行" = ($gc19 -like "*公路求生·克苏鲁向（v3.6.0）*" -and $gc19 -like "*SAN 值/理智值面板*" -and $gc19 -like "*行车规则*")
    "classifier映射行" = ($gc19 -like "*#21 赛道模板*" -and $gc19 -like "*F23-F27*" -and $gc19 -like "*§1.6*" -and $gc19 -like "*cosmic_horror*")
    "vector台账计数"   = ($vdb16 -like "*六大类 27 小类*" -and $vdb16 -like "*F1-F27*" -and $vdb16 -like "*公路场景专属 F23-F27*")
    "vector特征向量"   = ($vdb16 -like "*5 类特征向量*" -and $vdb16 -like "*临时提取*")
    "gt交叉引用"       = ($gt15 -like "*21 类赛道模板*")
}
$badCrossRoad = @($crossRoad.Keys | Where-Object { -not $crossRoad[$_] })
Check "T19h" "genre-classifier（信号行+映射行）/ review-vector-db（台账六大类27小类+5类特征向量临时提取）/ gender-transition（21类交叉引用）三文件联动" ($badCrossRoad.Count -eq 0) $(if ($badCrossRoad) { "未联动: $($badCrossRoad -join ',')" } else { "$(@($crossRoad).Count)/$(@($crossRoad).Count) 联动点" })

# T19i 零侵入门控与灰度回退（§1.6/§2.6/F23-F27 适用范围门控 + SKILL/INDEX 未命中休眠输出一致 + 模块级回退 + 只提建议）
$gateRoad = [ordered]@{
    "节奏门控"   = ($cl19 -like "*仅激活于公路求生*")
    "SAN门控"    = ($cl19 -like "*仅激活于含克苏鲁*")
    "伏笔门控"   = ($fj16 -like "*命中公路求生题材*")
    "SKILL休眠"  = ($skill -like "*未命中时规则休眠*" -and $skill -like "*输出与 v3.5.0*完全一致*")
    "INDEX休眠"  = ($idx15 -like "*未命中公路/克苏鲁要素时本节全部规则不激活*")
    "模块级回退" = ($skill -like "*模块级回退*")
    "只提建议"   = ($skill -like "*只提建议*")
}
$badGateRoad = @($gateRoad.Keys | Where-Object { -not $gateRoad[$_] })
Check "T19i" "零侵入门控与灰度回退（§1.6/§2.6/F23-F27 适用范围门控 + SKILL/INDEX 未命中休眠且输出与 v3.5.0 一致 + 模块级回退 + 只提建议）" ($badGateRoad.Count -eq 0) $(if ($badGateRoad) { "缺失: $($badGateRoad -join ',')" } else { "$(@($gateRoad).Count)/$(@($gateRoad).Count) 门控点" })

# T19j README v3.6.0 登记（历史更新章节 + 版本记录 + 功能特性 21类/F23-F27/六大类27小类/SAN/节点节奏 + 测试声明+T19范围）
$readmeRoad = @("v3.6.0", "公路求生", "21 类赛道", "F23-F27", "六大类", "27 小类",
                "SAN", "公路节点节奏", "75 项单元+集成测试", "T19 系列")
$missReadmeRoad = @($readmeRoad | Where-Object { $readme -notlike "*$_*" })
Check "T19j" "README v3.6.0 公路求生·克苏鲁向适配登记（历史更新/版本记录/功能特性/测试75项+T19范围）齐全" ($missReadmeRoad.Count -eq 0) $(if ($missReadmeRoad) { "缺失: $($missReadmeRoad -join ',')" } else { "$(@($readmeRoad).Count)/$(@($readmeRoad).Count) 要点" })

# ── T20 v3.7/v3.8/v3.9 记忆架构接线 ──
$mi20  = Read-Text "references\memory-index.md"
$sty20 = Read-Text "references\style-memory-db.md"
$rf20  = Read-Text "references\templates\shared\prompts\review_flow.md"

# T20a v3.9.0 版本号全链路统一（SKILL / README / INDEX / review-vector-db / genre-classifier / memory-index / run_tests 头）
$testsRaw = Get-Content $PSCommandPath -Raw -Encoding UTF8
$t20a = ($skill -like "*version: 3.9.0*" -and
         ($skill -like "*v3.9.0*" -and $skill -like "*轻量记忆索引*") -and
         $readme -like "*version-3.9.0*" -and
         $readme -like "*| **v3.9.0** | **2026-09-05** |*" -and
         $idx15 -like "*v3.9.0*" -and
         $vdb16 -like "*v3.9.0*" -and
         $gc19 -like "*v3.9.0*" -and
         $mi20 -like "*v3.9.0*" -and
         $testsRaw -like "*v3.9.0 测试套件*")
Check "T20a" "v3.9.0 版本号全链路统一（SKILL frontmatter+description / README badge+版本记录 / INDEX / review-vector-db / genre-classifier / memory-index / run_tests 头 八处声明）" $t20a $(if ($t20a) { "8/8 声明到位" } else { "SKILL=$($skill -like '*version: 3.9.0*') SKILL_desc=$($skill -like '*轻量记忆索引*') README_badge=$($readme -like '*version-3.9.0*') README_record=$($readme -like '*| **v3.9.0** | **2026-09-05** |*') INDEX=$($idx15 -like '*v3.9.0*') VDB=$($vdb16 -like '*v3.9.0*') GC=$($gc19 -like '*v3.9.0*') MI=$($mi20 -like '*v3.9.0*') Tests=$($testsRaw -like '*v3.9.0 测试套件*')" })

# T20b 轻量记忆索引四件套接线（SKILL 目录树+说明 / review-vector-db 登记 / README 表格 / report-template 索引层比对）
$indexFiles = @("entity_index.json", "characters/", "keyword_index.json", "story_summaries.json")
$indexFuncs = @("实体注册表", "分层人物库", "倒排索引", "滚动摘要")
$missIdxSkill = @($indexFiles | Where-Object { $skill -notlike "*$_*" })
$missIdxVdb   = @($indexFiles | Where-Object { $vdb16 -notlike "*$_*" }) + @($indexFuncs | Where-Object { $vdb16 -notlike "*$_*" })
$missIdxRt    = @("entity_index", "story_summaries") | Where-Object { $rt -notlike "*$_*" }
$t20b = ($missIdxSkill.Count -eq 0 -and $missIdxVdb.Count -eq 0 -and $missIdxRt.Count -eq 0)
Check "T20b" "轻量记忆索引四件套接线（SKILL 目录树+加载说明 / review-vector-db 登记四索引+功能 / report-template 索引层比对）" $t20b $(if (-not $t20b) { "SKILL 缺: $($missIdxSkill -join ',')；VDB 缺: $($missIdxVdb -join ',')；RT 缺: $($missIdxRt -join ',')" } else { "SKILL 4/4 + VDB 8/8 + RT 比对就位" })

# T20c 三级更新分级机制（轻量级默认 / 标准级 /sync-setting / 全量级 /sync-outline + 绝对不碰 + 索引维护）
$t20cKeys = @("更新分级原则", "轻量级（默认）", "标准级", "全量级", "绝对不碰", "轻量索引维护", "增量追加", "无明确指令")
$missT20c = @($t20cKeys | Where-Object { $skill -notlike "*$_*" })
Check "T20c" "三级更新分级机制（轻量级默认/标准级 /sync-setting/全量级 /sync-outline + 绝对不碰清单 + 轻量索引维护增量追加 + 无明确指令不碰大纲）" ($missT20c.Count -eq 0) $(if ($missT20c) { "缺失: $($missT20c -join ',')" } else { "$(@($t20cKeys).Count)/$(@($t20cKeys).Count) 要点" })

# T20d 8 指令指令集（v3.5 五条 + v3.7 新增三条 + 词典追加 + 默认更新原则）
$t20dKeys = @("/init-review", "/full-load", "/light-mode", "/sync-setting", "/sync-outline", "/force-archive", "/archive-closed", "/export-foreshadow",
              "同步更新设定", "同步更新章纲", "默认更新原则")
$missT20d = @($t20dKeys | Where-Object { $skill -notlike "*$_*" })
Check "T20d" "手动控制指令集 8 指令（v3.5 五条 + v3.7 新增 /sync-setting /sync-outline /force-archive）+ 意图词典追加 + 默认更新原则" ($missT20d.Count -eq 0) $(if ($missT20d) { "缺失: $($missT20d -join ',')" } else { "8/8 指令 + 词典 + 原则" })

# T20e 题材缓存路由（SKILL 第2步缓存快速路由 / genre-classifier §〇 / vdb meta.json cached_genre / 漂移兜底）
$t20eSkill = @("缓存快速路由", "cached_genre")
$missT20eS = @($t20eSkill | Where-Object { $skill -notlike "*$_*" })
$t20eGc = @("题材缓存快速路由", "cached_genre", "强信号", "漂移")
$missT20eG = @($t20eGc | Where-Object { $gc19 -notlike "*$_*" })
$t20eVdb = ($vdb16 -like "*cached_genre*")
Check "T20e" "题材缓存路由（SKILL 第2步缓存快速路由 / genre-classifier §〇 强信号快速校验+漂移兜底 / review-vector-db meta.json 登记）" (($missT20eS.Count -eq 0) -and ($missT20eG.Count -eq 0) -and $t20eVdb) $(if ($missT20eS -or $missT20eG -or -not $t20eVdb) { "SKILL 缺: $($missT20eS -join ',')；GC 缺: $($missT20eG -join ',')；VDB=$t20eVdb" } else { "SKILL 2/2 + GC 4/4 + VDB 登记" })

# T20f 人物卡三级金字塔（常驻层/建档层/名片层 + 出场≥3章建档 + setting.md ~300行控制；memory-index + vdb + README 三处一致）
$t20fKeys = @("常驻层", "建档层", "名片层")
$missT20fMi = @($t20fKeys | Where-Object { $mi20 -notlike "*$_*" })
$missT20fSkill = @($t20fKeys | Where-Object { $skill -notlike "*$_*" })
$t20fRd = ($readme -like "*人物卡三级金字塔*" -and $readme -like "*出场≥3章*")
$t20fVdb = ($vdb16 -like "*出场≥3 章*" -or $vdb16 -like "*出场≥3章*")
$t20fMi3 = ($mi20 -like "*人物卡三级分层*" -and ($mi20 -like "*出场≥3章*" -or $mi20 -like "*出场 ≥ 3 章*"))
Check "T20f" "人物卡三级金字塔（常驻层 setting.md / 建档层 characters/ / 名片层 entity_index.json + 出场≥3章建档 + ~300行控制）memory-index/SKILL/README/vdb 四处一致" (($missT20fMi.Count -eq 0) -and ($missT20fSkill.Count -eq 0) -and $t20fRd -and $t20fVdb -and $t20fMi3) $(if (-not (($missT20fMi.Count -eq 0) -and ($missT20fSkill.Count -eq 0) -and $t20fRd -and $t20fVdb -and $t20fMi3)) { "MI 缺: $($missT20fMi -join ',')；SKILL 缺: $($missT20fSkill -join ',')；README=$t20fRd；VDB=$t20fVdb；MI分层=$t20fMi3" } else { "四文档三级金字塔接线" })

# T20g v3.7 精简架构（project_state.json 四专项字段 / 5 核心文件 / 向量临时提取审完即弃 / style_fingerprint 单文件 / INDEX 22-24 条）
$t20gSkill = @("project_state.json", "system_state", "gender_state", "road_state", "san_value")
$missT20gS = @($t20gSkill | Where-Object { $skill -notlike "*$_*" })
$t20gVdb = ($vdb16 -like "*v3.7.0 重大精简*" -and $vdb16 -like "*临时提取*" -and $vdb16 -like "*审完即弃*")
$t20gSty = ($sty20 -like "*style_fingerprint.json*")
$t20gIdx = ($idx15 -like "*三级更新分级机制*" -and $idx15 -like "*项目数据库精简架构*" -and $idx15 -like "*禁止全量重写文件*")
Check "T20g" "v3.7 精简架构（project_state.json 四专项字段合并 / 向量临时提取审完即弃 / style_fingerprint 单文件 / INDEX 22-24 条铁律）" (($missT20gS.Count -eq 0) -and $t20gVdb -and $t20gSty -and $t20gIdx) $(if (-not (($missT20gS.Count -eq 0) -and $t20gVdb -and $t20gSty -and $t20gIdx)) { "SKILL 缺: $($missT20gS -join ',')；VDB=$t20gVdb；STY=$t20gSty；IDX=$t20gIdx" } else { "SKILL 5/5 字段 + VDB 精简 + STY 单文件 + INDEX 铁律" })

# T20h v3.8 精简优化（social 15 项并入 character-logic §三 人情账本审计 / review_flow 合并男女频标记 / INDEX v3.8.0 声明 / SKILL 专项通用铁律）
$t20hCl = @("人情账本审计", "十五项")
$missT20hCl = @($t20hCl | Where-Object { $cl19 -notlike "*$_*" })
$t20hRf = ($rf20 -like "*【男频专属】*" -and $rf20 -like "*【女频专属】*")
$t20hIdx = ($idx15 -like "*v3.8.0*" -and $idx15 -like "*social-audit-checklist*")
$t20hSkill = ($skill -like "*专项通用铁律*" -and $skill -like "*已并入原 social-audit-checklist*")
Check "T20h" "v3.8 精简优化（social-audit-checklist 15 项并入 character-logic 人情账本审计 / review_flow 男女频合并标记 / INDEX v3.8.0 声明 / SKILL 专项通用铁律合并）" (($missT20hCl.Count -eq 0) -and $t20hRf -and $t20hIdx -and $t20hSkill) $(if (-not (($missT20hCl.Count -eq 0) -and $t20hRf -and $t20hIdx -and $t20hSkill)) { "CL 缺: $($missT20hCl -join ',')；RF=$t20hRf；IDX=$t20hIdx；SKILL=$t20hSkill" } else { "CL 并入 + RF 合并 + IDX 声明 + SKILL 铁律合并" })

# T20i 增量写入规则（SKILL 增量写入+禁止全量重写 / vdb 增量追加 / INDEX 增量写入铁律 / report-template 轻量级自动回写）
$t20iSkill = ($skill -like "*增量写入*" -and $skill -like "*禁止全量重写*")
$t20iVdb = ($vdb16 -like "*增量追加*")
$t20iIdx = ($idx15 -like "*增量写入铁律*" -or ($idx15 -like "*增量写入*" -and $idx15 -like "*禁止全量重写*"))
$t20iRt = ($rt -like "*轻量级自动回写*" -and $rt -like "*增量追加*")
Check "T20i" "增量写入规则（SKILL 增量写入+禁止全量重写 / review-vector-db 增量追加 / INDEX 铁律 / report-template 轻量级自动回写）四文档一致" ($t20iSkill -and $t20iVdb -and $t20iIdx -and $t20iRt) $(if (-not ($t20iSkill -and $t20iVdb -and $t20iIdx -and $t20iRt)) { "SKILL=$t20iSkill；VDB=$t20iVdb；IDX=$t20iIdx；RT=$t20iRt" } else { "四文档增量写入接线" })

# T20j README v3.9.0 登记完整（最新更新六子节 + 历史更新 v3.8/v3.7 章节 + 版本记录三行 + 85 项测试声明）
$t20jKeys = @("## 📌 最新更新（v3.9.0", "确定性查表替代语义检索", "四大索引模块", "人物卡三级金字塔", "题材缓存路由",
              "与三级更新分级的整合", "旧库零迁移", "## 📌 历史更新（v3.8.0", "## 📌 历史更新（v3.7.0",
              "| **v3.9.0** | **2026-09-05** |", "| **v3.8.0** | **2026-09-05** |", "| **v3.7.0** | **2026-09-05** |",
              "85 项单元+集成测试", "T20 系列")
$missT20j = @($t20jKeys | Where-Object { $readme -notlike "*$_*" })
Check "T20j" "README v3.9.0 登记完整（最新更新六子节 / 历史更新 v3.8+v3.7 章节 / 版本记录三行 / 85 项测试+T20 范围）" ($missT20j.Count -eq 0) $(if ($missT20j) { "缺失: $($missT20j -join ',')" } else { "$(@($t20jKeys).Count)/$(@($t20jKeys).Count) 要点" })

# ── 汇总 ──
Write-Output ("=" * 78)
$nPass = 0
foreach ($r in $Results) {
    $mark = if ($r.Ok) { "PASS" } else { "FAIL" }
    if ($r.Ok) { $nPass++ }
    Write-Output ("[{0}] {1,-6} {2}" -f $mark, $r.Id, $r.Name)
    if (-not $r.Ok) { Write-Output ("        └─ {0}" -f $r.Detail) }
}
Write-Output ("-" * 78)
Write-Output ("通过 {0}/{1}" -f $nPass, $Results.Count)
Write-Output ("=" * 78)
if ($nPass -ne $Results.Count) { exit 1 }
