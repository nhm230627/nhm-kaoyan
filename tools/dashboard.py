#!/usr/bin/env python
# 生成一页「项目进度看板」HTML：左边每个模块做到哪，右边最近一次 CI 跑出来的真机截图
#
# 为什么需要它：此前所有进度都躺在 docs/*.md 里，用户要翻五个文档才知道"现在到哪了"，
# 而且看不到 App 长什么样。这个脚本把两件事合成一页：
#   1) 阶段与条目状态 —— 从 01-开发清单.md 里解析，不手填，避免看板与实际漂移；
#   2) 截图 —— 从 docs/shots/ 里读 CI 下载回来的 PNG。
# 产出 docs/dashboard.html，双击就能看，可以随时重跑。

import glob  # 找文件
import os  # 路径处理
import re  # 解析 markdown
import subprocess  # 调 git 拿提交号
from datetime import datetime  # 生成时间

ROOT = r"D:\APP"  # 项目根目录
DOC = os.path.join(ROOT, "docs", "01-开发清单.md")  # 清单文档
SHOTS = os.path.join(ROOT, "docs", "shots")  # 截图目录
OUT = os.path.join(ROOT, "docs", "dashboard.html")  # 输出文件

TAB_CN = {"today": "今日", "quiz": "刷题", "interview": "面试", "companion": "伙伴", "profile": "我的"}  # Tab 英文名转中文
TAB_DESC = {  # 每张图看什么
    "today": "倒计时 / 今日概览 / 任务",
    "quiz": "章节列表 / 关卡星级",
    "interview": "考官构成 / 考场设置",
    "companion": "3D 宠物 / 投喂",
    "profile": "统计 / 成长溯源 / 重置",
}

STAGE_CN = {  # 阶段名，与清单保持一致
    0: "环境与工程骨架",
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
<div class="cols">
  <div class="panel"><h2>做到哪了</h2><div class="hint">状态从 docs/01-开发清单.md 解析，非手填；橙色"差"是清单里仍标 ⬜ 的条目</div>__STAGES__</div>
  <div class="panel"><h2>长什么样</h2><div class="hint">CI 在 iPhone 模拟器上真机启动后截的图，点开看大图</div><div class="shots">__SHOTS__</div></div>
</div></div></body></html>"""  # 模板

    html = html.replace("__TIME__", datetime.now().strftime("%Y-%m-%d %H:%M"))  # 生成时间
    html = html.replace("__HEAD__", git_head())  # 提交号
    html = html.replace("__RUN__", run_text)  # 截图来源
    html = html.replace("__KPI__", kpi_html)  # KPI
    html = html.replace("__STAGES__", "".join(stage_rows))  # 阶段
    html = html.replace("__SHOTS__", shot_html)  # 截图
    return html  # 返回


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
    print("看板已生成：%s" % OUT)  # 提示路径
    print("  条目 %d 条（明确未完成 %d），阶段 %d 个，截图 %d 张（来源 %s）" % (
        len(items), sum(len(s["open"]) for s in stage_summary(items).values()), len(progress), len(shots), run_id or "无"))  # 概况
    print("  源码 %d 文件 / %d 行；测试 %d 方法 / %d 断言" % (stats["files"], stats["lines"], stats["methods"], stats["asserts"]))  # 代码事实


if __name__ == "__main__":  # 直接运行
    main()  # 执行
