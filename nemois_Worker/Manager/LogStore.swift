//
//  LogStore.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import Combine

/// 앱 전체의 로그 메시지를 관리하고 UI에 제공하는 `ObservableObject`입니다.
/// Singleton 패턴으로 구현되어 앱의 어느 곳에서나 쉽게 접근하여 로그를 추가할 수 있습니다.
class LogStore: ObservableObject {
    
    @Published private(set) var logs: [LogEntry] = []
    
    static let shared = LogStore()
    
    private let dateFormatter: DateFormatter
    private let lock = NSRecursiveLock()
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "[HH:mm:ss.SSS]"
    }
    
    /// 새로운 로그 메시지를 추가합니다.
    /// 이 메소드는 여러 쓰레드에서 동시에 호출되어도 안전합니다.
    /// - Parameter message: 기록할 로그 문자열입니다.
    func add(log message: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = dateFormatter.string(from: Date())
        let newLog = LogEntry(message: "\(timestamp) \(message)")
        print(newLog.message) // Xcode 콘솔에도 로그를 출력합니다.
        
        // UI 업데이트는 Main 쓰레드에서 수행합니다.
        DispatchQueue.main.async {
            self.logs.append(newLog)
            if self.logs.count > 200 {
                self.logs.removeFirst()
            }
        }
    }
}

/// 단일 로그 항목을 나타내는 구조체입니다.
struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let message: String
}