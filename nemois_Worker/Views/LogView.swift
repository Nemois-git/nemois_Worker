

//
//  LogView.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI

/// `LogStore`에 기록된 로그들을 화면에 표시하는 뷰입니다.
struct LogView: View {
    // 앱 전역에서 공유되는 LogStore 인스턴스를 환경 객체로 가져옵니다.
    @EnvironmentObject var logStore: LogStore

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logStore.logs) { log in
                        Text(log.message)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal)
                            .id(log.id)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: logStore.logs) { _, _ in
                // 새로운 로그가 추가되면 자동으로 맨 아래로 스크롤합니다.
                if let lastLog = logStore.logs.last {
                    withAnimation {
                        scrollViewProxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            // 로그를 복사하거나 지우는 버튼을 추가합니다.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: copyLogs) {
                        Label("Copy Logs", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func copyLogs() {
        let logText = logStore.logs.map { $0.message }.joined(separator: "\n")
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
        #else
        UIPasteboard.general.string = logText
        #endif
        logStore.add(log: "Logs copied to clipboard.")
    }
}
