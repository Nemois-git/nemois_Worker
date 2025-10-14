
//
//  ContentView.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI

enum Panel: Hashable {
    case dashboard
    case settings
    case logs
}

/// 앱의 메인 컨텐츠 뷰로서, 주요 화면들을 탭으로 관리하는 컨테이너 역할을 합니다.
/// 사용자는 이 뷰를 통해 대시보드와 설정 화면을 쉽게 전환할 수 있습니다.
struct ContentView: View {
    @State private var selection: Panel? = .dashboard

    var body: some View {
        // 좌우로 뷰를 나누는 NavigationSplitView
        NavigationSplitView {
            // --- 왼쪽 사이드바 (Sidebar) ---
            List(selection: $selection) {
                // NavigationLink를 사용해 각 항목을 선택 가능하게 만듭니다.
                NavigationLink(value: Panel.dashboard) {
                    Label("Dashboard", systemImage: "gauge.high")
                }
                
                NavigationLink(value: Panel.settings) {
                    Label("Settings", systemImage: "gear")
                }
                
                NavigationLink(value: Panel.logs) {
                    Label("Logs", systemImage: "doc.text.below.ecg")
                }
            }
            .navigationTitle("Worker") // 사이드바 상단에 표시될 제목
            .listStyle(.sidebar)
            
        } detail: {
            // --- 오른쪽 컨텐츠 (Detail) ---
            // 'selection' 값에 따라 다른 뷰를 보여줍니다.
            switch selection {
            case .dashboard:
                DashboardContainerView()
            case .settings:
                SettingsContainerView()
            case .logs:
                LogView()
            case .none:
                // 아무것도 선택되지 않았을 때 기본으로 보여줄 뷰
                Text("Select an item from the sidebar")
            }
        }
    }
}

/// 대시보드 탭의 컨텐츠를 구성하는 뷰입니다.
struct DashboardContainerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DashboardView()
            }
            .padding()
        }
        .navigationTitle("Dashboard") // 컨텐츠 영역의 제목
    }
}

/// 설정 탭의 컨텐츠를 구성하는 뷰입니다.
struct SettingsContainerView: View {
    var body: some View {
        // Form을 사용하는 경우 NavigationView가 없어도 제목이 잘 표시됩니다.
        SettingsView()
            .navigationTitle("Settings") // 컨텐츠 영역의 제목
    }
}
