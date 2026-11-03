#!/usr/bin/env python
# 生成一页「项目进度看板」HTML：左边每个模块做到哪，右边最近一次 CI 跑出来的真机截图
#
# 为什么需要它：此前所有进度都躺在 docs/*.md 里，用户要翻五个文档才知道"现在到哪了"，
# 而且看不到 App 长什么样。这个脚本把两件事合成一页：
#   1) 阶段与条目状态 —— 从 01-开发清单.md 里解析，不手填，避免看板与实际漂移；
#   2) 截图 —— 从 docs/shots/ 里读 CI 下载回来的 PNG。
# 产出 docs/dashboard.html，双击就能看，可以随时重跑。

import base64  # 把截图内嵌成单文件 HTML 用
import glob  # 找文件
import os  # 路径处理
import re  # 解析 markdown
import subprocess  # 调 git 拿提交号
from datetime import datetime  # 生成时间

ROOT = r"D:\APP"  # 项目根目录
DOC = os.path.join(ROOT, "docs", "01-开发清单.md")  # 清单文档
SHOTS = os.path.join(ROOT, "docs", "shots")  # 截图目录
OUT = os.path.join(ROOT, "docs", "dashboard.html")  # 输出文件
OUT_SINGLE = os.path.join(ROOT, "docs", "dashboard-standalone.html")  # 图片内嵌的单文件版，方便发给别人或跨设备打开
# 发布目录：只放一个自包含 index.html，避免把整个 docs（含项目文档）都传到公网
PUB_DIR = os.path.join(ROOT, "publish")  # 发布用目录
PUB_INDEX = os.path.join(PUB_DIR, "index.html")  # 发布入口

TAB_CN = {"today": "今日", "quiz": "刷题", "interview": "面试", "companion": "伙伴", "profile": "我的"}  # Tab 英文名转中文
TAB_DESC = {  # 每张图看什么
    "today": "倒计时 / 今日概览 / 任务",
    "quiz": "章节列表 / 关卡星级",
    "interview": "考官构成 / 考场设置",
    "companion": "3D 宠物 / 投喂",
    "profile": "统计 / 成长溯源 / 重置",
}

# 样板（Web 原型）18 个页面 → iOS 实况对照表
# 说明：这张表是人工建立的「一一对应关系」，但每行的状态由脚本去检查文件是否存在，
# 不是手填的。文件不在就显示「没做」，所以看板不会骗人。
# 字段：(样板页面 id, 样板页名, 对应的 iOS 文件相对 app/FuShiZhuan 的路径 或 None, 备注)
PAGES = [
    ("page-home", "今日首页", "Features/Today/TodayView.swift", "倒计时 / 任务 / 宠物卡"),
    ("page-quiz", "刷题首页", "Features/Quiz/QuizHomeView.swift", "章节与关卡星级"),
    ("page-run", "答题过程", "Features/Quiz/LevelPlayView.swift", "闯关答题 + 即时解析"),
    ("page-result", "交卷结果", "Features/Quiz/LevelPlayView.swift", "结果页在该文件内"),
    ("page-game", "闯关模式", "Features/Quiz/LevelPlayView.swift", "3 心 / 连击 / 星级"),
    ("page-wrong", "错题本", None, "数据模型已有（WrongItem），页面未做"),
    ("page-diy", "换装 DIY", None, "缺美术资产"),
    ("page-shop", "商店", None, "未定商品规则"),
    ("page-interview", "面试设置", "Features/Interview/InterviewHomeView.swift", "考官构成 / 近期场次"),
    ("page-room", "面试考场", "Features/Interview/InterviewRoomView.swift", "5 席 / 提问 / 作答"),
    ("page-review", "面试复盘", "Features/Interview/InterviewReviewView.swift", "五维评分 / 逐题点评"),
    ("page-mock", "模考大厅", "Features/MockExam/MockExamHomeView.swift", "单机模拟版"),
    ("page-pet", "伙伴主页", "Features/Companion/CompanionHomeView.swift", "3D 宠物 / 投喂"),
    ("page-ritual", "拨穗仪式", "Features/Companion/PetSceneView.swift", "流苏绕竖轴转半圈"),
    ("page-map", "学习地图", "Features/Plaza/WorldMapView.swift", "5 座考研岛"),
    ("page-plaza", "广场", None, "样板是 NPC，iOS 未做"),
    ("page-community", "社区", None, "UGC，受苹果审核 1.2 约束"),
    ("page-post", "发帖", None, "同上"),
]

# iOS 有、样板没有的页面（不是缺口，是超出样板的部分）
EXTRA = [
    ("我的", "Features/Profile/ProfileView.swift", "统计 / 成长溯源 / 重置 / 导出"),
    ("付费墙", "Features/Profile/PaywallView.swift", "StoreKit 2 订阅"),
    ("错题本", "Features/Quiz/WrongBookView.swift", "待攻 / 已掌握 + 板块归类"),
    ("AI 学伴", "Features/Today/CoachCard.swift", "先本地建议，点「问问」才联网"),
    ("隐私与协议", "Features/Profile/LegalView.swift", "隐私政策 / 用户协议双 Tab"),
    ("商户入驻", "Features/Profile/MerchantEntryView.swift", "占位页"),
]

# 哪个样板页面能对上某个 Tab 的截图（只有 5 个 Tab 有图）
PAGE_SHOT = {
    "page-home": "today",
    "page-quiz": "quiz",
    "page-interview": "interview",
    "page-pet": "companion",
}

STAGE_CN = {  # 阶段名，与清单保持一致
    0: "环境与骨架",
    1: "设计系统与导航",
    2: "数据层（单一来源）",
    3: "学习模块",
    4: "AI 面试",
    5: "3D 形象与电子宠物",
    6: "3D 社区与地图",
    7: "会员与支付",
    8: "联调与上线",
}


def read_doc():  # 读清单文档
    with open(DOC, "r", encoding="utf-8") as f:  # 按 UTF-8 打开
        return f.read()  # 全文返回


def parse_items(text):  # 解析所有 Sx.y 条目
    items = []  # 待返回
    stage = None  # 当前所在阶段
    marks = ("✅", "🔄", "⬜")  # 三种合法标记
    for line in text.splitlines():  # 逐行扫
        m_stage = re.match(r"^## 阶段 (\d+)", line)  # 阶段标题
        if m_stage:  # 命中了
            stage = int(m_stage.group(1))  # 记下阶段号
            continue  # 下一行
        if line.startswith("## "):  # 别的二级标题
            stage = None  # 阶段上下文结束
            continue  # 下一行
        if stage is None or not line.startswith("| S"):  # 不是条目行
            continue  # 跳过
        cells = [c.strip() for c in line.strip().strip("|").split("|")]  # 按竖线切表格
        if len(cells) < 2:  # 格子太少
            continue  # 跳过
        m_id = re.match(r"^(S\d+\.\d+)\s*([✅🔄⬜]?)$", cells[0])  # 第一格可能是「S4.1」也可能是「S4.1 🔄」
        if not m_id:  # 不是条目行
            continue  # 跳过
        title = cells[1]  # 默认第二格就是标题
        mark = m_id.group(2) or "?"  # 第一格里带了标记就用它
        if mark == "?" and cells[1] and cells[1][0] in marks:  # 标记写在第二格（另一种表头排法）
            mark = cells[1][0]  # 取标记
            title = cells[2] if len(cells) > 2 else cells[1]  # 标题顺延到第三格
        items.append({  # 收进来
            "id": m_id.group(1),  # 编号
            "mark": mark,  # 状态标记
            "title": re.sub(r"[*`]", "", title),  # 标题去掉 markdown 记号
            "stage": stage,  # 所属阶段
        })  # 收集结束
    return items  # 返回全部条目


def parse_progress(text):  # 解析「当前进度」表，这是阶段状态的唯一权威来源
    progress = {}  # 阶段号 → (标记, 描述, 证据)
    inside = False  # 是否已进入该小节
    for line in text.splitlines():  # 逐行扫
        if line.startswith("## 当前进度"):  # 进入小节
            inside = True  # 打开开关
            continue  # 下一行
        if inside and line.startswith("## "):  # 出了小节
            break  # 结束
        if not inside or not line.startswith("| "):  # 不是表格行
            continue  # 跳过
        cells = [c.strip() for c in line.strip().strip("|").split("|")]  # 切表格
        if len(cells) < 2 or not cells[0].isdigit():  # 第一格必须是阶段号
            continue  # 跳过表头与分隔行
        status = cells[1]  # 状态词，形如「✅ 代码完成（…）」
        mark = status[0] if status and status[0] in ("✅", "🔄", "⬜") else "?"  # 取首个字符当标记
        progress[int(cells[0])] = {  # 存起来
            "mark": mark,  # 标记
            "text": re.sub(r"[*`]", "", status),  # 状态原词
            "evidence": re.sub(r"[*`]", "", cells[2]) if len(cells) > 2 else "",  # 证据
        }  # 存完
    return progress  # 返回


def parse_notes(text):  # 解析写在阶段末尾的"差距说明"段落
    notes = {}  # 按阶段号存
    stage = None  # 当前阶段
    for line in text.splitlines():  # 逐行扫
        m_stage = re.match(r"^## 阶段 (\d+)", line)  # 阶段标题
        if m_stage:  # 命中
            stage = int(m_stage.group(1))  # 记下
            continue  # 下一行
        if line.startswith("## "):  # 出了阶段区
            stage = None  # 清空
            continue  # 下一行
        if stage is None:  # 不在阶段区里
            continue  # 跳过
        if line.startswith("**当前差距**") or line.startswith("**进度**") or line.startswith("**为什么停在这里"):  # 三类说明行
            notes.setdefault(stage, []).append(line.strip())  # 累积到该阶段
    return notes  # 返回


def code_stats():  # 统计代码事实（全部现算，不手填）
    swift = glob.glob(os.path.join(ROOT, "app", "FuShiZhuan", "**", "*.swift"), recursive=True)  # App 源码
    tests = glob.glob(os.path.join(ROOT, "app", "FuShiZhuanTests", "**", "*.swift"), recursive=True)  # 测试
    lines = 0  # 源码总行数
    for path in swift:  # 逐个文件
        with open(path, "r", encoding="utf-8", errors="replace") as f:  # 打开
            lines += len(f.readlines())  # 累加行数
    methods = 0  # 测试方法数
    asserts = 0  # 断言数
    for path in tests:  # 逐个测试文件
        with open(path, "r", encoding="utf-8", errors="replace") as f:  # 打开
            body = f.read()  # 一次读完
        methods += len(re.findall(r"\n\s*func test", body))  # 数测试方法
        asserts += len(re.findall(r"XCTAssert", body))  # 数断言
    return {"files": len(swift), "lines": lines, "tfiles": len(tests), "methods": methods, "asserts": asserts}  # 返回


def latest_shots():  # 找出最新一批截图
    marker = os.path.join(SHOTS, "latest.txt")  # 记录最新运行号的文件
    run_id = None  # 运行号
    if os.path.exists(marker):  # 有标记就用标记
        with open(marker, "r", encoding="utf-8") as f:  # 打开
            run_id = f.read().strip()  # 读掉空白
    if run_id:  # 校验目录真存在
        folder = os.path.join(SHOTS, run_id)  # 对应目录
        if os.path.isdir(folder):  # 存在
            return run_id, sorted(glob.glob(os.path.join(folder, "*.png")))  # 返回
    runs = sorted([d for d in glob.glob(os.path.join(SHOTS, "*")) if os.path.isdir(d)])  # 退路：按目录名排序
    if not runs:  # 一张图都没有
        return None, []  # 返回空
    folder = runs[-1]  # 取最新目录
    return os.path.basename(folder), sorted(glob.glob(os.path.join(folder, "*.png")))  # 返回


def git_head():  # 取最近一次提交号，标注看板对应哪版代码
    try:  # 可能没有 git
        out = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=10)  # 执行
        return out.stdout.strip() or "未知"  # 拿到就用
    except Exception:  # 任何异常都不该让看板生成失败
        return "未知"  # 返回占位


def stage_summary(items):  # 按阶段汇总条目
    summary = {}  # 阶段号 → 统计
    for item in items:  # 逐条
        bucket = summary.setdefault(item["stage"], {"done": 0, "open": [], "unknown": 0, "total": 0})  # 初始化
        bucket["total"] += 1  # 总数
        if item["mark"] == "✅":  # 明确完成
            bucket["done"] += 1  # 计数
        elif item["mark"] in ("🔄", "⬜"):  # 明确未完成
            bucket["open"].append("%s %s" % (item["id"], item["title"]))  # 记下编号和名字
        else:  # 表里没有状态列
            bucket["unknown"] += 1  # 单独计
    return summary  # 返回


MARK_COLOR = {"✅": "#1f9d55", "🔄": "#c98a00", "⬜": "#8a94a6", "?": "#8a94a6"}  # 状态配色
MARK_WIDTH = {"✅": 100, "🔄": 55, "⬜": 8, "?": 8}  # 进度条长度是状态示意，不是精确百分比


def compare_html(shots, run_id):  # 生成「样板 18 页 vs iOS 实况」对照表
    app_dir = os.path.join(ROOT, "app", "FuShiZhuan")  # iOS 源码根
    by_tab = {}  # Tab 名 → 图片文件名
    for path in shots:  # 逐张截图
        by_tab[os.path.splitext(os.path.basename(path))[0]] = os.path.basename(path)  # 记录
    base = "shots/%s" % run_id if run_id else ""  # 相对 docs/ 的图片目录

    rows = []  # 表格行
    done = 0  # 有代码的样板页数
    shot_count = 0  # 有截图的数量
    for pid, name, rel, note in PAGES:  # 逐条样板页
        exists = bool(rel) and os.path.isfile(os.path.join(app_dir, rel))  # 文件真实存在才算做了
        tab = PAGE_SHOT.get(pid)  # 该页有没有对应截图
        shot_file = by_tab.get(tab) if tab else None  # 取图片名
        if exists:  # 有代码
            done += 1  # 计数
        if exists and shot_file:  # 有代码且有图
            mark, color, label = "✅", "#1f9d55", "已实现·已截图"  # 绿
            img = '<a href="%s/%s" target="_blank"><img class="thumb" src="%s/%s" alt="%s"></a>' % (base, shot_file, base, shot_file, name)  # 缩略图
            shot_count += 1  # 计数
        elif exists:  # 有代码但没截过图
            mark, color, label = "🟡", "#c98a00", "已实现·未截图"  # 琥珀
            img = '<span class="nosshot">—</span>'  # 没有图
        else:  # 没做
            mark, color, label = "❌", "#c2410c", "未做"  # 橙红
            img = '<span class="nosshot">—</span>'  # 没有图
        impl = ('<code>%s</code>' % rel.split("/")[-1]) if rel else '<span class="nosshot">%s</span>' % note  # 实现文件或缺失原因
        if exists and rel:  # 已实现的补一句说明
            impl += '<div class="sub2">%s</div>' % note  # 备注
        rows.append(  # 一行
            '<div class="cmp-row"><div class="cmp-name">%s</div>'
            '<div><span class="cmp-dot" style="background:%s"></span>%s</div>'
            '<div class="cmp-impl">%s</div><div>%s</div></div>' % (
                name, color, label, impl, img)
        )  # 行结束

    extra_rows = []  # iOS 独有页面
    for name, rel, note in EXTRA:  # 逐条
        if os.path.isfile(os.path.join(app_dir, rel)):  # 存在才列
            extra_rows.append(  # 一行
                '<div class="cmp-row extra"><div class="cmp-name">%s</div>'
                '<div><span class="cmp-dot" style="background:#2b54e8"></span>iOS 独有</div>'
                '<div class="cmp-impl"><code>%s</code><div class="sub2">%s</div></div><div>—</div></div>' % (
                    name, rel.split("/")[-1], note)
            )  # 行结束

    head = ('<div class="cmp-head"><span>样板页</span><span>iOS 状态</span>'
            '<span>实现位置 / 缺失原因</span><span>截图</span></div>')  # 表头
    summary = ('<div class="cmp-sum"><b>%d / %d</b> 页已实现（其中 %d 页有真机截图），'
               '<b>%d</b> 页未做</div>' % (done, len(PAGES), shot_count, len(PAGES) - done))  # 一句话结论
    return '<div class="cmp">%s%s%s%s</div>' % (summary, head, "".join(rows), "".join(extra_rows))  # 拼起来


def build_html(items, notes, stats, shots, run_id, progress):  # 拼 HTML
    summary = stage_summary(items)  # 阶段汇总
    total_all = len(items)  # 条目总数
    open_all = sum(len(s["open"]) for s in summary.values())  # 明确未完成的条目数
    stage_done = sum(1 for v in progress.values() if v["mark"] == "✅")  # 代码完成的阶段数
    stage_doing = sum(1 for v in progress.values() if v["mark"] == "🔄")  # 进行中的阶段数
    stage_todo = sum(1 for v in progress.values() if v["mark"] == "⬜")  # 未开始的阶段数

    kpi = [  # 顶部四个数字
        ("源码文件", str(stats["files"]), "个 Swift 文件"),
        ("源码行数", "%d" % stats["lines"], "行，每行都有尾注释"),
        ("单元测试", "%d" % stats["methods"], "%d 个断言" % stats["asserts"]),
        ("阶段进度", "%d / %d" % (stage_done, len(progress)), "%d 个进行中，%d 个未开始" % (stage_doing, stage_todo)),
    ]

    kpi_html = "".join(  # KPI 卡
        '<div class="kpi"><div class="kpi-v">%s</div><div class="kpi-k">%s</div><div class="kpi-d">%s</div></div>' % (v, k, d)
        for k, v, d in kpi
    )

    cmp_block = compare_html(shots, run_id)  # 样板与 iOS 的对照表

    stage_rows = []  # 阶段表行
    for no in sorted(summary):  # 按阶段号
        s = summary[no]  # 该阶段条目统计
        info = progress.get(no, {"mark": "?", "text": "未标注", "evidence": ""})  # 阶段状态原词
        mark = info["mark"]  # 标记
        color = MARK_COLOR.get(mark, "#8a94a6")  # 颜色
        width = MARK_WIDTH.get(mark, 8)  # 进度条长度（示意）
        open_html = ""  # 缺口
        if s["open"]:  # 有明确未完成的条目
            open_html = '<div class="todo">差：%s</div>' % "；".join(s["open"][:5])  # 最多列五条
        elif s["unknown"]:  # 表里没标状态，但阶段状态词说了不算完成
            open_html = '<div class="todo">清单未逐条标注状态（%d 条），以阶段状态为准</div>' % s["unknown"]  # 如实说明
        note_html = ""  # 说明文字
        for note in notes.get(no, []):  # 该阶段的说明
            text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", note)  # 去掉 markdown 加粗标记
            note_html += '<div class="note">%s</div>' % text  # 逐条拼
        stage_rows.append(  # 一行
            '<div class="stage">'
            '<div class="stage-h"><span class="dot" style="background:%s"></span>'
            '<span class="stage-n">阶段 %d</span><span class="stage-t">%s</span>'
            '<span class="stage-p">%s</span></div>'
            '<div class="bar"><i style="width:%d%%;background:%s"></i></div>'
            '%s%s</div>' % (color, no, STAGE_CN.get(no, ""), info["text"], width, color, open_html, note_html)
        )

    shot_html = ""  # 截图块
    if shots:  # 有图
        base = os.path.relpath(SHOTS, os.path.dirname(OUT)).replace("\\", "/")  # 相对 docs/ 的路径
        for path in shots:  # 逐张
            name = os.path.splitext(os.path.basename(path))[0]  # 文件名（即 Tab 名）
            label = TAB_CN.get(name, name)  # 中文名
            desc = TAB_DESC.get(name, "")  # 说明
            src = "%s/%s/%s" % (base, run_id, os.path.basename(path))  # 图片地址
            shot_html += (  # 一张卡
                '<figure class="shot"><a href="%s" target="_blank"><img src="%s" alt="%s" loading="lazy"></a>'
                '<figcaption><b>%s</b><span>%s</span></figcaption></figure>' % (src, src, label, label, desc)
            )  # 卡片结束
    else:  # 没图
        shot_html = ('<div class="empty">还没有截图。<br>'
                     'CI 跑完后执行 <code>python tools/pull_shots.py</code> 把图拉回来，'
                     '再重跑本脚本。</div>')  # 引导文案

    run_text = ("运行 #%s" % run_id) if run_id else "尚未取到截图"  # 截图来源

    html = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>复试专 · 项目看板</title>
<style>
:root{--bg:#f5f6f8;--card:#fff;--line:#e6e8ec;--t1:#1a1d24;--t2:#5b6472;--t3:#8a94a6;--brand:#2b54e8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--t1);font:15px/1.6 -apple-system,"PingFang SC","Microsoft YaHei",system-ui,sans-serif}
.wrap{max-width:1240px;margin:0 auto;padding:28px 20px 60px}
h1{font-size:24px;margin:0 0 6px}
.sub{color:var(--t2);font-size:13px;margin-bottom:22px}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:26px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px 18px}
.kpi-v{font-size:26px;font-weight:700;letter-spacing:-.5px}
.kpi-k{font-size:13px;color:var(--t2);margin-top:2px}
.kpi-d{font-size:12px;color:var(--t3);margin-top:6px}
.cols{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:22px}
.cmp-panel{margin-bottom:22px}
.cmp-sum{font-size:13px;color:var(--t2);margin-bottom:8px}
.cmp-sum b{color:var(--t1);font-size:15px}
.cmp-head,.cmp-row{display:grid;grid-template-columns:132px 138px minmax(0,1fr) 64px;gap:12px;align-items:center;padding:9px 0;border-top:1px solid var(--line);font-size:13px}
.cmp-head{border-top:0;color:var(--t3);font-size:11.5px;padding:0 0 6px}
.cmp-name{font-weight:600}
.cmp-dot{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:6px;vertical-align:middle}
.cmp-impl code{font-size:12px}
.sub2{font-size:11.5px;color:var(--t3);margin-top:2px}
.thumb{width:56px;border:1px solid var(--line);border-radius:8px;display:block;aspect-ratio:9/19.5;object-fit:cover;object-position:top}
.nosshot{color:var(--t3);font-size:12px}
.cmp-row.extra{background:#f7f9ff}
.panel{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px}
.panel h2{font-size:15px;margin:0 0 4px}
.panel .hint{font-size:12px;color:var(--t3);margin-bottom:16px}
.stage{padding:12px 0;border-top:1px solid var(--line)}
.stage:first-of-type{border-top:0}
.stage-h{display:flex;align-items:center;gap:8px;font-size:14px}
.dot{width:8px;height:8px;border-radius:50%;flex:0 0 8px}
.stage-n{color:var(--t3);font-size:12px}
.stage-t{font-weight:600}
.stage-p{margin-left:auto;color:var(--t2);font-size:11.5px;text-align:right;max-width:56%;line-height:1.35}
.bar{height:6px;background:#eef0f4;border-radius:99px;margin:8px 0 0;overflow:hidden}
.bar i{display:block;height:100%;border-radius:99px}
.todo{font-size:12.5px;color:#c2410c;margin-top:6px}
.note{font-size:12.5px;color:var(--t2);margin-top:6px}
.shots{display:grid;grid-template-columns:repeat(auto-fill,minmax(148px,1fr));gap:14px}
.shot{margin:0}
.shot img{width:100%;border:1px solid var(--line);border-radius:12px;display:block;background:#eef0f4;aspect-ratio:9/19.5;object-fit:cover;object-position:top}
.shot figcaption{font-size:12px;color:var(--t2);margin-top:6px;display:flex;flex-direction:column}
.shot figcaption b{color:var(--t1);font-size:13px}
.empty{color:var(--t2);font-size:13px;padding:30px 0;text-align:center;line-height:1.9}
code{background:#eef0f4;padding:1px 5px;border-radius:4px;font-size:12px}
@media(max-width:900px){.cols{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(2,1fr)}}
</style></head><body><div class="wrap">
<h1>复试专 · 项目看板</h1>
<div class="sub">生成于 __TIME__ ｜ 对应提交 __HEAD__ ｜ 截图来源 __RUN__</div>
<div class="kpis">__KPI__</div>
<div class="panel cmp-panel"><h2>样板 18 页 → iOS 实况</h2>
<div class="hint">左边是 Web 样板（完整预想形态，能点）／右边是 iOS 真 App。状态由脚本检查源文件是否真实存在得出，不是手填；有截图的可以点开看真机画面</div>
__COMPARE__</div>
<div class="cols">
  <div class="panel"><h2>做到哪了</h2><div class="hint">状态从 docs/01-开发清单.md 解析，非手填；橙色"差"是清单里仍标 ⬜ 的条目</div>__STAGES__</div>
  <div class="panel"><h2>长什么样</h2><div class="hint">CI 在 iPhone 模拟器上真机启动后截的图，点开看大图</div><div class="shots">__SHOTS__</div></div>
</div></div></body></html>"""  # 模板

    html = html.replace("__TIME__", datetime.now().strftime("%Y-%m-%d %H:%M"))  # 生成时间
    html = html.replace("__HEAD__", git_head())  # 提交号
    html = html.replace("__RUN__", run_text)  # 截图来源
    html = html.replace("__KPI__", kpi_html)  # KPI
    html = html.replace("__COMPARE__", cmp_block)  # 对照表
    html = html.replace("__STAGES__", "".join(stage_rows))  # 阶段
    html = html.replace("__SHOTS__", shot_html)  # 截图
    return html  # 返回


def inline_shots(html):  # 把 <img src="shots/..."> 换成内嵌的 base64
    # 为什么需要：本地看板引用的是相对路径，单独拷走一个 HTML 图片会全丢；
    # 内嵌之后整个看板就是一个文件，微信传、拷 U 盘、放到别的电脑都能直接看。
    def repl(match):  # 单个替换
        rel = match.group(1)  # 形如 shots/41560012360/today.png
        path = os.path.join(ROOT, "docs", rel.replace("/", os.sep))  # 换成真实路径
        if not os.path.isfile(path):  # 图不存在
            return match.group(0)  # 原样保留，宁可缺图也不要生成坏 base64
        with open(path, "rb") as f:  # 读原始字节
            b64 = base64.b64encode(f.read()).decode("ascii")  # 转 base64
        return 'src="data:image/png;base64,%s"' % b64  # 换成内嵌地址
    return re.sub(r'src="(shots/[^"]+\.png)"', repl, html)  # 只替换 img 的 src，不动 a 的 href


def main():  # 主流程
    text = read_doc()  # 读清单
    items = parse_items(text)  # 解析条目
    notes = parse_notes(text)  # 解析说明
    progress = parse_progress(text)  # 解析阶段状态
    stats = code_stats()  # 统计代码
    run_id, shots = latest_shots()  # 找截图
    html = build_html(items, notes, stats, shots, run_id, progress)  # 生成
    with open(OUT, "w", encoding="utf-8") as f:  # 写文件
        f.write(html)  # 写入
    single = inline_shots(html)  # 生成图片内嵌版本
    with open(OUT_SINGLE, "w", encoding="utf-8") as f:  # 写单文件版
        f.write(single)  # 写入
    os.makedirs(PUB_DIR, exist_ok=True)  # 发布目录不存在就建
    with open(PUB_INDEX, "w", encoding="utf-8") as f:  # 写发布入口
        f.write(single)  # 同样的自包含内容，放到 index.html 供公网访问
    print("看板已生成：%s" % OUT)  # 提示路径
    print("  条目 %d 条（明确未完成 %d），阶段 %d 个，截图 %d 张（来源 %s）" % (
        len(items), sum(len(s["open"]) for s in stage_summary(items).values()), len(progress), len(shots), run_id or "无"))  # 概况
    print("  源码 %d 文件 / %d 行；测试 %d 方法 / %d 断言" % (stats["files"], stats["lines"], stats["methods"], stats["asserts"]))  # 代码事实


if __name__ == "__main__":  # 直接运行
    main()  # 执行
