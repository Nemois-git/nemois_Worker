
//
//  SystemMonitor.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import Combine

/// 시스템의 CPU 및 메모리 사용량을 실시간으로 모니터링하는 `ObservableObject`입니다.
/// 이 클래스는 시스템 레벨의 API를 직접 호출하여 실제 데이터를 가져오며, 더 이상 시뮬레이션 데이터를 사용하지 않습니다.
class SystemMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: UInt64 = 0 // Bytes 단위
    
    // MARK: - Private Properties
    
    private var timer: AnyCancellable?
    
    // For CPU Usage Calculation
    private var host: host_t
    private var loadPrevious = host_cpu_load_info()
    
    init() {
        self.host = mach_host_self()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    private func startMonitoring() {
        // 1초마다 리소스 사용량을 업데이트합니다.
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func stopMonitoring() {
        timer?.cancel()
    }
    
    // MARK: - Metric Updates
    
    private func updateMetrics() {
        updateCPUUsage()
        updateMemoryUsage()
    }
    
    /// **시스템 전체**의 CPU 사용량을 업데이트합니다.
    private func updateCPUUsage() {
        let load = hostCPULoadInfo()
        
        let userDiff = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let sysDiff = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        let activeTicks = sysDiff + userDiff + niceDiff
        
        if totalTicks > 0 {
            self.cpuUsage = activeTicks / totalTicks * 100.0
        } else {
            self.cpuUsage = 0.0
        }
        
        self.loadPrevious = load
    }
    
    /// **현재 앱 프로세스**의 메모리 사용량(RAM)을 업데이트합니다.
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            self.memoryUsage = info.resident_size
        } else {
            print("Error with task_info(): \(String(cString: mach_error_string(kerr)))")
            self.memoryUsage = 0
        }
    }
    
    // MARK: - Private Helpers
    
    private func hostCPULoadInfo() -> host_cpu_load_info {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        #if DEBUG
        if result != KERN_SUCCESS {
            print("Error with host_statistics(): \(String(cString: mach_error_string(result)))")
        }
        #endif
        
        return cpuLoadInfo
    }
}
