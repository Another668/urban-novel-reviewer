# text_stats.ps1 - 网文文本量化统计（urban-novel-reviewer v3.0）
# 零依赖 PowerShell 版，功能对齐 scripts/text_stats.py：AI 特征词频 / 段落结构 / 句长均质 /
# 对话占比 / 的的不休 / 弱化副词密度。供审稿时取量化证据；脚本命中为线索，最终判定需语境复核。
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\text_stats.ps1 -Path <章节文件> [-Mode full|ai|structure|repeat]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [ValidateSet("full", "ai", "structure", "repeat")][string]$Mode = "full"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Path)) { Write-Error "文件不存在: $Path"; exit 1 }
$text = Get-Content -Path $Path -Raw -Encoding UTF8

# ── AI 特征词库（与 references/rules-pack/ai-flavor-rules.md 保持同步）──
$AiGroups = [ordered]@{
    "情绪套话"   = @("心中涌现", "眼眸深处", "嘴角微微上扬", "嘴角勾起", "眸子微动", "深吸一口气", "心头一紧", "心中一动", "五味杂陈", "百感交集", "莫名的感动", "热泪盈眶", "眼眶湿润", "眼中闪过")
    "思维OS套话" = @("他深知", "她深知", "他明白", "她明白", "清楚地知道", "终于明白", "暗自下定决心", "命运的齿轮", "这一切都是命运")
    "行动套话"   = @("不动声色", "淡淡地说", "淡然道", "淡漠道", "缓缓开口", "沉默片刻", "沉声道", "云淡风轻", "冷冷地扫", "轻描淡写", "嗤之以鼻")
    "场景套话"   = @("阳光透过", "空气中弥漫着", "夜风轻轻", "时间仿佛凝固", "空气都变得凝重", "寂静笼罩")
    "过渡套话"   = @("正当此时", "就在这时", "千钧一发之际", "与此同时", "谁也没想到", "都只是", "刚刚开始")
    "旁观者惊叹" = @("周围的人都惊呆", "倒吸一口冷气", "没有人想到", "谁也没想到", "人群中爆发", "陷入一片寂静", "议论纷纷", "面面相觑", "所有人的目光", "在场所有人")
    "华丽意象"   = @("璀璨", "熠熠生辉", "画卷", "华章", "乘风破浪", "扬帆起航", "落英缤纷", "如梦似幻", "如诗如画", "气势磅礴", "美不胜收", "令人窒息", "肃然起敬")
    "番茄禁用词" = @("不禁", "竟然", "居然", "仿佛", "宛如", "深邃", "瞳孔收缩", "瞳孔微缩", "嘴角上扬")
    "弱化副词"   = @("缓缓", "微微", "轻轻", "淡淡", "慢慢", "悄悄", "冷冷", "淡然", "漠然", "陡然", "骤然", "猛然", "猛地", "死死地")
    "最毒句式"   = @("不是", "而是", "带着", "毫无波澜", "平静无波", "心中涌起", "心头一震", "他不知道的是", "她不知道的是", "这一夜注定", "才刚刚开始")
}

# 话疗关键词（G3 门禁）
$Hualiao = @("我理解你", "说服", "感化", "唤醒", "共鸣", "融入", "共存", "不是消灭", "救赎")

function Get-Count($haystack, $needle) {
    $c = 0; $i = 0
    while (($i = $haystack.IndexOf($needle, $i)) -ge 0) { $c++; $i += [Math]::Max(1, $needle.Length) }
    return $c
}

$totalChars = ($text -replace "\s", "").Length
Write-Output "===== 文本统计报告 ====="
Write-Output ("文件: {0}" -f (Resolve-Path $Path))
Write-Output ("总字数(去空白): {0}" -f $totalChars)

if ($Mode -in "full", "ai") {
    Write-Output "`n----- AI 特征词命中（分组计数，单次不判、看密度）-----"
    $grand = 0
    foreach ($g in $AiGroups.Keys) {
        $hits = @()
        foreach ($w in $AiGroups[$g]) {
            $n = Get-Count $text $w
            if ($n -gt 0) { $hits += ("{0}×{1}" -f $w, $n); $grand += $n }
        }
        $line = if ($hits.Count) { $hits -join "，" } else { "（无命中）" }
        Write-Output ("[{0}] {1}" -f $g, $line)
    }
    Write-Output ("-- AI 特征词总命中: {0} 处（参考: 0-2低风险 / 3-5中风险 / >5高风险，须语境复核）" -f $grand)
    $hl = @()
    foreach ($w in $Hualiao) { $n = Get-Count $text $w; if ($n -gt 0) { $hl += ("{0}×{1}" -f $w, $n) } }
    Write-Output ("[话疗关键词 G3] {0}" -f ($(if ($hl.Count) { $hl -join "，" } else { "（无命中）" })))
}

if ($Mode -in "full", "structure") {
    Write-Output "`n----- 段落与对话结构 -----"
    $paras = $text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }
    $pLen = $paras | ForEach-Object { ($_ -replace "\s", "").Length }
    $avgP = if ($pLen.Count) { [math]::Round(($pLen | Measure-Object -Average).Average, 1) } else { 0 }
    $sdP = if ($pLen.Count -gt 1) {
        $m = ($pLen | Measure-Object -Average).Average
        [math]::Round([math]::Sqrt((($pLen | ForEach-Object { ($_ - $m) * ($_ - $m) }) | Measure-Object -Average).Average), 1)
    } else { 0 }
    $uniform = if ($avgP -gt 0) { [math]::Round($sdP / $avgP, 2) } else { 0 }
    $lq = [char]0x201C; $rq = [char]0x201D
    $dlgLines = ($paras | Where-Object { $_.Contains($lq) -or $_.Contains($rq) -or $_.Contains('"') }).Count
    $dlgRatio = if ($paras.Count) { [math]::Round($dlgLines / $paras.Count * 100, 1) } else { 0 }
    Write-Output ("非空段落数: {0}  段长均值: {1}  段长标准差: {2}  段落均匀度: {3}（<0.3 疑似AI均质）" -f $paras.Count, $avgP, $sdP, $uniform)
    Write-Output ("含引号行: {0}  对话占比(行数法): {1}%  （门禁: ≤40%达标 / >40%超标 / >50%大改）" -f $dlgLines, $dlgRatio)

    $sents = [regex]::Matches($text, "[^。！？!?…]+[。！？!?…]?") | ForEach-Object { ($_.Value -replace "\s", "").Length } | Where-Object { $_ -gt 0 }
    if ($sents.Count) {
        $sAvg = [math]::Round(($sents | Measure-Object -Average).Average, 1)
        $sSd = [math]::Round([math]::Sqrt((($sents | ForEach-Object { ($_ - $sAvg) * ($_ - $sAvg) }) | Measure-Object -Average).Average), 1)
        $machine = ($sents | Where-Object { $_ -ge 15 -and $_ -le 30 }).Count
        Write-Output ("句数: {0}  句长均值: {1}  句长标准差: {2}  15-30字句: {3}（连续5句波动≤5字=机关枪节奏）" -f $sents.Count, $sAvg, $sSd, $machine)
    }

    $dCount = 0
    foreach ($line in $paras) { $dCount += ([regex]::Matches($line, "的")).Count }
    $de = [char]0x7684  # 的
    Write-Output ("[{0}]字总数: {1}（单句≥4个[{0}]=的的不休，需逐句人工复核）" -f $de, $dCount)
}

if ($Mode -in "full", "repeat") {
    Write-Output "`n----- 高频词/重复（3-8字短语粗扫）-----"
    $paras = $text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }
    $phrases = @{}
    foreach ($p in $paras) {
        $lq = [char]0x201C; $rq = [char]0x201D
        $clean = ($p -replace "[，。！？!?…、：；\s]", "").Replace($lq, "").Replace($rq, "").Replace('"', "")
        for ($k = 4; $k -le 8; $k++) {
            for ($i = 0; $i -le $clean.Length - $k; $i += 2) {
                $ph = $clean.Substring($i, $k)
                if ($ph -match "[一-鿿]{$k}") { $phrases[$ph] = 1 + ($phrases[$ph] | ForEach-Object { $_ }) }
            }
        }
    }
    $top = $phrases.GetEnumerator() | Where-Object { $_.Value -ge 3 } | Sort-Object Value -Descending | Select-Object -First 10
    if ($top) { $top | ForEach-Object { Write-Output ("  「{0}」×{1}" -f $_.Key, $_.Value) } }
    else { Write-Output "  （无≥3次重复短语）" }
}
Write-Output "`n提示：脚本结果为线索，对话层套话/刻意为之/真人门检信号需人工语境复核（见 ai-flavor-rules.md §0）。"
