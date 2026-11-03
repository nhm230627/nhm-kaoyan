#!/usr/bin/env python
# 用 GitHub REST API 提交本地改动，绕开被墙/超时的 github.com:443
#
# 为什么需要它：git push 走的是 github.com 的 HTTPS 端口，网络抽风时会直接超时；
# 而 api.github.com 往往还能通。这个脚本用 Git Data API 手工造一个提交，
# 效果等同于 push：远程多一个 commit，文件内容完全一致。
#
# 局限（必须知道）：
#   1) 它只做「新增一个提交」，不做合并、不做 rebase；
#   2) 用完之后本地和远程的 commit SHA 会不一样（内容一样），
#      等网络恢复后要执行 `git fetch origin && git reset --hard origin/main` 对齐；
#   3) 只支持修改/新增文件，不支持删除文件。

import base64  # 把文件内容转成 API 要的 base64
import json  # 构造与解析 JSON
import os  # 拼接路径
import re  # 提取 Token
import sys  # 读写命令行参数、退出码
import urllib.request  # 发 HTTP 请求

ROOT = r"D:\APP"  # 项目根目录
OWNER = "nhm230627"  # 仓库所有者
REPO = "nhm-kaoyan"  # 仓库名
BRANCH = "main"  # 目标分支
BASE = "https://api.github.com/repos/%s/%s" % (OWNER, REPO)  # API 基地址


def load_token():  # 从 token.txt 里取出 Token
    raw = open(os.path.join(ROOT, "token.txt"), "rb").read()  # 按字节读
    text = raw.decode("utf-8-sig", errors="replace")  # 去掉可能存在的 BOM
    hit = re.search(r"gh[pousr]_[A-Za-z0-9]{20,}", text)  # 只认 ghp_ 开头
    if not hit:  # 找不到就直接失败
        print("token.txt 里没有可用的 Token")  # 说明原因
        sys.exit(2)  # 非零退出
    return hit.group(0)  # 返回干净的 Token


TOKEN = load_token()  # 模块级只读一次


def api(method, path, body=None):  # 统一封装一次 API 调用
    url = BASE + path  # 拼出完整地址
    data = json.dumps(body).encode("utf-8") if body is not None else None  # 有体才序列化
    req = urllib.request.Request(url, data=data, method=method)  # 构造请求
    req.add_header("Authorization", "token " + TOKEN)  # 鉴权
    req.add_header("Accept", "application/vnd.github+json")  # 用新版 API
    req.add_header("Content-Type", "application/json")  # 声明请求体类型
    req.add_header("User-Agent", "fushizhuan-push-tool")  # GitHub 要求必须有 UA
    try:  # 捕获 HTTP 错误，把 GitHub 的原文打出来
        with urllib.request.urlopen(req, timeout=40) as resp:  # 发出去并等响应
            raw = resp.read().decode("utf-8")  # 读回文本
    except urllib.error.HTTPError as e:  # 4xx/5xx 时
        detail = e.read().decode("utf-8", errors="replace")  # 读回错误体
        print("HTTP %d on %s %s" % (e.code, method, path))  # 打出出错位置
        print(detail)  # 打出 GitHub 的原始说明
        sys.exit(3)  # 直接退出，别继续往下造提交
    return json.loads(raw) if raw.strip() else {}  # 空体返回空字典


def read_normalized(rel_path):  # 读文件并把换行统一成 LF
    with open(os.path.join(ROOT, rel_path), "rb") as f:  # 以二进制读，避免平台换行干扰
        data = f.read()  # 取出全部字节
    return data.replace(b"\r\n", b"\n")  # 统一成 LF，与 .gitattributes 规则一致


def main():  # 主流程
    if len(sys.argv) < 3:  # 至少要给提交信息与文件列表
        print("用法: python tools/push_via_api.py \"提交信息\" 文件1 文件2 ...")  # 提示用法
        sys.exit(1)  # 参数不足退出
    message = sys.argv[1]  # 第一条参数是提交信息
    paths = sys.argv[2:]  # 其余都是仓库内的相对路径

    ref = api("GET", "/git/ref/heads/" + BRANCH)  # 取当前分支指针
    base_sha = ref["object"]["sha"]  # 当前提交
    base_commit = api("GET", "/git/commits/" + base_sha)  # 取该提交详情
    base_tree = base_commit["tree"]["sha"]  # 取它的树

    tree = []  # 待写入的树条目
    for path in paths:  # 逐个文件上传
        content = read_normalized(path)  # 读入并规范换行
        blob = api("POST", "/git/blobs", {  # 先建 blob
            "content": base64.b64encode(content).decode("ascii"),  # base64 编码
            "encoding": "base64",  # 声明编码方式
        })  # blob 建立结束
        tree.append({"path": path, "mode": "100644", "type": "blob", "sha": blob["sha"]})  # 记到树里
        print("已上传 %s（%d 字节）" % (path, len(content)))  # 打一行进度

    new_tree = api("POST", "/git/trees", {"base_tree": base_tree, "tree": tree})  # 在旧树基础上改
    new_commit = api("POST", "/git/commits", {  # 造一个新提交
        "message": message,  # 提交信息
        "tree": new_tree["sha"],  # 新树
        "parents": [base_sha],  # 父提交是原来的头
    })  # 提交建立结束
    api("PATCH", "/git/refs/heads/" + BRANCH, {"sha": new_commit["sha"], "force": False})  # 移动分支指针

    print("\n提交成功")  # 提示成功
    print("  新提交: " + new_commit["sha"])  # 打出 SHA
    print("  对比:   https://github.com/%s/%s/commit/%s" % (OWNER, REPO, new_commit["sha"]))  # 网页地址
    print("\n注意：本地 SHA 与远程已不一致（内容相同）。网络恢复后执行：")  # 提醒后续动作
    print("  git fetch origin && git reset --hard origin/main")  # 对齐命令


if __name__ == "__main__":  # 直接运行时
    main()  # 进主流程
