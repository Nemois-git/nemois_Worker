
//
//  DashboardView.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI

/// 실시간 리소스 사용량과 모델/서버 상태를 시각적으로 보여주는 대시보드 뷰입니다.
struct DashboardView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var serverManager: ServerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Resource Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding([.horizontal, .bottom])

            ResourceMetricView(
                metricName: "CPU Usage (System-wide)",
                value: String(format: "%.1f%%", systemMonitor.cpuUsage),
                iconName: "cpu",
                color: .blue
            )
            
            ResourceMetricView(
                metricName: "Memory Usage (App)",
                value: "\(formatBytes(systemMonitor.memoryUsage))",
                iconName: "memorychip",
                color: .green
            )
            
            Divider().padding(.vertical)
            
            modelControlSection
            
            Divider().padding(.vertical)
            
            serverControlSection
            
            Spacer()
        }
    }
    
    /// 모델 제어 UI
    private var modelControlSection: some View {
        VStack(alignment: .leading, spacing: 15) {

            VStack(alignment: .leading, spacing: 15)  {
                Text("Model Control")
                    .font(.title2).fontWeight(.bold).padding(.horizontal)
                HStack {
                    modelStatusView
                    Spacer()
                    Toggle("Load Model", isOn: Binding(
                        get: { modelManager.isModelLoaded },
                        set: { shouldBeLoaded in
                            if shouldBeLoaded {
                                Task { modelManager.loadModel() }
                            } else {
                                modelManager.unloadModel() // 이 함수는 동기 함수이므로 await이 필요 없습니다.
                            }
                        }
                    ))
                    .labelsHidden()
                    .disabled(modelManager.modelState.isLoading || serverManager.serverState.isStartingOrRunning)
                }
                .padding(.horizontal)
                Divider().padding(.vertical)
                Text("Toggle Memory")
                    .font(.title2).fontWeight(.bold).padding(.horizontal)
                HStack {
                    memoryToggleView
                    Spacer()
                    Toggle("Toggle memory(Very limited)", isOn: $modelManager.memoryMode)
                        .labelsHidden()
                        .disabled(modelManager.modelState.isLoading || serverManager.serverState.isStartingOrRunning)
                }
                .padding(.horizontal)
            }
            if case .error(let errorMessage) = modelManager.modelState {
                Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
        }
    }
    
    /// 서버 제어 UI
    private var serverControlSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Server Control")
                .font(.title2).fontWeight(.bold).padding(.horizontal)
            
            HStack {
                serverStatusView
                Spacer()
                Toggle("API Server", isOn: Binding(
                    get: { serverManager.serverState.isStartingOrRunning },
                    set: { shouldBeOn in
                        if shouldBeOn {
                            Task { serverManager.startServer() }
                        } else {
                            serverManager.stopServer()
                        }
                    }
                ))
                .labelsHidden()
                .disabled(!modelManager.isModelLoaded) // 모델이 로드되어야만 서버를 켤 수 있습니다.
            }
            .padding(.horizontal)
            
            HStack {
                Text("API Address:").font(.subheadline).foregroundColor(.secondary)
                Text(serverManager.serverAddress).font(.subheadline).fontWeight(.semibold).textSelection(.enabled)
                Spacer()
            }.padding(.horizontal)
            
            if case .error(let errorMessage) = serverManager.serverState {
                Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
            }
        }
    }
    
    /// 모델 상태 UI
    @ViewBuilder private var modelStatusView: some View {
        HStack {
            switch modelManager.modelState {
            case .notLoaded: Image(systemName: "xmark.circle.fill").foregroundColor(.gray); Text("Not Loaded")
            case .loading: ProgressView().scaleEffect(0.8); Text("Loading...")
            case .loaded: Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Loaded")
            case .error: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red); Text("Error")
            }
        }
    }
    
    /// 서버 상태 UI
    @ViewBuilder private var serverStatusView: some View {
        HStack {
            switch serverManager.serverState {
            case .stopped: Image(systemName: "xmark.circle.fill").foregroundColor(.gray); Text("Stopped")
            case .starting: ProgressView().scaleEffect(0.8); Text("Starting...")
            case .running: Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Running")
            case .error: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red); Text("Error")
            }
        }
    }
    
    /// Memory function UI
    @ViewBuilder private var memoryToggleView: some View {
        HStack {
            switch modelManager.memoryMode {
            case false: Image(systemName: "xmark.circle.fill").foregroundColor(.gray); Text("Stopped")
            case true: Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Running")
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter(); formatter.allowedUnits = [.useMB, .useGB]; formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// 리소스 지표를 표시하기 위한 재사용 가능한 서브뷰입니다.
struct ResourceMetricView: View {
    let metricName: String; let value: String; let iconName: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: iconName).font(.largeTitle).foregroundColor(color).frame(width: 60)
            VStack(alignment: .leading) {
                Text(metricName).font(.headline).foregroundColor(.secondary)
                Text(value).font(.title2).fontWeight(.semibold)
            }
        }.padding(.horizontal)
    }
}

// Extensions for state checking
extension ModelManager.ModelState {
    var isLoading: Bool { if case .loading = self { return true }; return false }
}
