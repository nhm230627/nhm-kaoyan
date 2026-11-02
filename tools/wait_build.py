#!/usr/bin/env python
# 盯 GitHub Actions 编译进度，跑完把结果和报错原文打出来
# 用法：python tools/wait_build.py [run_id]，不给 run_id 就取最新一次

import json  # 解析接口返回的 JSON
import os  # 取当前工作目录
import re  # 正则提取 Token 和报错行
import subprocess  # 调 curl，避免 urllib 在 302 跳转时把 Authorization 带给 S3
import sys  # 读命令行参数
import time  # 轮询间隔

ROOT = r"D:\APP"  # 项目根目录
API = "https://api.github.com/repos/nhm230627/nhm-kaoyan"  # 仓库 API 基地址
MAX_WAIT = 40  # 最多轮询 40 次
INTERVAL = 15  # 每次间隔 15 秒，合计 10 分钟


def load_token():  # 从 token.txt 里抽出 Token，容忍记事本留下的多余文字
    raw = open(os.path.join(ROOT, "token.txt"), "rb").read()  # 按字节读，防止编码报错
    text = raw.decode("utf-8-sig", errors="replace")  # 去掉 BOM 再转字符串
    hit = re.search(r"gh[pousr]_[A-Za-z0-9]{20,}", text)  # 只认 ghp_ 开头的串
    if not hit:  # 没找到就说明文件内容不对
        print("token.txt 里没有找到 Token")  # 提示原因
        sys.exit(2)  # 用非零码退出
    return hit.group(0)  # 返回干净的 Token


def curl_json(url, token):  # 带鉴权拿一份 JSON
    out = subprocess.run(  # 起一个 curl 进程
        ["curl", "-s", "-m", "25", "-H", "Authorization: token " + token, url],  # 只发必要的头
        capture_output=True,  # 把输出收进变量而不是打到屏幕
    )  # 命令结束
    body = out.stdout.decode("utf-8", errors="replace")  # 统一按 utf-8 解码
    try:  # 接口正常时应该是 JSON
        return json.loads(body)  # 解析成字典
    except json.JSONDecodeError:  # 网络异常时会拿到空串或 HTML
        return {"_raw": body[:300]}  # 原样带回便于排查


def fetch_log_text(job_id, token):  # 下载某个 job 的完整日志
    url = API + "/actions/jobs/" + str(job_id) + "/logs"  # 日志接口，会 302 到 S3
    head = subprocess.run(  # 第一步：拿跳转地址
        ["curl", "-s", "-m", "25", "-o", "/dev/null", "-w", "%{redirect_url}",  # 只要 Location
         "-H", "Authorization: token " + token, url],  # 这一步必须带鉴权
        capture_output=True,  # 收输出
    )  # 命令结束
    location = head.stdout.decode("utf-8", errors="replace").strip()  # 去掉换行
    if not location.startswith("http"):  # 没拿到地址说明接口没给跳转
        return ""  # 返回空串，后面会打印「日志取不到」
    body = subprocess.run(  # 第二步：不带鉴权直接拉文件，否则 S3 会拒绝
        ["curl", "-sL", "-m", "60", location],  # -L 跟着跳转走
        capture_output=True,  # 收输出
    )  # 命令结束
    return body.stdout.decode("utf-8", errors="replace")  # 返回纯文本日志


def main():  # 主流程
    token = load_token()  # 先拿 Token
    run_id = sys.argv[1] if len(sys.argv) > 1 else None  # 支持指定某一次运行
    if not run_id:  # 没指定就查最新一次
        data = curl_json(API + "/actions/runs?per_page=1", token)  # 只要最新一条
        runs = data.get("workflow_runs", [])  # 取出运行列表
        if not runs:  # 一次都没有说明工作流没触发
            print("还没有任何运行记录，去 Actions 页面看是否需要手动启用工作流")  # 给出方向
            sys.exit(3)  # 非零退出
        run_id = runs[0]["id"]  # 记下编号

    for i in range(MAX_WAIT):  # 最多盯 40 轮
        data = curl_json(API + "/actions/runs/" + str(run_id), token)  # 查这次运行的状态
        status = data.get("status")  # queued / in_progress / completed
        conclusion = data.get("conclusion")  # 只有 completed 才有值
        print("第 %d 次查询：%s / %s" % (i + 1, status, conclusion), flush=True)  # 实时打印进度
        if status == "completed":  # 跑完了就往下走
            break  # 跳出轮询
        time.sleep(INTERVAL)  # 没跑完就等一会
    else:  # 循环走完还在跑
        print("等了 10 分钟还没结束，去网页上看吧：" + data.get("html_url", ""))  # 给网页地址
        sys.exit(4)  # 非零退出

    print("\n===== 结果 =====")  # 分隔线
    print("结论:", conclusion)  # success / failure / cancelled
    print("地址:", data.get("html_url"))  # 方便点进去看
    jobs = curl_json(API + "/actions/runs/" + str(run_id) + "/jobs", token)  # 查这次运行包含哪些 job
    for job in jobs.get("jobs", []):  # 正常只有一个 job
        print("\n--- job:", job.get("name"), "/", job.get("conclusion"), "---")  # job 概况
        for step in job.get("steps", []):  # 逐个步骤看结果
            print("  [%s] %s" % (step.get("conclusion"), step.get("name")))  # 哪一步挂了
        if job.get("conclusion") != "success":  # 只有失败才去拉日志
            log = fetch_log_text(job.get("id"), token)  # 下载完整日志
            if not log:  # 拉不到就告知
                print("  （日志没取到，请到网页上查看）")  # 兜底提示
                continue  # 跳过后面解析
            bad = [ln for ln in log.splitlines() if ln.strip().startswith("error:")  # 只挑编译错误
                   or " error: " in ln  # 有些错误前面带文件路径
                   or ln.strip().startswith("xcodebuild: error")]  # xcodebuild 自身报错
            print("\n===== 编译错误（共 %d 条）=====" % len(bad))  # 报错条数
            for ln in bad[:60]:  # 最多打 60 条，避免刷屏
                print(ln.strip()[:300])  # 每条截到 300 字
            if not bad:  # 没有 error: 说明挂在别的步骤
                print("没有匹配到 error: 行，下面是日志最后 40 行：")  # 说明原因
                for ln in log.splitlines()[-40:]:  # 打印尾部
                    print(ln[:300])  # 截断长行


if __name__ == "__main__":  # 直接运行脚本时
    main()  # 进主流程
