//
//  SettingsView.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI

/// 앱의 다양한 설정을 관리하는 뷰입니다.
/// 사용자는 이 화면에서 모델 저장 위치 변경, 앱 정보 확인 등
/// 주요 옵션을 제어할 수 있습니다.
/// 현대적인 카드 UI를 적용하여 시각적으로 개선된 설정 뷰입니다.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

    var body: some View {
        // ZStack을 사용해 배경색을 깔아줍니다.
        ZStack {
            // macOS에서는 약간 어두운 배경색을, iOS에서는 시스템 배경색을 사용합니다.
            #if os(macOS)
            Color(.windowBackgroundColor).ignoresSafeArea()
            #else
            Color(.systemGroupedBackground).ignoresSafeArea()
            #endif

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // --- 서버 설정 카드 ---
                    VStack(alignment: .leading, spacing: 15) {
                        // 섹션 헤더
                        Text("Server Settings")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        // 포트 설정 행
                        HStack {
                            Label("Port", systemImage: "network")
                            Spacer()
                            TextField("Port", value: $viewModel.serverPort, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 100) // 텍스트 필드 너비 제한
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }
                    }
                    .padding()
                    .background(Material.regular, in: RoundedRectangle(cornerRadius: 12)) // 반투명한 카드 배경

                    // --- 정보 카드 ---
                    VStack(alignment: .leading, spacing: 15) {
                        Text("About")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        // 구분선
                        Divider()

                        // 개발자 정보 행
                        HStack {
                            Label("Developer", systemImage: "person.fill")
                            Spacer()
                            Text("nemois")
                                .foregroundStyle(.secondary)
                        }

                        // 구분선
                        Divider()
                        
                        // 버전 정보 행
                        HStack {
                            Label("Version", systemImage: "info.circle.fill")
                            Spacer()
                            Text("\(appVersion ?? "") (\(buildNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Material.regular, in: RoundedRectangle(cornerRadius: 12))
                    
                    Spacer() // 컨텐츠를 위로 밀어 올림
                }
                .padding() // 전체적인 여백
            }
        }
        .navigationTitle("Settings")
    }
}
