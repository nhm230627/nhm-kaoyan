# -*- coding: utf-8 -*-
"""静态检查：结构体初始化参数名与顺序。 // Swift 要求实参顺序与声明一致，本机没法编译，只能用脚本兜住这类错"""
import glob  # 遍历文件
import io  # 读文件
import os  # 路径
import re  # 正则
import sys  # 退出码

ROOT = 'D:/APP/app/FuShiZhuan'  # 源码根目录
TEST_ROOT = 'D:/APP/app/FuShiZhuanTests'  # 单元测试根目录，和源码适用同一条参数标签规则
SWIFT = sorted(  # 合并两处的全部 Swift 文件
    glob.glob(os.path.join(ROOT, '**', '*.swift'), recursive=True)  # 源码
    + glob.glob(os.path.join(TEST_ROOT, '**', '*.swift'), recursive=True)  # 测试
)  # 合并结束


def strip_strings(text):
    """把字符串字面量替换成空格，避免引号里的括号与冒号干扰解析。 // 返回等长脱敏文本"""
    out = []  # 结果
    quote = None  # 当前引号
    i = 0  # 游标
    while i < len(text):  # 逐字符
        ch = text[i]  # 当前字符
        if quote:  # 在字符串里
            if ch == '\\':  # 转义
                out.append(' ')  # 抹掉
                if i + 1 < len(text):  # 还有下一个
                    out.append(' ')  # 抹掉
                i += 2  # 跳过
                continue  # 继续
            if ch == quote:  # 结束引号
                quote = None  # 退出
            out.append(' ')  # 抹掉内容
            i += 1  # 前进
            continue  # 继续
        if ch in ('"', "'"):  # 进入字符串
            quote = ch  # 记住
            out.append(' ')  # 抹掉引号
            i += 1  # 前进
            continue  # 继续
        out.append(ch)  # 保留
        i += 1  # 前进
    return ''.join(out)  # 返回


def read(path):
    """读文件并脱敏。 // 返回脱敏后的全文"""
    return strip_strings(io.open(path, encoding='utf-8').read())


def match_brace(text, start):
    """从 start 处的 { 找到配对的 }，返回其下标。 // 用于切出一个块"""
    depth = 0  # 深度
    for i in range(start, len(text)):  # 往后扫
        if text[i] == '{':  # 开
            depth += 1  # 加一
        elif text[i] == '}':  # 闭
            depth -= 1  # 减一
            if depth == 0:  # 配平了
                return i  # 返回下标
    return -1  # 没找到


def declared_params(body):
    """从一个 struct 体里取参数顺序：优先用显式 init，否则用存储属性。 // 返回标签列表"""
    init_at = body.find('init(')  # 显式构造器
    if init_at != -1:  # 有显式构造器
        open_at = body.find('(', init_at)  # 参数表起点
        close_at = match_paren(body, open_at)  # 参数表终点
        if close_at != -1:  # 找到了
            return labels_of(body[open_at + 1:close_at])  # 取标签
    names = []  # 存储属性名
    for line in body.split('\n'):  # 逐行
        s = line.strip()  # 去空白
        m = re.match(r'(?:let|var)\s+(\w+)\s*:', s)  # 取 let/var 名
        if m:  # 命中
            names.append(m.group(1))  # 记下
    return names  # 返回


def match_paren(text, start):
    """从 start 处的 ( 找到配对的 )。 // 返回下标"""
    depth = 0  # 深度
    for i in range(start, len(text)):  # 往后扫
        if text[i] == '(':  # 开
            depth += 1  # 加一
        elif text[i] == ')':  # 闭
            depth -= 1  # 减一
            if depth == 0:  # 配平
                return i  # 返回
    return -1  # 没找到


def split_top(text):
    """按顶层逗号切分参数表。 // 返回片段列表"""
    parts = []  # 结果
    depth = 0  # 括号深度
    buf = []  # 当前片段
    for ch in text:  # 逐字符
        if ch in '([{':  # 进入嵌套
            depth += 1  # 加一
        elif ch in ')]}':  # 离开嵌套
            depth -= 1  # 减一
        if ch == ',' and depth == 0 and ch not in '([{':  # 顶层逗号
            parts.append(''.join(buf))  # 收一个
            buf = []  # 清空
            continue  # 继续
        buf.append(ch)  # 收字符
    if buf:  # 最后一段
        parts.append(''.join(buf))  # 收进来
    return parts  # 返回


def labels_of(param_text):
    """从参数表里取出标签名（label: 形式）。 // 返回列表"""
    out = []  # 结果
    for seg in split_top(param_text):  # 逐段
        m = re.match(r'\s*(\w+)\s*:', seg)  # 形如 name:
        if m:  # 命中
            out.append(m.group(1))  # 记下
    return out  # 返回


def collect_structs():
    """扫描全部文件，收集 struct 名与声明顺序。 // 返回 dict"""
    table = {}  # name -> params
    for path in SWIFT:  # 逐文件
        text = read(path)  # 读全文
        for m in re.finditer(r'\bstruct\s+(\w+)[^{]*\{', text):  # 找 struct
            name = m.group(1)  # 名字
            open_at = text.rfind('{', m.start(), m.end())  # 起始大括号
            close_at = match_brace(text, open_at)  # 配对
            if close_at == -1:  # 异常
                continue  # 跳过
            params = declared_params(text[open_at:close_at])  # 参数顺序
            if params:  # 有参数才记
                table[name] = params  # 记录
    return table  # 返回


def check_calls(table):
    """检查每个调用点的标签是否存在且顺序一致。 // 返回问题列表"""
    problems = []  # 问题
    for path in SWIFT:  # 逐文件
        text = read(path)  # 读全文
        for name, params in table.items():  # 逐个已知结构
            for m in re.finditer(r'(?<![.\w])' + re.escape(name) + r'\s*\(', text):  # 找调用
                open_at = m.end() - 1  # 左括号位置
                close_at = match_paren(text, open_at)  # 配对
                if close_at == -1:  # 异常
                    continue  # 跳过
                got = labels_of(text[open_at + 1:close_at])  # 实参标签
                if not got:  # 没有标签（位置参数或空）
                    continue  # 跳过
                unknown = [g for g in got if g not in params]  # 不存在的标签
                if unknown:  # 有错名
                    problems.append((path, name, '不存在的参数 %s，声明是 %s' % (unknown, params)))
                    continue  # 下一个
                idx = [params.index(g) for g in got]  # 各标签的声明位置
                if idx != sorted(idx):  # 顺序被打乱
                    problems.append((path, name, '顺序不对：传了 %s，声明是 %s' % (got, params)))
    return problems  # 返回


def main():
    """入口。 // 有问题时退出码 1"""
    table = collect_structs()  # 收集声明
    problems = check_calls(table)  # 检查调用
    print('已知结构体 %d 个，问题 %d 处' % (len(table), len(problems)))  # 汇总
    for path, name, why in problems:  # 逐个打印
        print('NG  %s  %s  %s' % (os.path.relpath(path, 'D:/APP'), name, why))  # 一行一条
    sys.exit(0 if not problems else 1)  # 退出码


main()  # 执行
