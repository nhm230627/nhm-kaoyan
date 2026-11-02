//  SnapshotStore.swift —— 本地持久化                               // 文件说明
//  整份状态序列化成一个 JSON 文件，原子写入，主文件坏了用备份            // 设计说明
//  不用 SwiftData 的理由写在 docs/01 与项目记忆里                     // 设计说明

import Foundation  // 基础库

enum StoreError: Error {  // 存储错误
    case encodeFailed(String)  // 编码失败
    case decodeFailed(String)  // 解码失败
    case writeFailed(String)  // 写入失败
}  // StoreError 结束

final class SnapshotStore {  // 快照存储
    private let fileURL: URL  // 主文件地址
    private let backupURL: URL  // 备份文件地址
    private let queue = DispatchQueue(label: "com.fushizhuan.store", qos: .utility)  // 串行写队列

    init(directory: URL? = nil) {  // 构造器，可传测试目录
        let base = directory ?? FileManager.default.urls(  // 默认文档目录
            for: .documentDirectory,  // 文档目录
            in: .userDomainMask  // 用户域
        )[0]  // 取第一个
        self.fileURL = base.appendingPathComponent("appstate.json")  // 主文件名
        self.backupURL = base.appendingPathComponent("appstate.backup.json")  // 备份名
    }  // 构造结束

    func load() throws -> AppSnapshot? {  // 同步读盘
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }  // 没文件返回空
        do {  // 尝试读主文件
            let data = try Data(contentsOf: fileURL)  // 读原始数据
            let decoder = JSONDecoder()  // 建解码器
            decoder.dateDecodingStrategy = .iso8601  // 日期用 ISO8601
            return try decoder.decode(AppSnapshot.self, from: data)  // 解码
        } catch {  // 主文件坏了
            if let backup = try? Data(contentsOf: backupURL) {  // 试备份
                let decoder = JSONDecoder()  // 建解码器
                decoder.dateDecodingStrategy = .iso8601  // 日期格式
                if let snap = try? decoder.decode(AppSnapshot.self, from: backup) {  // 备份能解
                    return snap  // 用备份恢复
                }  // 分支结束
            }  // 分支结束
            throw StoreError.decodeFailed(String(describing: error))  // 都坏了才抛错
        }  // 分支结束
    }  // load 结束

    func save(_ snapshot: AppSnapshot) {  // 后台串行写入
        queue.async { [fileURL, backupURL] in  // 丢到写队列
            do {  // 尝试写
                let encoder = JSONEncoder()  // 建编码器
                encoder.dateEncodingStrategy = .iso8601  // 日期 ISO8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]  // 好看且稳定
                let data = try encoder.encode(snapshot)  // 编码

                if FileManager.default.fileExists(atPath: fileURL.path) {  // 已有主文件
                    try? FileManager.default.removeItem(at: backupURL)  // 删旧备份
                    try? FileManager.default.copyItem(at: fileURL, to: backupURL)  // 主文件转备份
                }  // 分支结束

                let tmp = fileURL.appendingPathExtension("tmp")  // 临时文件名
                try data.write(to: tmp, options: .atomic)  // 原子写临时文件
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)  // 原子替换
            } catch {  // 写失败
                NSLog("[SnapshotStore] save failed: \(error)")  // 留痕，不崩 App
            }  // 分支结束
        }  // 队列任务结束
    }  // save 结束

    func exportData() throws -> Data {  // 导出原始 JSON
        guard FileManager.default.fileExists(atPath: fileURL.path) else {  // 没文件
            throw StoreError.writeFailed("暂无可导出的数据")  // 抛错
        }  // 分支结束
        return try Data(contentsOf: fileURL)  // 读出来返回
    }  // exportData 结束

    func reset() {  // 重置
        queue.sync {  // 同步执行，避免竞态
            try? FileManager.default.removeItem(at: fileURL)  // 删主文件
            try? FileManager.default.removeItem(at: backupURL)  // 删备份
        }  // 同步块结束
    }  // reset 结束
}  // SnapshotStore 结束
