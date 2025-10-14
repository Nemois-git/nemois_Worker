
//
//  nemois_WorkerApp.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI
import Combine

/// 앱의 핵심 서비스(상태) 객체들을 생성하고 의존성을 관리하는 컨테이너입니다.
class AppState: ObservableObject {
    let modelManager = ModelManager()
    let serverManager: ServerManager
    let systemMonitor = SystemMonitor()
    let logStore = LogStore.shared
    
    init() {
        // ServerManager를 생성할 때, 이미 생성된 ModelManager 인스턴스를 주입합니다.
        self.serverManager = ServerManager(modelManager: self.modelManager)
    }
}

@main
struct nemois_WorkerApp: App {
    // AppState를 단일 StateObject로 사용하여 모든 핵심 서비스를 관리합니다.
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 모든 하위 뷰에서 핵심 서비스들을 사용할 수 있도록 환경 객체로 주입합니다.
                .environmentObject(appState.serverManager)
                .environmentObject(appState.modelManager)
                .environmentObject(appState.systemMonitor)
                .environmentObject(appState.logStore)
        }
    }
}
