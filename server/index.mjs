// ============================================================
// 复试专 BFF 代理服务
// 作用：iOS App 只调这个服务，DeepSeek Key 只存在服务器，客户端拿不到。
// 依赖：Node 18+（自带 fetch），零第三方包。
// 启动：node index.mjs   或双击 start.bat
// ============================================================

import { createServer } from 'node:http'  // 建 HTTP 服务
import { readFileSync, existsSync } from 'node:fs'  // 读密钥文件、判存在
import { fileURLToPath } from 'node:url'  // 取当前文件绝对路径
import { dirname, join } from 'node:path'  // 路径拼接
import { randomUUID } from 'node:crypto'  // 生成请求 id

// ---------- 基础配置 ----------

const __dirname = dirname(fileURLToPath(import.meta.url))  // 当前文件所在目录
const PORT = Number(process.env.PORT || 4318)  // 监听端口，默认 4318
const UPSTREAM = 'https://api.deepseek.com/chat/completions'  // 上游模型接口
const MODEL = process.env.MODEL || 'deepseek-chat'  // 模型名，可环境变量覆盖
const DAILY_LIMIT = Number(process.env.DAILY_LIMIT || 60)  // 每设备每日调用上限
const TIMEOUT_MS = Number(process.env.TIMEOUT_MS || 60000)  // 单次上游超时
const SERVICE_TOKEN = process.env.SERVICE_TOKEN || 'dev-token-change-me'  // 客户端鉴权令牌
const CACHE_TTL_MS = 10 * 60 * 1000  // 幂等缓存保留 10 分钟

// 读密钥：优先环境变量，其次同目录 .key 文件；两者都没有就拒绝启动
function loadKey() {  // 读密钥
  if (process.env.DEEPSEEK_API_KEY) return process.env.DEEPSEEK_API_KEY.trim()  // 环境变量优先
  const file = join(__dirname, '.key')  // 本地密钥文件名
  if (existsSync(file)) return readFileSync(file, 'utf8').trim()  // 文件兜底
  return ''  // 都没有返回空
}  // loadKey 结束

const API_KEY = loadKey()  // 启动时读一次，运行期不变

// ---------- 内存态：限流与幂等 ----------
// 生产环境请换 Redis；单机内存够跑内测，重启即清空。

const usage = new Map()  // deviceId -> { day, count }
const idempotent = new Map()  // requestKey -> { at, payload }

// 每日额度检查：跨天自动归零，超限返回 false
function takeQuota(deviceId) {  // 每日额度检查
  const day = new Date().toISOString().slice(0, 10)  // 当天日期 YYYY-MM-DD
  const rec = usage.get(deviceId)  // 取该设备记录
  if (!rec || rec.day !== day) {  // 第一次或跨天
    usage.set(deviceId, { day, count: 1 })  // 重置为 1 次
    return true  // 放行
  }  // 重置分支结束
  if (rec.count >= DAILY_LIMIT) return false  // 超限拦下
  rec.count += 1  // 计数加一
  return true  // 放行
}  // takeQuota 结束

// 幂等：同一个 key 在 TTL 内重复请求，直接返回首次结果，不重复扣额度
function idempotentGet(key) {  // 查幂等缓存
  const hit = idempotent.get(key)  // 查缓存
  if (!hit) return null  // 没命中
  if (Date.now() - hit.at > CACHE_TTL_MS) {  // 过期
    idempotent.delete(key)  // 清掉
    return null  // 当作没命中
  }  // 过期分支结束
  return hit.payload  // 返回首次结果
}  // idempotentGet 结束

// 写入幂等缓存，并顺手清理过期项，避免 Map 无限增长
function idempotentSet(key, payload) {  // 写幂等缓存
  idempotent.set(key, { at: Date.now(), payload })  // 存结果
  for (const [k, v] of idempotent) {  // 遍历旧项
    if (Date.now() - v.at > CACHE_TTL_MS) idempotent.delete(k)  // 删过期
  }  // 遍历结束
}  // idempotentSet 结束

// ---------- 1V1 配对（纯内存，题目不出服务器） ----------
// 与 AI 接口完全解耦：不调模型、不扣额度，所以鉴权也放在 AI 那套之外。
// 协议照样板 /api/duel/*：join → poll → progress → state。
// 挑战题不进服务端：双方拿同一个 seed，各自用本地题库出同样的题。

const duelWaiting = new Map()  // pid -> 排队项
const duelGames = new Map()  // duelId -> 对局
const DUEL_WAIT_MS = 9000  // 等 9 秒配不上就回 timeout，客户端上 AI 陪练
const DUEL_TTL_MS = 30 * 60 * 1000  // 对局保留 30 分钟，够客户端取完结果

// 清掉过期条目，避免内存无限增长
function pruneDuel() {  // 清理过期
  const now = Date.now()  // 当前时间
  for (const [pid, item] of duelWaiting) {  // 遍历排队
    if (now - item.at > 60000) duelWaiting.delete(pid)  // 排队超 1 分钟作废
  }  // 遍历结束
  for (const [id, game] of duelGames) {  // 遍历对局
    if (now - game.at > DUEL_TTL_MS) duelGames.delete(id)  // 超 30 分钟作废
  }  // 遍历结束
}  // pruneDuel 结束

// 取对手的实时进度，客户端拿它画进度条
function duelFoe(game, pid) {  // 对手状态
  const side = game.pids[pid]  // 我在哪一边
  if (!side) return null  // 不在这场里
  const other = side === 'a' ? game.sides.b : game.sides.a  // 对面那一边
  return { answered: other.answered, correct: other.correct, done: other.done, ms: other.ms }  // 对手数据
}  // duelFoe 结束

// 配对服务路由：全部走内存，重启即清空
async function handleDuel(req, res, path, url) {  // 配对路由
  pruneDuel()  // 先清理过期条目

  if (path === '/api/duel/online' && req.method === 'GET') {  // 在线人数
    const waiting = duelWaiting.size  // 排队中的人数
    const duels = duelGames.size  // 进行中的对局数
    return sendJSON(res, 200, { waiting, duels, online: waiting + duels * 2 })  // 照样板口径返回
  }  // 在线分支结束

  if (path === '/api/duel/join' && req.method === 'POST') {  // 报名匹配
    let body  // 请求体
    try {  // 读请求体
      body = await readBody(req)  // 解析
    } catch (e) {  // 体不合法
      return sendJSON(res, 400, { code: 'badRequest', message: String(e.message) })  // 400
    }  // 分支结束
    const count = Math.max(3, Math.min(50, Number(body.count) || 5))  // 题量 3 到 50
    const track = String(body.track || 'tax').slice(0, 16)  // 考试方向：不同方向题不一样，不能配
    const nick = String(body.nick || '研友').slice(0, 20)  // 昵称
    const school = String(body.school || '').slice(0, 30)  // 院校，可空
    const myPid = randomUUID()  // 本次报名标识

    for (const [pid, item] of duelWaiting) {  // 找一个在等的人
      if (item.count !== count || item.track !== track) continue  // 题量或方向不同就不配
      duelWaiting.delete(pid)  // 配对成功，把我俩都从队列摘掉
      const duelId = randomUUID()  // 对局 id
      const seed = Math.floor(Math.random() * 1e9)  // 出题种子，双方各自用它出题
      duelGames.set(duelId, {  // 建对局
        id: duelId,  // 对局 id
        seed,  // 出题种子
        count,  // 题量
        at: Date.now(),  // 建立时间
        pids: { [pid]: 'a', [myPid]: 'b' },  // pid 到左右边
        sides: {  // 双方进度
          a: { pid, nick: item.nick, school: item.school, answered: 0, correct: 0, done: false, ms: 0 },  // 先到的人
          b: { pid: myPid, nick, school, answered: 0, correct: 0, done: false, ms: 0 },  // 后到的人
        },  // 双方进度结束
      })  // 建对局结束
      return sendJSON(res, 200, {  // 直接告诉后到的人配上了
        status: 'matched',  // 已配对
        pid: myPid,  // 我的标识
        duelId,  // 对局 id
        seed,  // 出题种子
        count,  // 题量
        foe: { nick: item.nick, school: item.school },  // 对手信息
      })  // 返回结束
    }  // 遍历结束

    duelWaiting.set(myPid, { pid: myPid, nick, school, count, track, at: Date.now() })  // 没人等就自己排队
    return sendJSON(res, 200, { status: 'waiting', pid: myPid })  // 告诉客户端去轮询
  }  // 报名分支结束

  if (path === '/api/duel/poll' && req.method === 'GET') {  // 轮询是否配上
    const pid = url.searchParams.get('pid') || ''  // 我的标识
    for (const game of duelGames.values()) {  // 先看自己是否已被别人配上
      if (!game.pids[pid]) continue  // 不是我这一场
      const foe = game.pids[pid] === 'a' ? game.sides.b : game.sides.a  // 对手
      duelWaiting.delete(pid)  // 清掉可能残留的排队项
      return sendJSON(res, 200, {  // 回报配对成功
        status: 'matched',  // 已配对
        pid,  // 我的标识
        duelId: game.id,  // 对局 id
        seed: game.seed,  // 出题种子
        count: game.count,  // 题量
        foe: { nick: foe.nick, school: foe.school },  // 对手信息
      })  // 返回结束
    }  // 遍历结束
    const wait = duelWaiting.get(pid)  // 取排队项
    if (!wait) return sendJSON(res, 200, { status: 'expired' })  // 排队没了，让客户端重来
    if (Date.now() - wait.at >= DUEL_WAIT_MS) {  // 等超时
      duelWaiting.delete(pid)  // 摘掉排队
      return sendJSON(res, 200, { status: 'timeout' })  // 回 timeout，客户端上 AI 陪练
    }  // 超时分支结束
    return sendJSON(res, 200, { status: 'waiting' })  // 继续等
  }  // 轮询分支结束

  if (path === '/api/duel/progress' && req.method === 'POST') {  // 上报我的进度
    let body  // 请求体
    try {  // 读请求体
      body = await readBody(req)  // 解析
    } catch (e) {  // 体不合法
      return sendJSON(res, 400, { code: 'badRequest', message: String(e.message) })  // 400
    }  // 分支结束
    const pid = String(body.pid || '')  // 我的标识
    if (String(body.duelId || '') === '__cancel__') {  // 取消匹配的约定值
      duelWaiting.delete(pid)  // 把排队项清掉，别让别人配到已经走的人
      return sendJSON(res, 200, { ok: true })  // 回执
    }  // 取消分支结束
    const game = duelGames.get(String(body.duelId || ''))  // 取对局
    if (!game) return sendJSON(res, 404, { code: 'notFound', message: '对局不存在或已过期' })  // 404
    const side = game.pids[pid]  // 我在哪一边
    if (!side) return sendJSON(res, 403, { code: 'forbidden', message: '你不在这一场里' })  // 403
    const mine = game.sides[side]  // 我这一边
    mine.answered = Math.max(0, Number(body.answered) || 0)  // 已答数
    mine.correct = Math.max(0, Number(body.correct) || 0)  // 答对数
    mine.done = Boolean(body.done)  // 是否交卷
    mine.ms = Math.max(0, Number(body.ms) || 0)  // 总用时
    return sendJSON(res, 200, { ok: true, foe: duelFoe(game, pid) })  // 顺手把对手进度带回去
  }  // 上报分支结束

  if (path === '/api/duel/state' && req.method === 'GET') {  // 只读对手进度
    const pid = url.searchParams.get('pid') || ''  // 我的标识
    const game = duelGames.get(url.searchParams.get('duelId') || '')  // 取对局
    if (!game) return sendJSON(res, 404, { code: 'notFound', message: '对局不存在或已过期' })  // 404
    const foe = duelFoe(game, pid)  // 对手进度
    if (!foe) return sendJSON(res, 403, { code: 'forbidden', message: '你不在这一场里' })  // 403
    return sendJSON(res, 200, { ok: true, foe })  // 返回
  }  // 读取分支结束

  return sendJSON(res, 404, { code: 'notFound', message: '接口不存在' })  // 其余路径 404
}  // handleDuel 结束

// ---------- HTTP 小工具 ----------

// 统一 JSON 响应，带 CORS 头（本地调试方便，上线可收紧）
function sendJSON(res, status, body) {  // 统一 JSON 响应
  const text = JSON.stringify(body)  // 序列化
  res.writeHead(status, {  // 写响应头
    'content-type': 'application/json; charset=utf-8',  // 声明 JSON
    'access-control-allow-origin': '*',  // 允许跨域
    'access-control-allow-headers': 'content-type,x-device-id,x-service-token',  // 允许的请求头
    'access-control-allow-methods': 'GET,POST,OPTIONS'  // 允许的方法
  })  // 响应头结束
  res.end(text)  // 结束响应
}  // sendJSON 结束

// 读取请求体，限制 1MB 防止被灌爆
function readBody(req) {  // 读请求体
  return new Promise((resolve, reject) => {  // 包成 Promise
    let size = 0  // 已读字节数
    const chunks = []  // 数据块
    req.on('data', (c) => {  // 收到数据
      size += c.length  // 累加长度
      if (size > 1_000_000) {  // 超过 1MB
        reject(new Error('payload too large'))  // 直接拒绝
        req.destroy()  // 断开连接
        return  // 结束
      }  // 超限分支结束
      chunks.push(c)  // 收下
    })  // data 事件结束
    req.on('end', () => {  // 读完了
      if (!chunks.length) return resolve({})  // 空体给空对象
      try {  // 尝试解析
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')))  // 解析 JSON
      } catch {  // 解析失败
        reject(new Error('invalid json'))  // 解析失败
      }  // 分支结束
    })  // end 事件结束
    req.on('error', reject)  // 传输错误
  })  // Promise 结束
}  // readBody 结束

// 鉴权与限流：返回 null 表示通过，否则返回错误体
function guard(req) {  // 鉴权与限流
  const deviceId = req.headers['x-device-id']  // 设备标识
  const token = req.headers['x-service-token']  // 客户端令牌
  if (!deviceId) return { code: 'missing_device', message: '缺少 X-Device-Id' }  // 无设备 id
  if (token !== SERVICE_TOKEN) return { code: 'unauthorized', message: '令牌无效' }  // 令牌不对
  if (!takeQuota(deviceId)) return { code: 'quotaExceeded', message: '今日次数已用完' }  // 超限
  return null  // 通过
}  // guard 结束

// ---------- 提示词 ----------
// 约束来自 references/ai-interview.md：5 位导师固定分工、追问按角色归属、
// 评分必须引用用户原话、不预测录取、不评价文本之外的东西。

// 通用系统提示：所有接口共用
const SYSTEM_BASE = [  // 通用系统提示
  '你是考研复试模拟面试系统里的 AI 角色。',  // 身份
  '五位导师是虚构角色：组长、专业导师A（税收理论）、专业导师B（税务实务与政策）、外语导师、综合导师。',  // 角色表
  '禁止使用真人姓名、真人院校在职教师身份。',  // 硬约束
  '禁止输出录取概率、禁止说“院校会给你打几分”、禁止说“导师一定会喜欢你”。',  // 硬约束
  '禁止评价眼神、坐姿、自信程度这类无法从文字判断的东西。',  // 硬约束
  '只输出 JSON，不要输出 Markdown、不要输出解释性前言。'  // 输出格式
].join('\n')  // 拼成一段

// 出题 / 追问：输入本场上下文，输出下一位导师的一句话提问
function buildTurnPrompt({ phase, speaker, history, mode, style }) {  // 拼出题提示词
  return [  // 提示词数组
    SYSTEM_BASE,  // 系统约束
    '',  // 空行
    `当前环节：${phase}`,  // 环节
    `本轮应由：${speaker} 提问`,  // 指定发言人
    `面试类型：${mode}，导师风格：${style}（只影响追问强度，不影响评分标准）`,  // 参数
    '',  // 空行
    '已有问答记录（JSON）：',  // 上下文标题
    JSON.stringify(history || []),  // 历史轮次
    '',  // 空行
    '要求：',  // 要求列表
    '1. 只问一个问题，不超过 60 字，口语化，像真人面试官。',  // 长度
    '2. 如果上一轮回答有明显漏洞，优先针对漏洞追问，追问由当前发言人发起。',  // 追问规则
    '3. 不要重复前面已经问过的问题。',  // 去重
    '4. 输出格式：{"question":"...","knowledgePoints":["..."]}',  // 输出结构
  ].join('\n')  // 拼成一段
}  // buildTurnPrompt 结束

// 单轮评分：输出五维，evidence 必须是用户原话片段
function buildEvaluatePrompt({ question, answer, speaker }) {  // 拼评分提示词
  return [  // 提示词数组
    SYSTEM_BASE,  // 系统约束
    '',  // 空行
    `提问人：${speaker}`,  // 谁问的
    `问题：${question}`,  // 问题原文
    `考生回答：${answer}`,  // 回答原文
    '',  // 空行
    '请评分，规则：',  // 规则标题
    '1. 五个维度：completeness（内容完整性）、logic（逻辑结构）、professionalExpression（专业表达）、languageOrganization（语言组织）、manner（综合素养）。',  // 维度
    '2. 每个维度 0-100 分，evidence 必须从“考生回答”里原样摘一句，不允许自己编。',  // 证据
    '3. 如果某个维度无法从回答判断，evidence 留空字符串，score 给 0。',  // 无法判断
    '4. improvements 给 1-3 条，每条要有 issue（问题）、example（考生原话）、rewrite（改写示例）。',  // 改进
    '5. 输出格式：{"evaluation":{"completeness":{"score":0,"evidence":"","comment":""},"logic":{...},"professionalExpression":{...},"languageOrganization":{...},"manner":{...}},"improvements":[{"issue":"","example":"","rewrite":""}],"confidence":"high|medium|low","uncertainty":"字符串或null"}',  // 输出结构
  ].join('\n')  // 拼成一段
}  // buildEvaluatePrompt 结束

// 整场总结：结构对齐 iOS 的 InterviewSession 结果字段
function buildSummaryPrompt({ turns, mode }) {  // 拼总结提示词
  return [  // 提示词数组
    SYSTEM_BASE,  // 系统约束
    '',  // 空行
    `面试类型：${mode}`,  // 类型
    '完整问答记录（JSON）：',  // 记录标题
    JSON.stringify(turns || []),  // 全部轮次
    '',  // 空行
    '请生成本场总结，规则：',  // 规则标题
    '1. headline 一句话结论，不含录取判断。',  // 结论
    '2. perQuestion 逐题列出：你答到的要点、该题常考但你漏掉的要点、追问暴露的问题。',  // 逐题
    '3. topActions 给 3 条可执行动作，每条带 why（为什么）和 howToCheck（怎么自检已改到位）。',  // 动作
    '4. 输出格式：{"headline":"","perQuestion":[{"question":"","yourPoints":[],"missingPoints":[],"followUpExposed":""}],"topActions":[{"action":"","why":"","howToCheck":""}],"confidence":"high|medium|low","uncertainty":["..."]}',  // 输出结构
  ].join('\n')  // 拼成一段
}  // buildSummaryPrompt 结束

// AI 学伴：首页那块「今天该练什么」的建议
function buildCoachPrompt({ question, context }) {  // 拼学伴提示词
  return [  // 提示词数组
    SYSTEM_BASE,  // 系统约束
    '',  // 空行
    '你的角色是备考学伴，不是面试官，也不是老师。',  // 角色
    `用户问：${question}`,  // 用户问题
    context ? `用户当前学习状态（真实数据，只能引用这里出现过的数字）：${context}` : '用户当前学习状态：未提供，禁止编造任何数字。',  // 上下文
    '',  // 空行
    '要求：',  // 要求列表
    '1. 回答不超过 120 字，直接给建议，不要寒暄，不要复述问题。',  // 长度
    '2. 只能引用上面给出的数字；没有给数字就不许说「你已经答了 N 题」这类话。',  // 禁止编造
    '3. 不预测录取结果，不承诺提分幅度。',  // 不做承诺
    '4. actions 给 1-2 条：用户点一下就能去做的事，必须对应 App 内已有功能（刷题、闯关、错题本、模拟面试）。',  // 动作
    '5. 输出格式：{"reply":"...","actions":[{"title":"...","detail":"..."}],"confidence":"high|medium|low"}',  // 输出结构
  ].join('\n')  // 拼成一段
}  // buildCoachPrompt 结束

// ---------- 调上游 ----------

// 调 DeepSeek，返回解析后的对象；失败抛结构化错误
async function callModel(prompt, { temperature = 0.7, json = true } = {}) {  // 调上游模型
  const ctrl = new AbortController()  // 用于超时中断
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS)  // 到点中断
  try {  // 尝试请求
    const resp = await fetch(UPSTREAM, {  // 发请求
      method: 'POST',  // POST
      signal: ctrl.signal,  // 绑定中断信号
      headers: {  // 请求头
        'content-type': 'application/json',  // JSON
        authorization: `Bearer ${API_KEY}`,  // Key 只在这里出现
      },  // 请求头结束
      body: JSON.stringify({  // 请求体
        model: MODEL,  // 模型
        temperature,  // 随机度
        messages: [  // 消息
          { role: 'system', content: SYSTEM_BASE },  // 系统
          { role: 'user', content: prompt },  // 用户
        ],  // 消息结束
        ...(json ? { response_format: { type: 'json_object' } } : {}),  // 强制 JSON
      }),  // 请求体结束
    })  // fetch 结束
    if (!resp.ok) {  // 上游报错
      const text = await resp.text()  // 读错误体
      throw new Error(`upstream ${resp.status}: ${text.slice(0, 200)}`)  // 抛出
    }  // 报错分支结束
    const data = await resp.json()  // 解析响应
    const content = data?.choices?.[0]?.message?.content ?? ''  // 取正文
    if (!content) throw new Error('empty completion')  // 空正文
    return JSON.parse(content)  // 解析 JSON
  } finally {  // 无论如何清理
    clearTimeout(timer)  // 清定时器
  }  // finally 结束
}  // callModel 结束

// ---------- 业务校验 ----------

// 校验 evidence 是否真出自考生回答：编造的维度直接作废
function sanitizeEvaluation(evaluation, answer) {  // 证据真实性校验
  const normalized = String(answer || '').replace(/\s+/g, '')  // 去掉空白再比
  const result = {}  // 结果容器
  const dropped = []  // 被作废的维度
  for (const [key, dim] of Object.entries(evaluation || {})) {  // 逐个维度
    const ev = String(dim?.evidence || '').replace(/\s+/g, '')  // 证据去空白
    const ok = ev.length > 0 && normalized.includes(ev)  // 是否真出自原文
    if (ok) {  // 通过校验
      result[key] = {  // 保留
        score: Math.max(0, Math.min(100, Number(dim.score) || 0)),  // 夹到 0-100
        evidence: dim.evidence,  // 原样保留证据
        comment: String(dim.comment || ''),  // 点评
      }  // 保留分支结束
    } else {  // 没通过
      result[key] = { score: 0, evidence: '', comment: '' }  // 记为不可判
      dropped.push(key)  // 记下维度名
    }  // 作废分支结束
  }  // 遍历结束
  return { evaluation: result, dropped }  // 返回结果
}  // sanitizeEvaluation 结束

// 主路由处理：把 path 分发到对应逻辑
async function handle(req, res) {  // 主路由
  const url = new URL(req.url, `http://localhost:${PORT}`)  // 解析 URL
  const path = url.pathname  // 取路径

  if (req.method === 'OPTIONS') return sendJSON(res, 204, {})  // 预检直接放行

  // 健康检查：不鉴权，App 启动时用它探测服务是否在线
  if (path === '/health') {  // 健康检查
    return sendJSON(res, 200, {  // 返回状态
      ok: true,  // 服务活着
      service: 'fushizhuan-bff',  // 服务名
      model: MODEL,  // 当前模型
      keyConfigured: Boolean(API_KEY),  // Key 是否就绪
      dailyLimit: DAILY_LIMIT,  // 每日额度
    })  // 响应结束
  }  // 分支结束

  // 1V1 配对：不调模型、不烧额度，所以放在 AI 鉴权之前处理
  if (path.startsWith('/api/duel/')) return handleDuel(req, res, path, url)  // 交给配对逻辑

  if (path !== '/v1/interview/turn' &&  // 非出题
      path !== '/v1/interview/evaluate' &&  // 非评分
      path !== '/v1/interview/summary' &&  // 非总结
      path !== '/v1/coach') {  // 非学伴
    return sendJSON(res, 404, { code: 'notFound', message: '接口不存在' })  // 404
  }  // 404 分支结束

  if (!API_KEY) {  // 没配 Key
    return sendJSON(res, 503, { code: 'aiUnavailable', message: '服务端未配置模型密钥' })  // 503
  }  // 未配 Key 分支结束

  const denied = guard(req)  // 鉴权 + 限流
  if (denied) return sendJSON(res, denied.code === 'quotaExceeded' ? 429 : 401, denied)  // 拦下

  let body  // 请求体
  try {  // 尝试读请求体
    body = await readBody(req)  // 读取
  } catch (e) {  // 请求体不合法
    return sendJSON(res, 400, { code: 'badRequest', message: String(e.message) })  // 体不合法
  }  // 分支结束

  const sessionId = String(body.sessionId || '')  // 场次 id
  const turnIndex = Number(body.turnIndex || 0)  // 轮次号

  // AI 学伴：一次性问答，没有「场次」概念，所以不走幂等缓存，直接出结果
  if (path === '/v1/coach') {  // 学伴分支
    const question = String(body.question || '').trim().slice(0, 200)  // 用户问题，限长
    if (!question) {  // 空问题没有意义
      return sendJSON(res, 400, { code: 'badRequest', message: 'question 不能为空' })  // 400
    }  // 分支结束
    const context = String(body.context || '').slice(0, 500)  // 学习状态摘要，限长防注入
    const prompt = buildCoachPrompt({ question, context })  // 拼提示词
    const out = await callModel(prompt, { temperature: 0.5 })  // 温度低一点，建议更稳
    return sendJSON(res, 200, {  // 返回
      requestId: randomUUID(),  // 请求 id
      reply: String(out.reply || '').slice(0, 600),  // 建议正文
      actions: Array.isArray(out.actions) ? out.actions.slice(0, 2) : [],  // 最多两条动作
      confidence: out.confidence || 'low',  // 置信度
    })  // 返回结束
  }  // 学伴分支结束

  const cacheKey = `${path}:${sessionId}:${turnIndex}`  // 幂等键
  const cached = idempotentGet(cacheKey)  // 查缓存
  if (cached) return sendJSON(res, 200, { ...cached, cached: true })  // 命中直接返回

  try {  // 进入业务分支
    if (path === '/v1/interview/turn') {  // 出题 / 追问
      const prompt = buildTurnPrompt({  // 拼提示词
        phase: body.phase || 'major',  // 环节
        speaker: body.speaker || 'lead',  // 发言人
        history: body.history || [],  // 历史
        mode: body.mode || 'professional',  // 类型
        style: body.style || 'standard',  // 风格
      })  // 参数结束
      const out = await callModel(prompt)  // 调模型
      const payload = {  // 组装响应
        requestId: randomUUID(),  // 请求 id，便于排查
        question: String(out.question || '').slice(0, 200),  // 问题，限长
        knowledgePoints: Array.isArray(out.knowledgePoints) ? out.knowledgePoints : [],  // 知识点
      }  // 组装结束
      idempotentSet(cacheKey, payload)  // 写缓存
      return sendJSON(res, 200, payload)  // 返回
    }  // 出题分支结束

    if (path === '/v1/interview/evaluate') {  // 单轮评分
      const answer = String(body.answer || '')  // 考生回答
      const prompt = buildEvaluatePrompt({  // 拼提示词
        question: body.question || '',  // 问题
        answer,  // 回答
        speaker: body.speaker || 'lead',  // 谁问的
      })  // 参数结束
      const out = await callModel(prompt)  // 调模型
      const { evaluation, dropped } = sanitizeEvaluation(out.evaluation, answer)  // 校验证据
      const uncertainty = []  // 不确定项
      if (out.uncertainty) uncertainty.push(String(out.uncertainty))  // 模型自述
      if (dropped.length) uncertainty.push(`以下维度缺少原文依据，已作废：${dropped.join('、')}`)  // 作废说明
      const payload = {  // 组装响应
        requestId: randomUUID(),  // 请求 id
        evaluation,  // 五维评分
        improvements: Array.isArray(out.improvements) ? out.improvements : [],  // 改进建议
        confidence: out.confidence === 'high' && dropped.length ? 'medium' : (out.confidence || 'low'),  // 有作废就降级
        uncertainty: uncertainty.length ? uncertainty.join('；') : null,  // 合并说明
      }  // 组装结束
      idempotentSet(cacheKey, payload)  // 写缓存
      return sendJSON(res, 200, payload)  // 返回
    }  // 评分分支结束

    // /v1/interview/summary                                      // 整场总结
    const prompt = buildSummaryPrompt({ turns: body.turns || [], mode: body.mode || 'professional' })  // 拼提示词
    const out = await callModel(prompt)  // 调模型
    const payload = {  // 组装响应
      requestId: randomUUID(),  // 请求 id
      headline: String(out.headline || ''),  // 一句话结论
      perQuestion: Array.isArray(out.perQuestion) ? out.perQuestion : [],  // 逐题复盘
      topActions: Array.isArray(out.topActions) ? out.topActions : [],  // 可执行动作
      confidence: out.confidence || 'low',  // 置信度
      uncertainty: Array.isArray(out.uncertainty) ? out.uncertainty : [],  // 不确定项
      disclaimer: '训练量表，非院校官方评分；不预测录取结果',  // 强制声明
    }  // 组装结束
    idempotentSet(cacheKey, payload)  // 写缓存
    return sendJSON(res, 200, payload)  // 返回
  } catch (err) {  // 业务异常
    const msg = String(err?.message || err)  // 错误信息
    const timeout = /abort/i.test(msg)  // 是否超时
    return sendJSON(res, timeout ? 504 : 502, {  // 超时 504，其它 502
      code: timeout ? 'timeout' : 'aiUnavailable',  // 错误码，对应 iOS AppError
      message: msg.slice(0, 300),  // 截断，避免泄露上游细节
      retriable: true,  // 允许重试
    })  // 响应结束
  }  // catch 结束
}  // handle 结束

// ---------- 启动 ----------

const server = createServer((req, res) => {  // 创建服务
  handle(req, res).catch((e) => {  // 兜底异常
    sendJSON(res, 500, { code: 'internal', message: String(e?.message || e) })  // 500
  })  // catch 结束
})  // createServer 结束

server.listen(PORT, () => {  // 开始监听
  console.log(`[bff] listening on http://127.0.0.1:${PORT}`)  // 本地地址
  console.log(`[bff] model=${MODEL} key=${API_KEY ? 'ready' : 'MISSING'}`)  // 配置状态
  console.log(`[bff] dailyLimit=${DAILY_LIMIT} token=${SERVICE_TOKEN.slice(0, 6)}***`)  // 额度与令牌
})  // listen 结束
