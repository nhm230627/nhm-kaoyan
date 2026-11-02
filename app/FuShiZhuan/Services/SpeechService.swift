//  SpeechService.swift —— 语音作答（系统识别，语音不出设备）            // 文件说明
//  只做一件事：把说的话变成文字，交给面试房间填进作答框                 // 职责约束
//  音频不落盘、不上传；识别失败统一翻译成 AppError                      // 隐私原则

import AVFoundation                                                 // 录音与音频会话
import Foundation                                                   // 基础库
import Observation                                                  // 观察框架
import Speech                                                       // 语音识别

@Observable                                                         // 视图自动刷新
final class SpeechService {                                         // 语音识别服务
    private(set) var transcript = ""                                // 当前识别文本
    private(set) var isRecording = false                            // 是否正在录
    private(set) var error: AppError?                               // 最近一次错误

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) // 中文识别器
    private let audio = AVAudioEngine()                             // 录音引擎
    private var request: SFSpeechAudioBufferRecognitionRequest?     // 识别请求
    private var task: SFSpeechRecognitionTask?                      // 识别任务

    // MARK: - 对外开关                                                  // 分节：开关

    /// 开始录音与识别。权限、识别器、音频会话任一不通都会写进 error 并返回
    func start() async {                                            // 开始
        guard !isRecording else { return }                          // 已在录就不重复开
        error = nil                                                 // 清旧错误
        transcript = ""                                             // 清旧文本

        guard await ensurePermission() else { return }              // 两道权限都过才继续
        guard let recognizer = recognizer, recognizer.isAvailable else { // 识别器可用性
            error = .speechUnavailable("这台设备的中文语音识别暂时不可用") // 明确原因
            return                                                  // 直接退出
        }                                                           // 分支结束

        let session = AVAudioSession.sharedInstance()               // 取音频会话
        do {                                                        // 配置音频会话
            try session.setCategory(.record, mode: .measurement, options: .duckOthers) // 只录不放，压低其它音
            try session.setActive(true, options: .notifyOthersOnDeactivation) // 激活
        } catch {                                                   // 配置失败
            self.error = AppError.speechUnavailable("麦克风被其它应用占用，先关掉正在通话或录音的应用") // 必须写 self，否则被 catch 的隐式 error 遮住
            return                                                  // 退出
        }                                                           // 分支结束

        let req = SFSpeechAudioBufferRecognitionRequest()           // 新建识别请求
        req.shouldReportPartialResults = true                       // 边说边出字
        req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition // 能在本机识别就不出设备
        let input = audio.inputNode                                 // 输入节点
        let format = input.outputFormat(forBus: 0)                  // 设备采样格式
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in // 抓音频
            req.append(buffer)                                      // 直接喂给识别器，不写文件
        }                                                           // 抓音结束

        audio.prepare()                                             // 预启动，减少延迟
        do {                                                        // 启动引擎
            try audio.start()                                       // 开始录
        } catch {                                                   // 启动失败
            input.removeTap(onBus: 0)                               // 清理已装的回调
            self.error = AppError.speechUnavailable("录音启动失败，请重试一次") // 必须写 self，否则被 catch 的隐式 error 遮住
            return                                                  // 退出
        }                                                           // 分支结束

        task = recognizer.recognitionTask(with: req) { [weak self] result, failure in // 启动识别
            Task { @MainActor in                                    // 回主线程改状态
                self?.consume(result: result, failure: failure)     // 处理识别回调
            }                                                       // 任务结束
        }                                                           // 识别任务结束

        request = req                                               // 持有引用
        isRecording = true                                          // 标记在录
    }                                                               // start 结束

    /// 停止录音并结束识别
    func stop() {                                                   // 停止
        guard isRecording else { return }                           // 没在录就不动
        isRecording = false                                         // 先改标记，避免回调再触发 stop
        audio.stop()                                                // 停引擎
        audio.inputNode.removeTap(onBus: 0)                         // 摘掉回调
        request?.endAudio()                                         // 告诉识别器没有更多音频
        task?.cancel()                                              // 取消识别任务
        task = nil                                                  // 清引用
        request = nil                                               // 清引用
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) // 释放音频会话
    }                                                               // stop 结束

    /// 清错误
    func clearError() { error = nil }                                // 重置

    // MARK: - 内部                                                      // 分节：内部

    /// 依次申请语音识别与麦克风权限
    private func ensurePermission() async -> Bool {                  // 权限检查
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in // 包成 async
            SFSpeechRecognizer.requestAuthorization { status in      // 系统弹窗
                cont.resume(returning: status)                       // 回传结果
            }                                                        // 回调结束
        }                                                            // 等待结束
        guard speechStatus == .authorized else {                     // 未授权
            error = .speechDenied                                    // 统一错误
            return false                                             // 失败
        }                                                            // 分支结束
        let micAllowed = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in // 包成 async
            AVAudioApplication.requestRecordPermission { granted in  // iOS 17 起用 AVAudioApplication
                cont.resume(returning: granted)                      // 回传结果
            }                                                        // 回调结束
        }                                                            // 等待结束
        guard micAllowed else {                                      // 未授权
            error = .speechDenied                                    // 统一错误
            return false                                             // 失败
        }                                                            // 分支结束
        return true                                                  // 都过了
    }                                                                // ensurePermission 结束

    /// 处理识别回调：累积文本，出错就停
    private func consume(result: SFSpeechRecognitionResult?, failure: Error?) { // 回调处理
        if let result = result {                                     // 有识别结果
            transcript = result.bestTranscription.formattedString    // 用最可能的一句
            if result.isFinal { stop() }                             // 说完自动停
        }                                                            // 分支结束
        if let failure = failure, isRecording {                      // 真出错且在录
            error = .speechUnavailable("识别中断：\(failure.localizedDescription)") // 记录原因
            stop()                                                   // 收尾
        }                                                            // 分支结束
    }                                                                // consume 结束
}                                                                    // SpeechService 结束
