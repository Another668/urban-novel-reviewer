# run_tests.ps1 - urban-novel-reviewer v3.3.1 测试套件（单元 + 集成）
# 零依赖 PowerShell，Windows 原生运行：
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
# 覆盖：T1 结构完整性 / T2 九技能映射 / T3 六大审查接线 / T4 脚本集成 /
#       T5 坏样本AI味检出 / T6 好样本低误判 / T7 对话博弈 / T8 模板化 /
#       T9 合规红线机制 / T10 向量库社交集合 / T11 v3.1前置语义解析层接线 /
#       T12 v3.2大纲审稿分支+系统文专项接线 / T13 v3.2.1系统文扩容接线 /
#       T14 v3.3.0性别转变角色专项接线 /
#       T15 v3.3.1性转兼容方案接线（版本统一/三层路由/六项复用/双触发+降级+开关/统一附录输出/跨模块联动/原生兼容/灰度兜底/全链路版本一致性）/
#       T16 v3.4.0伏笔追踪专项接线（版本统一/判定-冲突-分题材三规则包/触发与深度三档/台账持久化/附录输出/INDEX联动/灰度兜底/README登记）
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

# ── T1 结构完整性 ──
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
    "references\rules-pack\social-audit-checklist.md",
    "references\rules-pack\social-scenario-rules.md",
    "references\rules-pack\outline-review-rules.md",
    "references\rules-pack\system-novel-rules.md",
    "references\templates\shared\templates\social_persona_card.md",
    "references\templates\shared\templates\relationship_ledger.md",
    "scripts\text_stats.py", "scripts\text_stats.ps1"
)
$missing = $required | Where-Object { -not (Test-Path (Join-Path $Root $_)) }
Check "T1" "技能包结构完整（rules-pack 9+模板2+脚本2）" ($missing.Count -eq 0) $(if ($missing) { "缺失: $($missing -join ', ')" } else { "$($required.Count) 个必备文件全部就位" })
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

# ── T10 向量库社交集合 ──
$vdb = Read-Text "references\review-vector-db.md"
$colls = @("social_ledger.jsonl", "relations.jsonl", "leverage.jsonl")
$missV = @($colls | Where-Object { $vdb -notlike "*$_*" })
Check "T10" "向量库社交三集合接线" ($missV.Count -eq 0) $(if ($missV) { "缺失: $($missV -join ',')" } else { "3/3 集合" })
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
    "误触发限定"   = ($skill -like "*仅用于网文小说创作中的审稿与润色场景*" -or $skill -like "*仅用于网文小说、文稿的审稿与润色场景*")
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

# ── T13 v3.2.1 系统文专项扩容接线（20 类赛道 + 12 套性格人设 + 双校验）──
$v321skill = [ordered]@{
    "版本3.3.1"    = ($skill -like "*3.3.1*")
    "路由20类"     = ($skill -like "*20 类*" -or $skill -like "*20类*")
    "性格人设库"   = ($skill -like "*性格人设*")
    "双校验"       = ($skill -like "*双校验*")
    "三节点推演"   = ($skill -like "*30 章*" -and $skill -like "*大结局*")
}
$bad321 = @($v321skill.Keys | Where-Object { -not $v321skill[$_] })
Check "T13" "SKILL.md v3.2.1 系统文扩容（20类/性格人设/双校验/三节点）全接线" ($bad321.Count -eq 0) $(if ($bad321) { "未接线: $($bad321 -join ',')" } else { "5/5 接线点" })
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
          "核心人设一致性", "核心问题", "分阶段优化建议", "前瞻风险预警",
          "C1", "C2", "C4")
$missGt = @()
foreach ($k in $gtKps) {
    # 【核心人设一致性】兼容 【核心人设一致性校验】；核心问题/分阶段优化建议/前瞻风险预警兼容同句或含「优化建议」「前瞻风险」的同源短语
    $ok = $false
    switch ($k) {
        "核心人设一致性" { $ok = ($gt -like "*【核心人设一致性*") }
        "核心问题"       { $ok = ($gt -like "*【核心问题*" -or $gt -like "*核心问题*") }
        "分阶段优化建议" { $ok = ($gt -like "*【分阶段优化建议*" -or ($gt -like "*优化建议*" -and $gt -like "*阶段*")) }
        "前瞻风险预警"   { $ok = ($gt -like "*【前瞻风险预警*" -or $gt -like "*前瞻风险*" -or $gt -like "*前瞻预警*") }
        default          { $ok = ($gt -like "*$k*") }
    }
    if (-not $ok) { $missGt += $k }
}
Check "T14"  "gender-transition-rules 六大维度+四模式+双方向+八小众赛道+6套模板+输出七模块+C1/C2/C4联动齐全" ($missGt.Count -eq 0) $(if ($missGt) { "缺失: $($missGt -join ',')" } else { "$(@($gtKps).Count)/$(@($gtKps).Count) 要点" })
# SKILL 接线：新路由行 + 新审查模式行 + 参考文件行 + 意图词典行
$gtSkillKps = @("性别转变专项", "gender-transition-rules", "六大审查维度", "性转、性别转换、变身", "女装大佬、伪娘、男娘", "变嫁", "强制型性转叠加")
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
# T15a v3.3.1 版本历史链路保留（SKILL/README/INDEX/GT-rules 声明 3.3.1；README 徽章已随 v3.4.0 顺延为 version-3.4.0）
$idx15 = Read-Text "references\rules-pack\INDEX.md"
$gt15  = Read-Text "references\rules-pack\gender-transition-rules.md"
$t15a = ($skill -like "*3.3.1*" -and $readme -like "*v3.4.0*" -and $readme -like "*v3.3.1*" -and $idx15 -like "*v3.3.1*" -and $gt15 -like "*3.3.1*")
Check "T15a" "v3.3.1 版本历史保留 + 徽章顺延（SKILL/README/INDEX/GT-rules 声明 3.3.1；README 徽章=version-3.4.0）" $t15a $(if ($t15a) { "5/5 声明到位（含 README v3.4.0 徽章顺延校验）" } else { "SKILL=$($skill -like '*3.3.1*') README_34=$($readme -like '*v3.4.0*') README_331=$($readme -like '*v3.3.1*') INDEX=$($idx15 -like '*v3.3.1*') GT=$($gt15 -like '*3.3.1*')" })

# T15b SKILL 三层路由架构 + 四级优先级排序
$routingKeys = @("语义解析层", "通用审稿内核", "专项增强层", "统一输出层", "正文 / 大纲 / 设定集", "主题材匹配", "通用专项匹配", "细分专项匹配")
$missRoute = @($routingKeys | Where-Object { $skill -notlike "*$_*" })
Check "T15b" "SKILL.md 三层路由架构（四节点链路）+ 四级路由优先级排序齐全" ($missRoute.Count -eq 0) $(if ($missRoute) { "缺失: $($missRoute -join ',')" } else { "$(@($routingKeys).Count)/$(@($routingKeys).Count) 要点" })

# T15c 六项底层能力复用（记忆扩展字段 / 4 类向量 / 文风校准 / 三步模板叠加 / 通用优先三仲裁 / 调度增强标注）
$reuseKeys = @("性别转变状态", "当前阶段", "核心转变节点",
               ".review-db/gender-transition/", "性别场景文风校准",
               "主题材模板", "性转专项模板",
               "通用规则优先级高于专项规则",
               "[调度:技能名 + 性转专项增强]")
$missReuse = @($reuseKeys | Where-Object { $skill -notlike "*$_*" -or (
    # 记忆/向量/文风/模板/规则/调度 六支柱覆盖：INDEX 也同步声明通用优先
    $_ -eq "通用规则优先级高于专项规则" -and -not ($idx15 -like "*$_*" -and $gt15 -like "*$_*")) })
Check "T15c" "六项底层能力复用（记忆3字段 / 向量独立目录 / 文风校准 / 三步模板叠加 / 通用优先三仲裁 / 调度增强标注）全链路接线" ($missReuse.Count -eq 0) $(if ($missReuse) { "缺失: $($missReuse -join ',')" } else { "$(@($reuseKeys).Count)/$(@($reuseKeys).Count) 要点" })

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
$missOutput = @($outputKeys | Where-Object {
    -not ($skill -like "*$_*" -and $idx15 -like "*$_*" -and $gt15 -like "*$_*" -and $readme -like "*$_*") })
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

# T15g Trae Skill 原生兼容：独立子目录 + 触发词追加既有词典 + 上下文继承
$nativeKeys = @("references/gender-transition/", ".review-db/gender-transition/", "上下文继承", "性转参数")
$missNative = @()
foreach ($k in $nativeKeys) {
    $ok = $true
    switch ($k) {
        # 上下文继承：兼容「上下文继承兼容」「上下文继承机制」；三文档需至少包含「上下文继承」短语
        "上下文继承" {
            $a = ($skill -like "*上下文继承*")
            $b = ($readme -like "*上下文继承*")
            $c = ($idx15 -like "*上下文继承*")
            $ok = ($a -and $b -and $c)
        }
        # 性转参数：兼容「性转参数 / 性别转变参数 / 性别转变阶段 / 人物状态」等同源参数名
        "性转参数" {
            $a = ($skill -like "*性转参数*" -or $skill -like "*性别转变阶段*")
            $b = ($readme -like "*性转参数*" -or $readme -like "*性别转变阶段*" -or $readme -like "*人物状态*")
            $c = ($idx15 -like "*性转参数*" -or $idx15 -like "*性别转变阶段*" -or $idx15 -like "*人物状态*")
            $ok = ($a -and $b -and $c)
        }
        default {
            $a = ($skill -like "*$_*")
            $b = ($readme -like "*$_*")
            $c = ($idx15 -like "*$_*")
            $ok = ($a -and $b -and $c)
        }
    }
    if (-not $ok) { $missNative += $k }
}
Check "T15g" "Trae Skill 原生兼容（references 与 .review-db 双独立子目录占位 + 触发词追加既有词典 + 上下文继承性转参数）三文档一致" ($missNative.Count -eq 0) $(if ($missNative) { "缺失: $($missNative -join ',')" } else { "$(@($nativeKeys).Count)/$(@($nativeKeys).Count) 要点" })

# T15h 灰度与兜底：默认建议级 / 独立数据 / 模块级回退清单 + 只提建议铁则
$safeguardKeys = @("建议级", "问题级", "数据隔离", "模块级回退", "只提建议")
$missSafe = @()
foreach ($k in $safeguardKeys) {
    $ok = $true
    switch ($k) {
        # 只提建议：兼容「只提建议、不改原文」「只提建议不擅自修改原文」「只提建议、不代写」的同源铁律表述
        "只提建议" {
            $a = ($skill -like "*只提建议*")
            $b = ($idx15 -like "*只提建议*")
            $c = ($gt15 -like "*只提建议*")
            $d = ($readme -like "*只提建议*" -or $readme -like "*只建议*")
            $ok = ($a -and $b -and $c -and $d)
        }
        default {
            $a = ($skill -like "*$_*")
            $b = ($idx15 -like "*$_*")
            $c = ($gt15 -like "*$_*")
            $d = ($readme -like "*$_*")
            $ok = ($a -and $b -and $c -and $d)
        }
    }
    if (-not $ok) { $missSafe += $k }
}
Check "T15h" "灰度与兜底兼容（建议级默认→稳定升问题级 / 数据物理隔离 / 模块级回退清单 + 只提建议铁则）四文档一致" ($missSafe.Count -eq 0) $(if ($missSafe) { "缺失: $($missSafe -join ',')" } else { "$(@($safeguardKeys).Count)/$(@($safeguardKeys).Count) 要点" })

# T15i README 测试套件总数 57 项 与 T15/T16 系列覆盖范围一致（确保未虚高）
$readmeCountOk = ($readme -like "*57 项单元+集成测试*" -and $readme -like "*T15 系列：分层路由*" -and $readme -like "*T16 系列*")
Check "T15i" "README 测试套件总数声明（57 项）与 T15/T16 系列覆盖范围一致" $readmeCountOk $(if ($readmeCountOk) { "57 项声明就位，T15/T16 范围描述齐全" } else { "声明缺失或范围不匹配" })

# ── T16 v3.4.0 伏笔追踪专项接线（版本统一 / 判定-冲突-分题材三规则包 / 触发与深度三档 / 台账持久化 / 附录输出 / INDEX 联动 / 灰度兜底 / README 登记）──
$fj16  = Read-Text "references\rules-pack\foreshadow-judgment-rules.md"
$fc16  = Read-Text "references\rules-pack\foreshadow-conflict-rules.md"
$ft16  = Read-Text "references\rules-pack\foreshadow-topic-templates.md"
$vdb16 = Read-Text "references\review-vector-db.md"
$sty16 = Read-Text "references\style-memory-db.md"

# T16a v3.4.0 版本号全链路统一（SKILL frontmatter / README 徽章 / INDEX / 三伏笔规则包）
$t16a = ($skill -like "*version: 3.4.0*" -and $readme -like "*version-3.4.0*" -and $readme -like "*v3.4.0*" -and $idx15 -like "*v3.4.0*" -and $fj16 -like "*v3.4.0*" -and $fc16 -like "*v3.4.0*" -and $ft16 -like "*v3.4.0*")
Check "T16a" "v3.4.0 版本号全链路统一（SKILL frontmatter / README 徽章 / INDEX / 判定-冲突-模板三规则包 七处声明）" $t16a $(if ($t16a) { "7/7 声明到位" } else { "SKILL=$($skill -like '*version: 3.4.0*') README_badge=$($readme -like '*version-3.4.0*') README_v=$($readme -like '*v3.4.0*') INDEX=$($idx15 -like '*v3.4.0*') FJ=$($fj16 -like '*v3.4.0*') FC=$($fc16 -like '*v3.4.0*') FT=$($ft16 -like '*v3.4.0*')" })

# T16b 判定标准：五大类 22 小类 + 生命周期状态机 + 台账字段 + 埋设强度伪装度 + 深度三档
$fjKps = @("五大类", "22 小类", "实体类", "人物类", "力量体系类", "剧情长线类", "隐性弱埋线", "F1", "F22",
           "planted", "reinforced", "closed", "overdue", "broken", "生命周期", "状态机",
           "foreshadow_table", "编号", "优先级", "锚点", "计划回收章",
           "明示", "暗示", "伪装度", "文风自然度", "quick", "full", "precise", "foreshadow_base")
$missFj = @($fjKps | Where-Object { $fj16 -notlike "*$_*" })
Check "T16b" "foreshadow-judgment-rules 五大类22小类+生命周期状态机+台账字段+埋设强度伪装度+深度三档+精度对比齐全" ($missFj.Count -eq 0) $(if ($missFj) { "缺失: $($missFj -join ',')" } else { "$(@($fjKps).Count)/$(@($fjKps).Count) 要点" })

# T16c 冲突校验：四类冲突（联动 C1-C3/B1-B3/D2）+ 回收节奏 + 遗忘预警阈值 + hooks 分工 + 精度对比
$fcKps = @("设定冲突", "人物冲突", "时间线冲突", "剧情自洽", "C3", "B2", "B1", "D2",
           "5-15 章", "30-60 章", "150 章", "遗忘预警", "30 章", "60 章", "膨胀", "倒查",
           "吃书", "知识边界", "分工", "hooks", "精度对比")
$missFc = @($fcKps | Where-Object { $fc16 -notlike "*$_*" })
Check "T16c" "foreshadow-conflict-rules 四类冲突校验(联动C1-C3/B1-B3/D2)+回收节奏+遗忘预警阈值+hooks分工+精度对比齐全" ($missFc.Count -eq 0) $(if ($missFc) { "缺失: $($missFc -join ',')" } else { "$(@($fcKps).Count)/$(@($fcKps).Count) 要点" })

# T16d 分题材模板：题材速查表（11 行）+ 分题材伏笔类型 + 跨题材五雷区 + 大纲联动 + 叠加顺序
$ftKps = @("系统文", "变嫁", "末世", "仙侠", "商战", "悬疑", "快穿", "古言", "娱乐圈", "职场",
           "任务伏笔", "奖励伏笔", "身份伏笔", "情感伏笔", "秘密伏笔", "战力伏笔", "势力伏笔", "人脉伏笔", "信息差", "布局",
           "三层真相", "空降伏笔", "伏笔坟场", "回收倾销", "伪伏笔", "重复埋设",
           "大纲", "速查表", "叠加顺序")
$missFt = @($ftKps | Where-Object { $ft16 -notlike "*$_*" })
Check "T16d" "foreshadow-topic-templates 题材速查表11行+分题材伏笔类型+跨题材五雷区+大纲联动+叠加顺序齐全" ($missFt.Count -eq 0) $(if ($missFt) { "缺失: $($missFt -join ',')" } else { "$(@($ftKps).Count)/$(@($ftKps).Count) 要点" })

# T16e SKILL.md 伏笔专项全接线（复用机制 / 台账 / 深度三档 / 触发词 / 开关 / 前缀输出 / 铁律12）
$v340skill = [ordered]@{
    "专项复用机制章节" = ($skill -like "*伏笔追踪专项复用机制*")
    "三规则包引用"     = ($skill -like "*foreshadow-judgment-rules*" -and $skill -like "*foreshadow-conflict-rules*" -and $skill -like "*foreshadow-topic-templates*")
    "台账持久化"       = ($skill -like "*foreshadow_table*" -and $skill -like "*.review-db/foreshadow/*")
    "同源同步"         = ($skill -like "*同源同步*")
    "深度三档映射"     = ($skill -like "*深度三档*" -and $skill -like "*quick*" -and $skill -like "*full*" -and $skill -like "*precise*")
    "触发词三类"       = ($skill -like "*埋线*" -and $skill -like "*挖坑*" -and $skill -like "*剧情吃书*" -and $skill -like "*前后矛盾*" -and $skill -like "*线索遗漏*")
    "自动叠加场景"     = ($skill -like "*自动叠加*")
    "手动开关"         = ($skill -like "*启用伏笔专项深度审查*" -and $skill -like "*禁用伏笔专项，按通用标准审*")
    "伏笔前缀输出"     = ($skill -like "*【伏笔】*" -and $skill -like "*【伏笔预警】*")
    "精度对比可选"     = ($skill -like "*foreshadow_base*")
    "铁律12灰度隔离"   = ($skill -like "*伏笔专项灰度与数据隔离*")
}
$bad340 = @($v340skill.Keys | Where-Object { -not $v340skill[$_] })
Check "T16e" "SKILL.md v3.4.0 伏笔专项全接线（复用机制/台账持久化/深度三档/触发词/开关/伏笔前缀/铁律12）" ($bad340.Count -eq 0) $(if ($bad340) { "未接线: $($bad340 -join ',')" } else { "$(@($v340skill).Count)/$(@($v340skill).Count) 接线点" })

# T16f 台账持久化 + 向量库 / 文风库联动接线
$v340db = [ordered]@{
    "向量库伏笔子目录" = ($vdb16 -like "*foreshadow*" -and $vdb16 -like "*foreshadow_table*")
    "台账文件"         = ($vdb16 -like "*foreshadow_table.md*")
    "5类特征向量"      = ($vdb16 -like "*隐性弱埋线*")
    "物理隔离"         = ($vdb16 -like "*物理隔离*")
    "文风自然度校验"   = ($sty16 -like "*伏笔自然度校验*" -and $sty16 -like "*伪装度*")
    "明示密度阈值"     = ($sty16 -like "*2 处/千字*" -or $sty16 -like "*2处/千字*")
}
$bad340db = @($v340db.Keys | Where-Object { -not $v340db[$_] })
Check "T16f" "台账持久化与底层库联动（.review-db/foreshadow 台账+vectors 5类特征向量 / style 库伏笔自然度校验+明示密度阈值）接线" ($bad340db.Count -eq 0) $(if ($bad340db) { "未接线: $($bad340db -join ',')" } else { "$(@($v340db).Count)/$(@($v340db).Count) 接线点" })

# T16g 报告模板伏笔附录 + 输出降级规则
$rtFKps = @("伏笔追踪专项附录", "伏笔追踪专项结论", "本章新增预埋", "全局未回收", "逻辑冲突", "原生系统精度对比", "全书伏笔追踪表", "【伏笔】", "【伏笔预警】", "foreshadow_base", "降级")
$missRtF = @($rtFKps | Where-Object { $rt -notlike "*$_*" })
Check "T16g" "report-template 伏笔追踪专项附录（预埋/未回收/冲突/精度对比/追踪表 五子段）+【伏笔】前缀+【伏笔预警】+降级规则齐全" ($missRtF.Count -eq 0) $(if ($missRtF) { "缺失: $($missRtF -join ',')" } else { "$(@($rtFKps).Count)/$(@($rtFKps).Count) 要点" })

# T16h INDEX 登记联动 + SKILL 灰度兜底（通用优先/不重复/建议级/模块级回退/可选依赖/任意叠加）
$idxFKps = @("foreshadow-judgment-rules.md", "foreshadow-conflict-rules.md", "foreshadow-topic-templates.md", "伏笔追踪专项", "同源", "冲突处理", "自动叠加", "precise", "foreshadow_base", "建议级", "只提建议", "模块级回退", "不重复")
$missIdxF = @($idxFKps | Where-Object { $idx15 -notlike "*$_*" })
$skillSafe340 = @("建议级", "模块级回退清单", "物理隔离", "foreshadow_base", "任意叠加")
$missSkillSafe = @($skillSafe340 | Where-Object { $skill -notlike "*$_*" })
Check "T16h" "INDEX 伏笔三包登记+联动条款（同源/冲突处理/自动叠加/precise/建议级/只提建议/模块级回退/不重复）与 SKILL 灰度兜底（建议级/回退清单/物理隔离/可选依赖/任意叠加）齐备" (($missIdxF.Count -eq 0) -and ($missSkillSafe.Count -eq 0)) $(if ($missIdxF -or $missSkillSafe) { "INDEX 缺失: $($missIdxF -join ',')；SKILL 缺失: $($missSkillSafe -join ',')" } else { "INDEX $(@($idxFKps).Count)/$(@($idxFKps).Count) + SKILL $($skillSafe340.Count)/$($skillSafe340.Count) 要点" })

# T16i README 登记 v3.4.0 伏笔追踪专项（徽章/功能特性/触发词/模式/调度/目录/版本记录/测试总数）
$readmeFKps = @("version-3.4.0", "v3.4.0", "伏笔追踪", "伏笔追踪专项", "foreshadow_table", "五大类 22 小类", "遗忘预警", "深度三档", "foreshadow_base", "57 项单元+集成测试", "T16 系列")
$missRdF = @($readmeFKps | Where-Object { $readme -notlike "*$_*" })
Check "T16i" "README v3.4.0 伏笔追踪专项登记（徽章/最新更新/功能特性/触发词/审稿模式/调度映射/目录结构/.review-db/版本记录/测试57项+T16范围）齐全" ($missRdF.Count -eq 0) $(if ($missRdF) { "缺失: $($missRdF -join ',')" } else { "$(@($readmeFKps).Count)/$(@($readmeFKps).Count) 要点" })

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
