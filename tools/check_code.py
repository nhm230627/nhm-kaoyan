# -*- coding: utf-8 -*-
"""静态检查：行注释覆盖率 + 括号配平。 // 校验每行代码是否带尾部注释、大括号是否配平（本机可跑，无需 Mac）"""
import io  # 读文件
import os  # 走目录
import sys  # 取参数

SWIFT_EXTS = ('.swift',)  # Swift 源码后缀
JS_EXTS = ('.mjs', '.js', '.ts')  # 服务端源码后缀


def strip_quoted(line):
    """把字符串字面量的内容替换成空格，避免里面的 // 被当成注释。 // 返回值仍保持原长度，便于定位"""
    out = []  # 结果字符
    quote = None  # 当前引号类型
    i = 0  # 游标
    while i < len(line):  # 逐字符扫描
        ch = line[i]  # 当前字符
        if quote:  # 正在字符串里
            if ch == '\\':  # 转义符
                out.append(' ')  # 转义内容抹掉
                if i + 1 < len(line):  # 还有下一个字符
                    out.append(' ')  # 一起抹掉
                i += 2  # 跳过两个
                continue  # 继续扫描
            if ch == quote:  # 字符串结束
                quote = None  # 退出字符串
            out.append(' ')  # 内容抹成空格
            i += 1  # 前进
            continue  # 继续扫描
        if ch in ('"', "'"):  # 进入字符串
            quote = ch  # 记住引号类型
            out.append(' ')  # 引号本身也抹掉
            i += 1  # 前进
            continue  # 继续扫描
        out.append(ch)  # 普通字符保留
        i += 1  # 前进
    return ''.join(out)  # 返回等长脱敏结果


def has_trailing_comment(line):
    """判断一行是否带尾部注释（// 前面必须有空格，且不在字符串内）。 // 返回 True 表示已注释"""
    bare = strip_quoted(line)  # 去掉字符串内容
    idx = bare.find('//')  # 找注释起点
    while idx != -1:  # 逐个候选位置试
        if idx == 0:  # 整行就是注释
            return True  # 算已注释
        if bare[idx - 1] == ' ':  # 注释前有空格（排除 URL 里的 //）
            return True  # 算已注释
        idx = bare.find('//', idx + 2)  # 继续往后找
    return False  # 没找到合法注释


def analyse(path):
    """统计单文件：代码行数 / 已注释行数 / 缺口行号 / 括号差值。 // 返回 dict"""
    with io.open(path, 'r', encoding='utf-8') as f:  # 打开文件
        lines = f.read().split('\n')  # 拆行
    code_total = 0  # 代码行计数
    code_done = 0  # 已注释代码行计数
    missing = []  # 缺注释行号
    brace = 0  # 大括号差值
    paren = 0  # 小括号差值
    bracket = 0  # 中括号差值
    in_block = False  # 是否正处在三引号多行字符串里
    for no, raw in enumerate(lines, 1):  # 逐行处理
        s = raw.strip()  # 去掉首尾空白
        if s == '"""':  # 多行字符串的边界行（LegalView 的条款正文就是这种写法）
            in_block = not in_block  # 进入或离开块
            continue  # 边界行本身不计入，它不是代码也不缺注释
        if in_block:  # 块内的每一行都是产品文案
            continue  # 文案上加 // 会变成正文，所以整块跳过，括号也不统计
        if not s:  # 空行跳过
            continue  # 不计入
        if s.startswith('//') or s.startswith('*') or s.startswith('/*'):  # 纯注释行跳过
            continue  # 不计入
        bare = strip_quoted(raw)  # 脱敏后做括号统计
        brace += bare.count('{') - bare.count('}')  # 累计大括号
        paren += bare.count('(') - bare.count(')')  # 累计小括号
        bracket += bare.count('[') - bare.count(']')  # 累计中括号
        code_total += 1  # 计入代码行
        if has_trailing_comment(raw):  # 有尾部注释
            code_done += 1  # 计入已完成
        else:  # 缺注释
            missing.append(no)  # 记录行号
    return {'code': code_total, 'done': code_done, 'missing': missing,
            'brace': brace, 'paren': paren, 'bracket': bracket}  # 汇总


def walk(root, exts):
    """递归收集指定后缀的文件。 // 返回路径列表"""
    found = []  # 结果列表
    for base, _, files in os.walk(root):  # 遍历目录
        if '.build' in base or 'DerivedData' in base:  # 跳过构建产物
            continue  # 不处理
        for name in files:  # 逐文件
            if name.endswith(exts):  # 后缀匹配
                found.append(os.path.join(base, name))  # 收进来
    return sorted(found)  # 稳定排序


def report(title, files):
    """打印一组文件的检查结果。 // 返回失败数"""
    print('=' * 66)  # 分隔线
    print(title)  # 标题
    print('=' * 66)  # 分隔线
    bad = 0  # 失败文件数
    for p in files:  # 逐文件
        r = analyse(p)  # 统计
        rel = os.path.relpath(p, 'D:/APP')  # 相对路径
        balanced = (r['brace'] == 0 and r['paren'] == 0 and r['bracket'] == 0)  # 括号是否配平
        ok = (r['done'] == r['code']) and balanced  # 是否整体合格
        if not ok:  # 不合格
            bad += 1  # 计数
        flag = 'OK ' if ok else 'NG '  # 标记
        print('%s %-58s %3d/%-3d  {}=%+d ()=%+d []=%+d'
              % (flag, rel, r['done'], r['code'], r['brace'], r['paren'], r['bracket']))  # 一行结果
        if r['missing']:  # 有缺注释
            print('     缺注释行：%s' % ','.join(str(n) for n in r['missing'][:40]))  # 列出行号
    print('-' * 66)  # 分隔线
    print('文件数 %d，不合格 %d' % (len(files), bad))  # 汇总
    return bad  # 返回失败数


def main():
    """入口：跑 iOS 与服务端两组检查。 // 退出码非 0 表示有问题"""
    swift = walk('D:/APP/app/FuShiZhuan', SWIFT_EXTS)  # iOS 源码
    tests = walk('D:/APP/app/FuShiZhuanTests', SWIFT_EXTS)  # 单元测试也适用同一条注释规则
    js = walk('D:/APP/server', JS_EXTS)  # 服务端源码
    js = [p for p in js if 'node_modules' not in p]  # 排除依赖
    total_bad = report('iOS（Swift）注释覆盖率 + 括号配平', swift)  # 第一组
    total_bad += report('iOS 单元测试（Swift）注释覆盖率 + 括号配平', tests)  # 第二组
    total_bad += report('BFF（Node）注释覆盖率 + 括号配平', js)  # 第三组
    sys.exit(0 if total_bad == 0 else 1)  # 返回退出码


main()  # 执行
