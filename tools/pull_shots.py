#!/usr/bin/env python
# 把 GitHub Actions 最新一次运行产出的截图（artifact）下载到本机
#
# 为什么需要它：CI 在云上跑完，图存在 GitHub 的 artifact 里，网页上要登录点好几层才能下。
# 这个脚本一次把图抓到 docs/shots/<run号>/ 下，供本地看板 HTML 直接引用。
#
# 局限：
#   1) 只抓「最近一次」运行，不按时间范围批量抓；
#   2) artifact 默认 90 天过期，过期后要重跑 CI 才有图。

import io  # 把二进制当文件流处理
import json  # 解析 API 返回
import os  # 路径拼接
import re  # 提取 Token
import sys  # 退出码
import urllib.error  # 捕获 HTTPError（302 会以异常形式抛出来）
import urllib.request  # 发 HTTP 请求
import zipfile  # 解压 artifact

ROOT = r"D:\APP"  # 项目根目录
OWNER = "nhm230627"  # 仓库所有者
REPO = "nhm-kaoyan"  # 仓库名
BASE = "https://api.github.com/repos/%s/%s" % (OWNER, REPO)  # API 基地址
OUT_DIR = os.path.join(ROOT, "docs", "shots")  # 截图落地目录


def load_token():  # 从 token.txt 取 Token
    raw = open(os.path.join(ROOT, "token.txt"), "rb").read()  # 按字节读
    text = raw.decode("utf-8-sig", errors="replace")  # 去掉可能的 BOM
    hit = re.search(r"gh[pousr]_[A-Za-z0-9]{20,}", text)  # 只认 PAT 前缀
    if not hit:  # 找不到就退出
        print("token.txt 里没有可用的 Token")  # 说明原因
        sys.exit(2)  # 非零退出
    return hit.group(0)  # 返回干净 Token


TOKEN = load_token()  # 只读一次


def api(path):  # 带鉴权的 GET，返回解析后的 JSON
    req = urllib.request.Request(BASE + path)  # 拼地址
    req.add_header("Authorization", "token " + TOKEN)  # 鉴权
    req.add_header("Accept", "application/vnd.github+json")  # 指定版本
    with urllib.request.urlopen(req, timeout=30) as resp:  # 发请求
        return json.loads(resp.read().decode("utf-8"))  # 解析 JSON


def latest_run():  # 取最近一次运行
    data = api("/actions/runs?per_page=1")  # 只取一条
    runs = data.get("workflow_runs") or []  # 取列表
    if not runs:  # 一次都没跑过
        print("还没有任何 CI 运行记录")  # 说明原因
        sys.exit(3)  # 非零退出
    return runs[0]  # 最新那条


def find_artifact(run_id):  # 在该运行里找截图 artifact
    data = api("/actions/runs/%s/artifacts" % run_id)  # 列出产物
    for item in data.get("artifacts") or []:  # 逐个看
        if item.get("name") == "app-screenshots":  # 名字对上
            return item  # 命中
    return None  # 没有就返回 None


def download_zip(artifact_id):  # 下载 artifact 的 zip 字节
    # 坑（2026-11-03 踩）：GitHub 对 zip 下载返回 302 跳到 S3 预签名地址，
    # 如果让 urllib 自动跟跳转，它会连 Authorization 头一起带过去，
    # S3 看到 GitHub 的 token 会算签名不匹配，直接 403。
    # 所以必须分两步：先只问跳转地址（不带 body），再裸拉 S3。
    url = BASE + "/actions/artifacts/%s/zip" % artifact_id  # 下载地址
    head = urllib.request.Request(url)  # 造请求
    head.add_header("Authorization", "token " + TOKEN)  # 只有这一步带鉴权
    opener = urllib.request.build_opener(NoRedirect)  # 不自动跟跳转
    try:  # 302 会被当成 HTTPError 抛出来
        with opener.open(head, timeout=30) as resp:  # 发请求
            return resp.read()  # 万一没跳转就直接是内容
    except urllib.error.HTTPError as err:  # 预期会走这里
        if err.code not in (301, 302, 303, 307):  # 不是跳转就是真错
            raise  # 抛出去
        location = err.headers.get("Location")  # 取预签名地址
    with urllib.request.urlopen(location, timeout=120) as resp:  # 裸拉，不带任何鉴权
        return resp.read()  # 整个读进内存（图很小，几 MB）


class NoRedirect(urllib.request.HTTPRedirectHandler):  # 禁止自动跟随跳转的处理器
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # 覆盖默认行为
        return None  # 返回 None 表示不重发请求，交给调用方处理


def main():  # 主流程
    run = latest_run()  # 最近一次运行
    run_id = run["id"]  # 运行号
    print("最近一次运行：%s  结论：%s  创建于 %s" % (run_id, run.get("conclusion"), run.get("created_at")))  # 打印概况
    art = find_artifact(run_id)  # 找截图包
    if not art:  # 没有截图包
        print("这次运行没有 app-screenshots 产物（可能编译阶段就失败了）")  # 说明原因
        sys.exit(4)  # 非零退出
    target = os.path.join(OUT_DIR, str(run_id))  # 按运行号建目录
    os.makedirs(target, exist_ok=True)  # 目录不存在就建
    blob = download_zip(art["id"])  # 下载 zip
    with zipfile.ZipFile(io.BytesIO(blob)) as zf:  # 当成 zip 打开
        names = zf.namelist()  # 先看里面有什么
        zf.extractall(target)  # 全部解到目标目录
    print("已解出 %d 个文件 → %s" % (len(names), target))  # 报结果
    for name in sorted(names):  # 逐个列出来
        size = os.path.getsize(os.path.join(target, name))  # 看文件大小
        print("  %-24s %8d 字节" % (name, size))  # 一行一个
    with open(os.path.join(OUT_DIR, "latest.txt"), "w", encoding="utf-8") as f:  # 记住最新一次是哪次
        f.write(str(run_id))  # 只写运行号
    print("最新运行号已写入 docs/shots/latest.txt")  # 提示


if __name__ == "__main__":  # 作为脚本运行
    main()  # 执行
